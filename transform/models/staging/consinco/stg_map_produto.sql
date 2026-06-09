WITH source AS (
    SELECT * FROM {{ source('consinco', 'map_produto') }}
)

SELECT
    seqproduto::INTEGER                                                     AS produto_id,
    UPPER(desccompleta)::TEXT                                               AS produto,
    LPAD(seqproduto::TEXT, 6, '0') || ' - ' || UPPER(desccompleta)::TEXT    AS produto_id_nome,
    seqfamilia::INTEGER                                                     AS familia_id,
    dtahorinclusao::DATE                                                    AS data_inclusao,
    _loaded_at::TIMESTAMP                                                   AS carregado_em
FROM source
