WITH source AS (
    SELECT * FROM {{ source('consinco', 'map_marca') }}
)

SELECT
    seqmarca::INTEGER                                       AS marca_id,
    UPPER(marca)::TEXT                                      AS marca,
    LPAD(seqmarca::TEXT, 4, '0') || ' - ' || UPPER(marca)   AS marca_id_nome,
    CASE
        WHEN UPPER(status) = 'A' THEN 'ATIVA'
        WHEN UPPER(status) = 'I' THEN 'INATIVA'
        ELSE 'NÃO INFORMADA'
    END                                                     AS status_marca,
    _loaded_at::TIMESTAMP                                   AS carregado_em
FROM source