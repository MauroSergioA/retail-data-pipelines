{{ config(
    materialized='incremental',
    unique_key=['dta_movimento', 'empresa_id', 'produto_id'],
    on_schema_change='append_new_columns',
    incremental_strategy='delete+insert',
    indexes=[
      {'columns': ['dta_movimento', 'empresa_id', 'produto_id'], 'unique': True},
      {'columns': ['dta_movimento'], 'type': 'btree'},
      {'columns': ['empresa_id'], 'type': 'btree'},
      {'columns': ['produto_id'], 'type': 'btree'}
    ]
) }}

WITH stg AS (
    SELECT * FROM {{ ref('stg_mrl_custodia') }}
    {% if is_incremental() %}
    WHERE dta_movimento >= (
        SELECT MIN(dtaentradasaida::DATE) FROM {{ source('consinco', 'mrl_custodia') }}
    )
    {% endif %}
)

SELECT
    dta_movimento,
    empresa_id,
    produto_id,
    qtd_estoque_inicial,
    qtd_entrada,
    qtd_saida,
    qtd_estoque_final,
    qtd_compra,
    vlr_total_compra,
    qtd_venda,
    vlr_total_venda,
    vlr_custo_liquido_venda,
    vlr_custo_bruto_venda,
    qtd_devolucao,
    vlr_total_devolucao,
    vlr_custo_liquido_devolucao,
    custo_medio_dia_nf,
    custo_medio_dia_liquido,
    carregado_em
FROM stg
