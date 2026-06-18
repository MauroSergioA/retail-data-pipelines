{{ config(
    materialized='incremental',
    unique_key='movimento_id',
    on_schema_change='append_new_columns',
    incremental_strategy='delete+insert'
) }}

WITH stg AS (
    SELECT * FROM {{ ref('stg_mrl_lanctoestoque') }}
    {% if is_incremental() %}
    WHERE dta_movimento >= (
        SELECT MIN(dtaentradasaida::DATE) FROM {{ source('consinco', 'mrl_lanctoestoque') }}
    )
    {% endif %}
),

local AS (
    SELECT * FROM {{ ref('stg_mrl_local') }}
)

SELECT
    stg.movimento_id,
    stg.empresa_id,
    stg.dta_movimento,
    stg.dta_hor_lancto,
    stg.produto_id,
    stg.produto_base_id,
    stg.local_id,
    loc.descricao_local,
    loc.tipo_local,
    loc.status_local,
    stg.cod_geral_oper,
    stg.tip_uso_cgo,
    stg.tip_lancto,
    stg.qtd_lancto,
    stg.vlr_nf_lancto,
    stg.nro_documento,
    stg.motivo_movto,
    stg.lote_estoque_id,
    stg.historico,
    stg.carregado_em
FROM stg
LEFT JOIN local loc ON loc.empresa_id = stg.empresa_id AND loc.local_id = stg.local_id
