WITH source AS (
    SELECT * FROM {{ source('nocodb', 'meta_parametros') }}
)

SELECT
    mes::DATE                                                      AS mes,
    meta_grupo_padrao_valor::NUMERIC                               AS meta_grupo_padrao_valor,
    COALESCE(meta_grupo_desafio_valor, meta_grupo_padrao_valor)::NUMERIC
                                                                    AS meta_grupo_desafio_valor,
    COALESCE(anos_historico, 2)::INT                               AS anos_historico
FROM source
