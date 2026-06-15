{{ config(materialized='table', tags=['monthly']) }}

WITH periodo AS (
    SELECT
        MAX(dta_entrada)                             AS data_fim,
        MAX(dta_entrada) - INTERVAL '12 months'      AS data_inicio
    FROM {{ ref('fato_entrada') }}
),

base AS (
    SELECT
        fe.fornecedor_id,
        fe.empresa_id,
        fe.dias_leadtime,
        fe.vlr_total_nf
    FROM {{ ref('fato_entrada') }} fe
    CROSS JOIN periodo p
    WHERE fe.cod_geral_oper IN (1, 11, 105, 107, 200, 205)
      AND fe.dta_entrada BETWEEN p.data_inicio AND p.data_fim
      AND fe.dias_leadtime >= 0
      AND fe.dias_leadtime <= 180
),

agregado AS (
    SELECT
        fornecedor_id,
        empresa_id,
        COUNT(*)                                             AS qtd_notas,
        ROUND(AVG(dias_leadtime), 1)                        AS media_leadtime,
        MIN(dias_leadtime)                                   AS min_leadtime,
        MAX(dias_leadtime)                                   AS max_leadtime,
        ROUND(STDDEV(dias_leadtime), 1)                     AS desvio_padrao_leadtime,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY dias_leadtime
        )::INTEGER                                           AS mediana_leadtime,
        SUM(vlr_total_nf)                                    AS vlr_total_nf,
        ROUND(
            SUM(dias_leadtime::NUMERIC * vlr_total_nf)
            / NULLIF(SUM(vlr_total_nf), 0),
            1
        )                                                    AS media_leadtime_ponderado
    FROM base
    GROUP BY fornecedor_id, empresa_id
)

SELECT
    a.fornecedor_id,
    a.empresa_id,
    a.qtd_notas,
    a.media_leadtime,
    a.min_leadtime,
    a.max_leadtime,
    a.desvio_padrao_leadtime,
    a.mediana_leadtime,
    a.media_leadtime_ponderado,
    a.vlr_total_nf,
    f.prazo_med_entrega                                      AS prazo_cadastrado,
    f.prazo_med_atraso                                       AS atraso_cadastrado,
    p.data_inicio                                            AS periodo_inicio,
    p.data_fim                                               AS periodo_fim,
    CURRENT_TIMESTAMP                                        AS carregado_em
FROM agregado a
CROSS JOIN periodo p
LEFT JOIN {{ ref('dim_fornecedor_info') }} f
    ON a.fornecedor_id = f.fornecedor_id
