WITH source AS (
    SELECT * FROM {{ source('nocodb', 'meta_ajustes_loja') }}
)

SELECT
    mes::DATE                                  AS mes,
    empresa_id::INT                            AS empresa_id,
    COALESCE(ajuste_padrao_valor, 0)::NUMERIC  AS ajuste_padrao_valor,
    COALESCE(ajuste_desafio_valor, 0)::NUMERIC AS ajuste_desafio_valor
FROM source
