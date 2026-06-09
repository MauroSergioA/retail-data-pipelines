WITH source AS (
    SELECT * FROM {{ source('consinco', 'vw_pdv') }}
)

SELECT
    nroempresa::INTEGER                               AS empresa_id,
    nrocheckout::INTEGER                              AS checkout_id,
    nrosegmento::INTEGER                              AS segmento_id,
    CASE
        WHEN UPPER(ativo) = 'S' THEN 'SIM'
        ELSE 'NÃO'
    END                                               AS pdv_ativo,
    _loaded_at::TIMESTAMP                             AS carregado_em
FROM source
