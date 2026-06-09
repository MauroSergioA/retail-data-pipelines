/*
    mart_curva_abc
    ==============
    Grain: produto_id × empresa_id
    Período: últimos 12 meses a partir da data mais recente em fato_venda.
             Usar MAX(data_venda) em vez de CURRENT_DATE garante que o mart
             funcione corretamente mesmo durante cargas históricas incompletas.

    Três dimensões de classificação ABC, cada uma por valor e por quantidade:
      1. Por empresa       — ABC do produto dentro da sua própria loja
      2. Por categoria × empresa — ABC do produto dentro da categoria na loja
      3. Por rede          — ABC consolidado de todas as lojas

    A separação em três dimensões permite que analyses downstream escolham
    a mais adequada. Ex: ruptura usa abc_valor_categoria (impacto financeiro
    dentro da categoria); negociação com fornecedor usa abc_valor_rede.

    Recalcular semanalmente — a curva de 12 meses não muda de forma relevante
    dia a dia e o custo de varrer a fato_venda inteira não se justifica diário.
*/

{{ config(materialized='table') }}

/*
    periodo
    -------
    Define a janela de 12 meses usada em todo o modelo.
    Centralizado aqui para que qualquer ajuste de período seja feito em
    um único lugar sem precisar alterar os CTEs de cálculo.
*/
WITH periodo AS (
    SELECT
        MAX(data_venda)                              AS data_fim,
        MAX(data_venda) - INTERVAL '12 months'       AS data_inicio
    FROM {{ ref('fato_venda') }}
),

/*
    vendas_produto_empresa
    ----------------------
    Agrega fato_venda no grain produto × empresa para o período.
    Inclui todas as operações (vendas 800/810/820/828 e devoluções 202) para
    que o SUM de vlr_venda_liq represente a receita líquida real.
    — vlr_venda_liq já é calculado como vlr_venda_item - vlr_devol_item na stg,
      e as linhas 202 carregam vlr_venda_item = 0 e vlr_devol_item > 0,
      resultando em vlr_venda_liq negativo. Somar tudo dá o líquido correto.
    HAVING > 0 exclui produtos que tiveram mais devoluções do que vendas no
    período — esses não devem integrar a curva ABC.
*/
vendas_produto_empresa AS (
    SELECT
        fv.empresa_id,
        fv.produto_id,
        SUM(fv.valor_venda_liquido)                 AS receita_liq,
        SUM(fv.qtd_venda_liquida)                   AS quantidade_liq
    FROM {{ ref('fato_venda') }} fv
    CROSS JOIN periodo p
    WHERE fv.data_venda BETWEEN p.data_inicio AND p.data_fim
    GROUP BY fv.empresa_id, fv.produto_id
    HAVING SUM(fv.valor_venda_liquido) > 0
),

/*
    vendas_produto_rede
    -------------------
    Consolida as vendas de todas as lojas por produto.
    Calculado em CTE separada — se fosse feito diretamente no JOIN com
    abc_empresa, o mesmo produto apareceria N vezes (uma por loja) e as
    window functions da rede contariam N vezes o mesmo valor, distorcendo
    o percentual acumulado.
*/
vendas_produto_rede AS (
    SELECT
        produto_id,
        SUM(receita_liq)    AS receita_liq_rede,
        SUM(quantidade_liq) AS quantidade_liq_rede
    FROM vendas_produto_empresa
    GROUP BY produto_id
),

/*
    enriquecida
    -----------
    Traz familia_id e categoria_id de dim_produto_info para permitir a
    classificação ABC por categoria. LEFT JOIN para não perder produtos
    sem cadastro de família ou categoria.
*/
enriquecida AS (
    SELECT
        vpe.empresa_id,
        vpe.produto_id,
        dp.familia_id,
        dp.categoria_id,
        vpe.receita_liq,
        vpe.quantidade_liq
    FROM vendas_produto_empresa             vpe
    LEFT JOIN {{ ref('dim_produto_info') }} dp ON dp.produto_id = vpe.produto_id
),

/*
    abc_empresa
    -----------
    Calcula os acumulados necessários para a classificação ABC nas dimensões
    empresa e categoria × empresa.

    Lógica das window functions:
      - PARTITION BY define o universo de comparação (loja, ou categoria+loja)
      - ORDER BY receita_liq DESC ordena do maior para o menor contribuidor
      - ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW acumula linha a linha
      - O total sem ORDER BY dá o denominador para calcular o percentual

    Com acumulado e total em mãos, o SELECT final calcula pct = acum / total
    e aplica os thresholds A ≤ 80%, B ≤ 95%, C > 95%.
*/
abc_empresa AS (
    SELECT
        empresa_id,
        produto_id,
        familia_id,
        categoria_id,
        receita_liq,
        quantidade_liq,
        -- acumulados por empresa (valor)
        SUM(receita_liq) OVER (
            PARTITION BY empresa_id
            ORDER BY receita_liq DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                       AS receita_acum_empresa,
        SUM(receita_liq) OVER (PARTITION BY empresa_id)         AS receita_total_empresa,
        -- acumulados por empresa (quantidade)
        SUM(quantidade_liq) OVER (
            PARTITION BY empresa_id
            ORDER BY quantidade_liq DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                       AS qtd_acum_empresa,
        SUM(quantidade_liq) OVER (PARTITION BY empresa_id)      AS qtd_total_empresa,
        -- acumulados por categoria x empresa (valor)
        SUM(receita_liq) OVER (
            PARTITION BY empresa_id, categoria_id
            ORDER BY receita_liq DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                       AS receita_acum_categoria,
        SUM(receita_liq) OVER (
            PARTITION BY empresa_id, categoria_id
        )                                                       AS receita_total_categoria,
        -- acumulados por categoria x empresa (quantidade)
        SUM(quantidade_liq) OVER (
            PARTITION BY empresa_id, categoria_id
            ORDER BY quantidade_liq DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                       AS qtd_acum_categoria,
        SUM(quantidade_liq) OVER (
            PARTITION BY empresa_id, categoria_id
        )                                                       AS qtd_total_categoria
    FROM enriquecida
),

/*
    abc_rede
    --------
    Calcula os acumulados para a classificação ABC consolidada da rede.
    Opera sobre vendas_produto_rede (grain: produto, sem empresa) para
    garantir que cada produto entre uma única vez no cálculo acumulado.
    Sem PARTITION BY — o universo é toda a rede.
*/
abc_rede AS (
    SELECT
        produto_id,
        receita_liq_rede,
        quantidade_liq_rede,
        -- acumulados rede (valor)
        SUM(receita_liq_rede) OVER (
            ORDER BY receita_liq_rede DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                       AS receita_acum_rede,
        SUM(receita_liq_rede) OVER ()                           AS receita_total_rede,
        -- acumulados rede (quantidade)
        SUM(quantidade_liq_rede) OVER (
            ORDER BY quantidade_liq_rede DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )                                                       AS qtd_acum_rede,
        SUM(quantidade_liq_rede) OVER ()                        AS qtd_total_rede
    FROM vendas_produto_rede
)

/*
    SELECT final
    ------------
    Converte os acumulados em percentuais e aplica os thresholds de classificação.
    NULLIF(..., 0) evita divisão por zero em casos extremos.
    ROUND(..., 4) mantém 4 casas decimais no percentual acumulado para
    permitir análises de fronteira (produtos exatamente no limite A/B ou B/C).

    abc_rede é JOINado por produto_id apenas — o mesmo valor de classificação
    rede se repete para todas as lojas do produto, o que é o comportamento
    esperado (a posição do produto na rede não muda por loja).
*/
SELECT
    ae.empresa_id,
    ae.produto_id,
    ae.familia_id,
    ae.categoria_id,
    ae.receita_liq,
    ae.quantidade_liq,
    ar.receita_liq_rede,
    ar.quantidade_liq_rede,
    -- Curva ABC por empresa — valor
    ROUND(ae.receita_acum_empresa / NULLIF(ae.receita_total_empresa, 0), 4)         AS pct_acum_valor_empresa,
    CASE
        WHEN ae.receita_acum_empresa / NULLIF(ae.receita_total_empresa, 0) <= 0.80 THEN 'A'
        WHEN ae.receita_acum_empresa / NULLIF(ae.receita_total_empresa, 0) <= 0.95 THEN 'B'
        ELSE 'C'
    END                                                                             AS curva_abc_valor_empresa,
    -- Curva ABC por empresa — quantidade
    ROUND(ae.qtd_acum_empresa / NULLIF(ae.qtd_total_empresa, 0), 4)                 AS pct_acum_qtd_empresa,
    CASE
        WHEN ae.qtd_acum_empresa / NULLIF(ae.qtd_total_empresa, 0) <= 0.80 THEN 'A'
        WHEN ae.qtd_acum_empresa / NULLIF(ae.qtd_total_empresa, 0) <= 0.95 THEN 'B'
        ELSE 'C'
    END                                                                             AS curva_abc_qtd_empresa,
    -- Curva ABC por categoria x empresa — valor
    ROUND(ae.receita_acum_categoria / NULLIF(ae.receita_total_categoria, 0), 4)     AS pct_acum_valor_categoria,
    CASE
        WHEN ae.receita_acum_categoria / NULLIF(ae.receita_total_categoria, 0) <= 0.80 THEN 'A'
        WHEN ae.receita_acum_categoria / NULLIF(ae.receita_total_categoria, 0) <= 0.95 THEN 'B'
        ELSE 'C'
    END                                                                             AS curva_abc_valor_categoria,
    -- Curva ABC por categoria x empresa — quantidade
    ROUND(ae.qtd_acum_categoria / NULLIF(ae.qtd_total_categoria, 0), 4)             AS pct_acum_qtd_categoria,
    CASE
        WHEN ae.qtd_acum_categoria / NULLIF(ae.qtd_total_categoria, 0) <= 0.80 THEN 'A'
        WHEN ae.qtd_acum_categoria / NULLIF(ae.qtd_total_categoria, 0) <= 0.95 THEN 'B'
        ELSE 'C'
    END                                                                             AS curva_abc_qtd_categoria,
    -- Curva ABC rede — valor
    ROUND(ar.receita_acum_rede / NULLIF(ar.receita_total_rede, 0), 4)               AS pct_acum_valor_rede,
    CASE
        WHEN ar.receita_acum_rede / NULLIF(ar.receita_total_rede, 0) <= 0.80 THEN 'A'
        WHEN ar.receita_acum_rede / NULLIF(ar.receita_total_rede, 0) <= 0.95 THEN 'B'
        ELSE 'C'
    END                                                                             AS curva_abc_valor_rede,
    -- Curva ABC rede — quantidade
    ROUND(ar.qtd_acum_rede / NULLIF(ar.qtd_total_rede, 0), 4)                       AS pct_acum_qtd_rede,
    CASE
        WHEN ar.qtd_acum_rede / NULLIF(ar.qtd_total_rede, 0) <= 0.80 THEN 'A'
        WHEN ar.qtd_acum_rede / NULLIF(ar.qtd_total_rede, 0) <= 0.95 THEN 'B'
        ELSE 'C'
    END                                                                             AS curva_abc_qtd_rede,
    -- período de referência
    p.data_inicio                                                                   AS periodo_inicio,
    p.data_fim                                                                      AS periodo_fim,
    NOW()                                                                           AS carregado_em
FROM abc_empresa        ae
JOIN abc_rede           ar ON ar.produto_id = ae.produto_id
CROSS JOIN periodo      p
