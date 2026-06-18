{{ config(
    materialized='incremental',
    unique_key=[
        'dta_entrada', 'nro_documento', 'produto_id',
        'cod_geral_oper', 'operador', 'qtd_embalagem'
    ],
    on_schema_change='append_new_columns',
    incremental_strategy='delete+insert',
    indexes=[
      {'columns': ['dta_entrada'], 'type': 'btree'},
      {'columns': ['empresa_id'], 'type': 'btree'},
      {'columns': ['produto_id'], 'type': 'btree'}
    ]
) }}

WITH stg AS (
    SELECT * FROM {{ ref('stg_maxv_abcentradabase') }}
    {% if is_incremental() %}
    WHERE dta_entrada >= (
        SELECT MIN(dtaentrada::DATE) FROM {{ source('consinco', 'maxv_abcentradabase') }}
    )
    {% endif %}
)

SELECT
    empresa_id,
    dta_entrada,
    dta_emissao,
    tempo_entrega_dias,
    produto_id,
    nro_docto,
    fornecedor_id,
    nro_documento,
    cod_geral_oper,
    operador,
    qtd_embalagem,
    quantidade,
    vlr_entrada,
    vlr_custo_bruto,
    vlr_custo_liquido,
    vlr_produto,
    vlr_total_nf,
    vlr_descontos,
    vlr_custo_fiscal_total,
    prazo_medio_pagamento,
    carregado_em
FROM stg
