WITH source AS (
    SELECT * FROM {{ source('consinco', 'madv_tippedido') }}
)

SELECT
    tippedido::TEXT                                                         AS tippedido_id,
    UPPER(desctippedido::TEXT)                                              AS tippedido,
    _loaded_at::TIMESTAMP                                                   AS carregado_em
FROM source