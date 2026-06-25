WITH source AS (
    SELECT * FROM {{ source('enriquecimento', 'indicadores_mercado_externo') }}
)

SELECT
    data_referencia::DATE     AS data_referencia,
    UPPER(indicador)::TEXT    AS indicador,
    valor::NUMERIC            AS valor,
    UPPER(fonte)::TEXT        AS fonte,
    _loaded_at::TIMESTAMP     AS carregado_em
FROM source
