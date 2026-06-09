WITH source AS (
    SELECT * FROM {{ source('consinco', 'madv_origempedido') }}
)

SELECT
    origempedido::TEXT                                                           AS origempedido_id,
    UPPER(descorigempedido::TEXT)                                                AS origempedido,
    _loaded_at::TIMESTAMP                                                        AS carregado_em
FROM source