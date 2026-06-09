WITH source AS (
    SELECT * FROM {{ source('consinco', 'mad_segmento') }}
)

SELECT
    nrodivisao::INTEGER                                                            AS divisao_id,
    nrosegmento::INTEGER                                                           AS segmento_id,
    UPPER(descsegmento::TEXT)                                                      AS segmento,
    LPAD(nrosegmento::TEXT, 3, '0') || ' - ' || UPPER(descsegmento::TEXT)          AS segmento_id_nome,
    CASE
        WHEN UPPER(status::TEXT) = 'A' THEN 'ATIVO'
        ELSE 'INATIVO'
    END                                                                            AS status,
    _loaded_at::TIMESTAMP                                                          AS carregado_em
FROM source