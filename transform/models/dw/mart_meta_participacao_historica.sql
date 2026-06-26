{{ config(
    materialized='table'
) }}

{#
  Participacao % de cada loja e categoria no faturamento do grupo, PRE-
  CALCULADA mes a mes - independente de qualquer meta digitada. Separado do
  rateio (mart_meta_comercial) pra que aplicar uma meta nova seja so uma
  multiplicacao trivial sobre participacao ja pronta, em vez de escanear
  fato_venda toda vez que a diretoria digita um numero. Decisao registrada em
  docs/negocio/redesign_dashboards.md ("Meta comercial").

  Grao: mes_meta x anos_historico x empresa_id x categoria_id. mes_meta cobre
  o mes corrente + proximos 12 (rolling, atualiza todo dia no cold) -
  qualquer mes que a diretoria for digitar meta jah tem participacao
  calculada esperando. anos_historico cobre 1 a 3 (faixa recomendada no
  campo correspondente em meta_parametros).

  Mesma logica de mart_meta_referencia_grupo/mart_meta_comercial (ver lah pro
  detalhe de cada decisao): mesmo mes do calendario em cada ano anterior (nao
  trailing consecutivo - preserva sazonalidade de categoria), lojas ATIVAS
  hoje em todo o historico (like-for-like), fallback de loja/categoria nova
  com renormalizacao.
#}

WITH lojas_ativas AS (
    SELECT empresa_id
    FROM {{ ref('dim_empresa_info') }}
    WHERE status_empresa = 'ATIVA' AND empresa_id <> 1
),

total_lojas_ativas AS (
    SELECT COUNT(*) AS qtd FROM lojas_ativas
),

spine AS (
    SELECT
        DATE_TRUNC('month', mes_serie)::DATE AS mes_meta,
        anos.anos_historico
    FROM generate_series(
        DATE_TRUNC('month', CURRENT_DATE)::DATE,
        DATE_TRUNC('month', CURRENT_DATE)::DATE + INTERVAL '12 months',
        INTERVAL '1 month'
    ) AS mes_serie
    CROSS JOIN (VALUES (1), (2), (3)) AS anos(anos_historico)
),

-- Pra cada (mes_meta, anos_historico), os meses do passado a olhar: mesmo
-- mes do calendario, k anos atras, k = 1 .. anos_historico.
meses_referencia AS (
    SELECT
        s.mes_meta,
        s.anos_historico,
        (s.mes_meta - (gs.k * INTERVAL '12 months'))::DATE AS mes_historico
    FROM spine s
    CROSS JOIN LATERAL generate_series(1, s.anos_historico) AS gs(k)
),

vendas_categoria AS (
    SELECT
        DATE_TRUNC('month', v.data_venda)::DATE AS mes_historico,
        v.empresa_id,
        p.categoria_id,
        p.categoria_id_nome,
        SUM(v.valor_venda_liquido) AS faturamento
    FROM {{ ref('fato_venda') }} v
    INNER JOIN lojas_ativas l
        ON l.empresa_id = v.empresa_id
    INNER JOIN {{ ref('dim_produto_info') }} p
        ON p.produto_id = v.produto_id
    -- range sargable (usa o indice btree em data_venda) antes do filtro exato
    -- por DATE_TRUNC - sem isso, Postgres varre fato_venda inteira (111M+
    -- linhas) pra calcular DATE_TRUNC linha a linha antes de filtrar.
    WHERE v.data_venda >= (SELECT MIN(mes_historico) FROM meses_referencia)
        AND v.data_venda < (SELECT MAX(mes_historico) + INTERVAL '1 month' FROM meses_referencia)
        AND DATE_TRUNC('month', v.data_venda) IN (SELECT DISTINCT mes_historico FROM meses_referencia)
    GROUP BY 1, 2, 3, 4
),

historico_loja_categoria AS (
    SELECT
        mr.mes_meta,
        mr.anos_historico,
        vc.empresa_id,
        vc.categoria_id,
        vc.categoria_id_nome,
        SUM(vc.faturamento) AS faturamento_historico
    FROM meses_referencia mr
    INNER JOIN vendas_categoria vc ON vc.mes_historico = mr.mes_historico
    GROUP BY 1, 2, 3, 4, 5
),

historico_loja AS (
    SELECT
        mes_meta,
        anos_historico,
        empresa_id,
        SUM(faturamento_historico) AS faturamento_historico_loja
    FROM historico_loja_categoria
    GROUP BY 1, 2, 3
),

historico_grupo AS (
    SELECT
        mes_meta,
        anos_historico,
        SUM(faturamento_historico_loja) AS faturamento_historico_grupo
    FROM historico_loja
    GROUP BY 1, 2
),

-- Grade loja-ativa x (mes-meta, anos_historico) - inclusive lojas sem
-- nenhuma venda nos meses de referencia (lojas novas, fallback igual).
lojas_por_combinacao AS (
    SELECT s.mes_meta, s.anos_historico, l.empresa_id
    FROM spine s
    CROSS JOIN lojas_ativas l
),

participacao_loja_bruta AS (
    SELECT
        lpc.mes_meta,
        lpc.anos_historico,
        lpc.empresa_id,
        COALESCE(
            hl.faturamento_historico_loja / hg.faturamento_historico_grupo,
            1.0 / (SELECT qtd FROM total_lojas_ativas)
        ) AS participacao_loja
    FROM lojas_por_combinacao lpc
    LEFT JOIN historico_loja hl
        ON hl.mes_meta = lpc.mes_meta AND hl.anos_historico = lpc.anos_historico AND hl.empresa_id = lpc.empresa_id
    LEFT JOIN historico_grupo hg
        ON hg.mes_meta = lpc.mes_meta AND hg.anos_historico = lpc.anos_historico
),

-- Renormaliza pra somar 100% por (mes, anos_historico) - o fallback de loja
-- sem historico entraria por cima das participacoes reais, inflando o total.
participacao_loja AS (
    SELECT
        mes_meta,
        anos_historico,
        empresa_id,
        participacao_loja / SUM(participacao_loja) OVER (PARTITION BY mes_meta, anos_historico) AS participacao_loja_normalizada
    FROM participacao_loja_bruta
),

participacao_categoria_na_loja AS (
    SELECT
        hlc.mes_meta,
        hlc.anos_historico,
        hlc.empresa_id,
        hlc.categoria_id,
        hlc.categoria_id_nome,
        hlc.faturamento_historico / hl.faturamento_historico_loja AS participacao_categoria
    FROM historico_loja_categoria hlc
    INNER JOIN historico_loja hl
        ON hl.mes_meta = hlc.mes_meta AND hl.anos_historico = hlc.anos_historico AND hl.empresa_id = hlc.empresa_id
    WHERE hl.faturamento_historico_loja > 0
),

-- Todas as categorias que tiveram venda em ALGUMA loja, por (mes, anos_historico).
categorias_existentes AS (
    SELECT DISTINCT mes_meta, anos_historico, categoria_id, categoria_id_nome
    FROM historico_loja_categoria
),

-- Proxy de rede: media da participacao dessa categoria nas lojas onde ela
-- tem historico - usado quando a loja especifica nao tem.
participacao_categoria_proxy_rede AS (
    SELECT
        mes_meta,
        anos_historico,
        categoria_id,
        AVG(participacao_categoria) AS participacao_categoria_media_rede
    FROM participacao_categoria_na_loja
    GROUP BY 1, 2, 3
),

grade_loja_categoria AS (
    SELECT
        lpc.mes_meta,
        lpc.anos_historico,
        lpc.empresa_id,
        ce.categoria_id,
        ce.categoria_id_nome
    FROM lojas_por_combinacao lpc
    INNER JOIN categorias_existentes ce
        ON ce.mes_meta = lpc.mes_meta AND ce.anos_historico = lpc.anos_historico
),

participacao_categoria_bruta AS (
    SELECT
        g.mes_meta,
        g.anos_historico,
        g.empresa_id,
        g.categoria_id,
        g.categoria_id_nome,
        COALESCE(pc.participacao_categoria, pr.participacao_categoria_media_rede, 0)
            AS participacao_categoria
    FROM grade_loja_categoria g
    LEFT JOIN participacao_categoria_na_loja pc
        ON pc.mes_meta = g.mes_meta AND pc.anos_historico = g.anos_historico
        AND pc.empresa_id = g.empresa_id AND pc.categoria_id = g.categoria_id
    LEFT JOIN participacao_categoria_proxy_rede pr
        ON pr.mes_meta = g.mes_meta AND pr.anos_historico = g.anos_historico AND pr.categoria_id = g.categoria_id
),

-- Normaliza pra somar 100% por loja - o fallback de proxy de rede nao
-- garante isso por construcao.
participacao_categoria_normalizada AS (
    SELECT
        *,
        participacao_categoria / SUM(participacao_categoria) OVER (PARTITION BY mes_meta, anos_historico, empresa_id)
            AS participacao_categoria_normalizada
    FROM participacao_categoria_bruta
    WHERE participacao_categoria > 0
)

SELECT
    pl.mes_meta                                    AS mes,
    pl.anos_historico,
    pl.empresa_id,
    pcn.categoria_id,
    pcn.categoria_id_nome,
    pl.participacao_loja_normalizada,
    pcn.participacao_categoria_normalizada,
    now()                                          AS carregado_em
FROM participacao_loja pl
INNER JOIN participacao_categoria_normalizada pcn
    ON pcn.mes_meta = pl.mes_meta AND pcn.anos_historico = pl.anos_historico AND pcn.empresa_id = pl.empresa_id
ORDER BY pl.mes_meta, pl.anos_historico, pl.empresa_id, pcn.categoria_id
