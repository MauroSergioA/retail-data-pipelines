-- Garante que o grão mes × empresa_id × categoria_id é único no mart.
-- O teste falha se retornar qualquer linha (duplicatas encontradas).
SELECT
    mes,
    empresa_id,
    categoria_id,
    COUNT(*) AS qtd
FROM {{ ref('mart_meta_comercial') }}
GROUP BY mes, empresa_id, categoria_id
HAVING COUNT(*) > 1
