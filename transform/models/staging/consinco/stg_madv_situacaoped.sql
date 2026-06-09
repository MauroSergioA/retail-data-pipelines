WITH source AS (
    SELECT * FROM {{ source('consinco', 'madv_situacaoped') }}
)

SELECT
    situacaoped::TEXT                                                           AS situacaoped_id,
    UPPER(descsituacaoped::TEXT)                                                AS situacaoped,
    _loaded_at::TIMESTAMP                                                       AS carregado_em
FROM source