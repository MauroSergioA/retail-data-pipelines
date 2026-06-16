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
        fe.tempo_entrega_dias,
        fe.vlr_total_nf
    FROM {{ ref('fato_entrada') }} fe
    CROSS JOIN periodo p
    WHERE fe.cod_geral_oper IN (1, 11, 105, 107, 200, 205)
      AND fe.dta_entrada BETWEEN p.data_inicio AND p.data_fim
      AND fe.tempo_entrega_dias >= 0
      AND fe.tempo_entrega_dias <= 180
),

agregado AS (
    SELECT
        fornecedor_id,
        empresa_id,
        COUNT(*)                                                AS qtd_notas,
        ROUND(AVG(tempo_entrega_dias), 1)                       AS media_tempo_entrega,
        MIN(tempo_entrega_dias)                                 AS min_tempo_entrega,
        MAX(tempo_entrega_dias)                                 AS max_tempo_entrega,
        ROUND(STDDEV(tempo_entrega_dias), 1)                    AS desvio_padrao_tempo_entrega,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY tempo_entrega_dias
        )::INTEGER                                              AS mediana_tempo_entrega,
        SUM(vlr_total_nf)                                       AS vlr_total_nf,
        ROUND(
            SUM(tempo_entrega_dias::NUMERIC * vlr_total_nf)
            / NULLIF(SUM(vlr_total_nf), 0),
            1
        )                                                       AS media_tempo_entrega_ponderado
    FROM base
    GROUP BY fornecedor_id, empresa_id
)

SELECT
    a.fornecedor_id,
    a.empresa_id,
    a.qtd_notas,
    a.media_tempo_entrega,
    a.min_tempo_entrega,
    a.max_tempo_entrega,
    a.desvio_padrao_tempo_entrega,
    a.mediana_tempo_entrega,
    a.media_tempo_entrega_ponderado,
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
