WITH source AS (
    SELECT * FROM {{ source('consinco', 'map_familia') }}
)

SELECT
    seqfamilia::INTEGER                                                     AS familia_id,
    UPPER(familia)::TEXT                                                    AS familia,
    LPAD(seqfamilia::TEXT, 6, '0') || ' - ' || UPPER(familia)::TEXT         AS familia_id_nome,
    CASE
        WHEN seqmarca IS NULL THEN 0
        ELSE seqmarca::INTEGER
    END                                                                     AS marca_id,
    CASE UPPER(pesavel)
        WHEN 'S' THEN 'SIM'
        ELSE 'NÃO'
    END                                                                     AS pesavel,
    CASE UPPER(pmtdecimal)
        WHEN 'S' THEN 'SIM'
        ELSE 'NÃO'
    END                                                                     AS permite_decimal,
    _loaded_at::TIMESTAMP                                                   AS carregado_em
FROM source
