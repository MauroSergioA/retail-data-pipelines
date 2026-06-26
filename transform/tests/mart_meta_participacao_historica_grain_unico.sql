-- Garante que o grão mes × anos_historico × empresa_id × categoria_id é
-- único no mart. O teste falha se retornar qualquer linha (duplicatas).
SELECT
    mes,
    anos_historico,
    empresa_id,
    categoria_id,
    COUNT(*) AS qtd
FROM {{ ref('mart_meta_participacao_historica') }}
GROUP BY mes, anos_historico, empresa_id, categoria_id
HAVING COUNT(*) > 1
