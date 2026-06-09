WITH source AS (
    SELECT * FROM {{ source('consinco', 'map_prodcodigo') }}
)

SELECT
    seqproduto::INTEGER           AS produto_id,
    qtdembalagem::INTEGER         AS qtd_embalagem,
    CASE UPPER(tipcodigo)
        WHEN 'I' THEN 'TRANSIÇÃO'
        WHEN 'E' THEN 'EAN'
        WHEN 'B' THEN 'BALANÇA'
        WHEN 'F' THEN 'FORNECEDOR'
        WHEN 'D' THEN 'DUN'
        ELSE UPPER(tipcodigo)
    END                           AS tipo_codigo,
    codacesso::TEXT               AS codigo_acesso,
    _loaded_at::TIMESTAMP         AS carregado_em
FROM source
