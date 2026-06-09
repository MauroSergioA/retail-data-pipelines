-- Garante que o grain empresa_id × produto_id é único no mart.
-- O teste falha se retornar qualquer linha (duplicatas encontradas).
SELECT
    empresa_id,
    produto_id,
    COUNT(*) AS qtd
FROM {{ ref('mart_curva_abc') }}
GROUP BY empresa_id, produto_id
HAVING COUNT(*) > 1
