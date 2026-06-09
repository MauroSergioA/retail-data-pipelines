{{ config(
    materialized='incremental',
    unique_key=[
        'datahora_venda', 'empresa_id', 'documento_numero', 'serie_documento',
        'checkout_id', 'forma_pagto_id', 'segmento_id', 'cod_operacao',
        'produto_id', 'operador_id'
    ],
    on_schema_change='append_new_columns',
    incremental_strategy='delete+insert'
) }}

WITH stg AS (
    SELECT * FROM {{ ref('stg_maxv_abcdistribbase') }}
    {% if is_incremental() %}
    WHERE data_venda >= (
        SELECT MIN(datahora::DATE) FROM {{ source('consinco', 'maxv_abcdistribbase') }}
    )
    {% endif %}
)

SELECT
    datahora_venda,
    data_venda,
    hora_venda,
    empresa_id,
    documento_numero,
    serie_documento,
    checkout_id,
    documento_chave,
    forma_pagto_id,
    segmento_id,
    cod_operacao,
    produto_id,
    operador_id,
    qtd_venda,
    qtd_devolvido,
    qtd_venda_liquida,
    valor_venda,
    valor_devolvido,
    valor_venda_liquido,
    valor_desconto,
    valor_venda_promocao,
    valor_lucro,
    valor_custo_bruto,
    valor_custo_liquido,
    carregado_em
FROM stg
WHERE cod_operacao IN (800, 810, 820, 828, 202)