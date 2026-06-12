{{ config(
    materialized='table',
    tags=['monthly']
) }}

-- Leadtime real de entrega por fornecedor × loja × mês.
-- Grain: fornecedor_id × empresa_id × mes_referencia.
-- Filtrado em compras diretas (cod_geral_oper IN (1, 11)) — operações de entrada de mercadoria.
-- Outliers excluídos: leadtime negativo (erro de data no Oracle) e acima de 180 dias.

WITH base AS (
    SELECT
        fe.fornecedor_id,
        fe.empresa_id,
        DATE_TRUNC('month', fe.dta_entrada)::DATE            AS mes_referencia,
        fe.dias_leadtime,
        fe.vlr_total_nf
    FROM {{ ref('fato_entrada') }} fe
    WHERE fe.cod_geral_oper IN (1, 11)
      AND fe.dias_leadtime >= 0
      AND fe.dias_leadtime <= 180
),

agregado AS (
    SELECT
        fornecedor_id,
        empresa_id,
        mes_referencia,
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
    GROUP BY fornecedor_id, empresa_id, mes_referencia
)

SELECT
    a.fornecedor_id,
    a.empresa_id,
    a.mes_referencia,
    a.qtd_notas,
    a.media_leadtime,
    a.min_leadtime,
    a.max_leadtime,
    a.desvio_padrao_leadtime,
    a.mediana_leadtime,
    a.media_leadtime_ponderado,
    a.vlr_total_nf,
    f.nome_razao                                             AS fornecedor,
    f.nome_razao_id_nome                                     AS fornecedor_id_nome,
    f.prazo_med_entrega                                      AS prazo_cadastrado,
    f.prazo_med_atraso                                       AS atraso_cadastrado,
    CURRENT_TIMESTAMP                                        AS carregado_em
FROM agregado a
LEFT JOIN {{ ref('dim_fornecedor_info') }} f
    ON a.fornecedor_id = f.fornecedor_id
