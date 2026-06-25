{{ config(
    materialized='table'
) }}

{#
  Apoio a definicao da meta do grupo (ver docs/negocio/redesign_dashboards.md,
  secao "Apoio a Definicao de Meta do Grupo"). Para cada mes (incluindo o mes
  seguinte ao ultimo mes com venda real, como projecao), calcula:

  - Parte 1 (tendencia interna): faturamento do mesmo mes no ano anterior x
    taxa de crescimento suavizada (media dos ultimos 6 meses de crescimento
    YoY) = sugestao_meta_nominal. Empresa 1 (MATRIZ) excluida, mesmo criterio
    do rateio por loja (ver Fact_MetaVenda original).
  - Parte 2 (contexto externo): IPCA de alimentos acumulado 12m e variacao
    anual do setor de hiper/supermercados (IBGE PMC) - nao mudam o numero
    sugerido, sao contexto pra diretoria avaliar se o crescimento e real ou
    so inflacao, e se a rede esta performando melhor ou peor que o setor.

  Todas as taxas em pontos percentuais (ex.: 5.2 = 5,2%), nao fracao.
#}

WITH spine AS (
    SELECT generate_series(
        DATE_TRUNC('month', (SELECT MIN(data_venda) FROM {{ ref('fato_venda') }}))::DATE,
        DATE_TRUNC('month', (SELECT MAX(data_venda) FROM {{ ref('fato_venda') }}))::DATE + INTERVAL '1 month',
        INTERVAL '1 month'
    )::DATE AS mes
),

vendas_mensal AS (
    SELECT
        DATE_TRUNC('month', data_venda)::DATE AS mes,
        SUM(valor_venda_liquido) AS faturamento
    FROM {{ ref('fato_venda') }}
    WHERE empresa_id <> 1
    GROUP BY 1
),

base AS (
    SELECT
        s.mes,
        v.faturamento
    FROM spine s
    LEFT JOIN vendas_mensal v ON v.mes = s.mes
),

com_ano_anterior AS (
    SELECT
        mes,
        faturamento,
        LAG(faturamento, 12) OVER (ORDER BY mes) AS faturamento_ano_anterior,
        -- mes do ultimo dado de venda real - qualquer mes a partir dele (inclusive)
        -- esta incompleto/em andamento, nao serve pra calcular crescimento
        (SELECT DATE_TRUNC('month', MAX(data_venda))::DATE FROM {{ ref('fato_venda') }}) AS mes_corrente_incompleto
    FROM base
),

crescimento AS (
    SELECT
        mes,
        faturamento,
        faturamento_ano_anterior,
        mes_corrente_incompleto,
        CASE
            WHEN mes >= mes_corrente_incompleto THEN NULL
            WHEN faturamento IS NOT NULL AND faturamento_ano_anterior > 0
                THEN ((faturamento / faturamento_ano_anterior) - 1) * 100
            ELSE NULL
        END AS crescimento_yoy_mensal
    FROM com_ano_anterior
),

crescimento_suavizado AS (
    SELECT
        mes,
        faturamento,
        faturamento_ano_anterior,
        mes_corrente_incompleto,
        crescimento_yoy_mensal,
        -- media dos ultimos 6 meses ANTERIORES ao mes atual (exclui o proprio mes,
        -- assim funciona igual pra historico real e pra projecao do mes seguinte)
        AVG(crescimento_yoy_mensal) OVER (
            ORDER BY mes ROWS BETWEEN 6 PRECEDING AND 1 PRECEDING
        ) AS crescimento_yoy_medio_6m
    FROM crescimento
),

ipca_alimentos AS (
    SELECT
        data_referencia AS mes,
        valor AS ipca_alimentos_mensal
    FROM {{ ref('stg_indicadores_mercado_externo') }}
    WHERE indicador = 'IPCA_ALIMENTOS_BEBIDAS'
),

ipca_acumulado AS (
    SELECT
        mes,
        ipca_alimentos_mensal,
        -- soma simples dos ultimos 12 meses como aproximacao do acumulado 12m
        -- (nao composto - suficiente pra contexto, nao pra precisao financeira)
        SUM(ipca_alimentos_mensal) OVER (
            ORDER BY mes ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ) AS ipca_alimentos_acumulado_12m
    FROM ipca_alimentos
),

pmc_setor AS (
    SELECT
        data_referencia AS mes,
        valor AS pmc_var_anual_setor
    FROM {{ ref('stg_indicadores_mercado_externo') }}
    WHERE indicador = 'PMC_HIPER_SUPER_VAR_ANUAL'
)

SELECT
    c.mes,
    c.faturamento                                                     AS faturamento_realizado,
    c.faturamento_ano_anterior,
    ROUND(c.crescimento_yoy_mensal, 2)                                AS crescimento_yoy_mensal,
    ROUND(c.crescimento_yoy_medio_6m, 2)                              AS crescimento_yoy_medio_6m,
    ROUND(c.faturamento_ano_anterior * (1 + c.crescimento_yoy_medio_6m / 100), 2)
                                                                       AS sugestao_meta_nominal,
    ROUND(i.ipca_alimentos_acumulado_12m, 2)                          AS ipca_alimentos_acumulado_12m,
    ROUND(p.pmc_var_anual_setor, 2)                                   AS pmc_var_anual_setor,
    ROUND(c.crescimento_yoy_medio_6m - i.ipca_alimentos_acumulado_12m, 2)
                                                                       AS crescimento_real_estimado,
    ROUND(c.crescimento_yoy_medio_6m - p.pmc_var_anual_setor, 2)      AS diferenca_vs_setor,
    CASE
        WHEN c.mes > c.mes_corrente_incompleto THEN 'PROJEÇÃO'
        WHEN c.mes = c.mes_corrente_incompleto THEN 'EM ANDAMENTO'
        ELSE 'REALIZADO'
    END                                                                AS tipo_linha,
    now()                                                              AS carregado_em
FROM crescimento_suavizado c
LEFT JOIN ipca_acumulado i ON i.mes = c.mes
LEFT JOIN pmc_setor p ON p.mes = c.mes
ORDER BY c.mes
