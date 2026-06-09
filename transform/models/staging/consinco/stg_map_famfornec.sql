WITH fornecedor_familia AS (
    SELECT * FROM {{ source('consinco', 'map_famfornec') }}
)

SELECT
    seqfamilia::INTEGER             AS familia_id,
    seqfornecedor::INTEGER          AS fornecedor_id,
    CASE UPPER(principal)
        WHEN 'S' THEN 'SIM'
        ELSE 'NÃO'
    END                             AS fornecedor_principal,
    CASE UPPER(indindenizavaria)
        WHEN 'S' THEN 'SIM'
        WHEN 'N' THEN 'NÃO'
        ELSE 'NÃO INFORMADO'
    END                             AS indeniza_avaria,
    _loaded_at::TIMESTAMP           AS carregado_em
FROM fornecedor_familia

