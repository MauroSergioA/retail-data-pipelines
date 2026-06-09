WITH produto AS (
    SELECT
        *
    FROM {{ ref('stg_map_produto') }}
),

produto_codigos as (
    SELECT
        produto_id,
        STRING_AGG(
            codigo_acesso,
            ' ; '
            ORDER BY
                CASE tipo_codigo WHEN 'EAN' THEN 1 ELSE 2 END,
                codigo_acesso
        ) AS codigo_acesso
    FROM {{ ref('stg_map_prodcodigo') }}
    WHERE tipo_codigo IN ('EAN','BALANÇA')
    AND codigo_acesso IS NOT NULL
    GROUP BY produto_id
),

familia AS (
    SELECT
        *
    FROM {{ ref('stg_map_familia') }}
),

marca AS (
    SELECT
        *   
    FROM {{ ref('stg_map_marca') }}
),

categoria AS (
    SELECT
        *
    FROM {{ ref('stg_etlv_categoria') }}        
),

fornecedor_principal AS (
    SELECT
        *
    FROM {{ ref('stg_map_famfornec') }}        
    WHERE fornecedor_principal = 'SIM'
),

pessoa AS (
    SELECT 
        *   
    FROM {{ ref('stg_ge_pessoa') }}
)

SELECT
    -- produto
    p.produto_id,
    p.produto,
    p.produto_id_nome,
    pc.codigo_acesso,
    -- familia
    f.familia_id,
    f.familia,
    f.familia_id_nome,
    f.pesavel,
    f.permite_decimal,
    -- categoria 
    CASE
        WHEN c.categoria_id IS NULL THEN 0
        ELSE c.categoria_id
    END                                                                         AS categoria_id,
    CASE
        WHEN c.categoria IS NULL THEN 'NÃO DEFINIDA'
        ELSE c.categoria
    END                                                                         AS categoria,
    CASE
        WHEN c.categoria_id_nome IS NULL THEN '0000 - NÃO DEFINIDA'
        ELSE c.categoria_id_nome
    END                                                                         AS categoria_id_nome,
    CASE
        WHEN c.subcategoria_id IS NULL THEN 0
        ELSE c.subcategoria_id
    END                                                                         AS subcategoria_id,
    CASE
        WHEN c.subcategoria IS NULL THEN 'NÃO DEFINIDA'
        ELSE c.subcategoria
    END                                                                         AS subcategoria,
    CASE
        WHEN c.subcategoria_id_nome IS NULL THEN '0000 - NÃO DEFINIDA'
        ELSE c.subcategoria_id_nome
    END                                                                         AS subcategoria_id_nome,
    CASE
        WHEN c.grupo_id IS NULL THEN 0
        ELSE c.grupo_id
    END                                                                         AS grupo_id,
    CASE
        WHEN c.grupo IS NULL THEN 'NÃO DEFINIDO'
        ELSE c.grupo
    END                                                                         AS grupo,
    CASE
        WHEN c.grupo_id_nome IS NULL THEN '0000 - NÃO DEFINIDO'
        ELSE c.grupo_id_nome
    END                                                                         AS grupo_id_nome,
    CASE
        WHEN c.sk_categoria IS NULL THEN 0
        ELSE c.sk_categoria
    END                                                                         AS sk_categoria,
    CASE
        WHEN c.categoria_completa IS NULL THEN 'NÃO DEFINIDO'
        ELSE c.categoria_completa
    END                                                                         AS categoria_completa,
    CASE
        WHEN c.categoria_completa_id_nome IS NULL THEN '0000 - NÃO DEFINIDO'
        ELSE c.categoria_completa_id_nome
    END                                                                         AS categoria_completa_id_nome,
    CASE
        WHEN c.perecivel IS NULL THEN 'NÃO'
        ELSE c.perecivel
    END                                                                         AS perecivel,
    -- marca
    CASE
        WHEN m.marca_id IS NULL THEN 0
        ELSE m.marca_id
    END                                                                         AS marca_id,
    CASE
        WHEN m.marca IS NULL THEN 'NÃO DEFINIDA'
        ELSE m.marca
    END                                                                         AS marca,
    CASE
        WHEN m.marca_id_nome IS NULL THEN '0000 - NÃO DEFINIDA'
        ELSE m.marca_id_nome
    END                                                                         AS marca_id_nome,
    -- fornecedor_principal
    CASE
        WHEN fp.fornecedor_id IS NULL THEN 0
        ELSE fp.fornecedor_id
    END                                                                         AS fornecedor_principal_id,
    CASE
        WHEN g.nome_razao IS NULL THEN 'NÃO DEFINIDO'
        ELSE g.nome_razao
    END                                                                         AS fornecedor_principal,
    CASE
        WHEN g.nome_razao_id_nome IS NULL THEN 'NÃO DEFINIDO'
        ELSE g.nome_razao_id_nome
    END                                                                         AS fornecedor_principal_id_nome,
    -- auditoria
    p.data_inclusao,
    p.carregado_em
FROM produto                        p
LEFT JOIN familia                   f   ON f.familia_id     = p.familia_id
LEFT JOIN marca                     m   ON m.marca_id       = f.marca_id
LEFT JOIN categoria                 c   ON c.familia_id     = f.familia_id
LEFT JOIN produto_codigos           pc  ON pc.produto_id    = p.produto_id
LEFT JOIN fornecedor_principal      fp  ON fp.familia_id    = f.familia_id
LEFT JOIN pessoa                    g   ON g.pessoa_id      = fp.fornecedor_id
