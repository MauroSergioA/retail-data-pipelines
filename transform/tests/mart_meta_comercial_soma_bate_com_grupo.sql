-- A soma de toda a meta rateada (todas as lojas x categorias) precisa bater
-- com a meta do grupo definida pela diretoria, em cada cenário. Detecta bug
-- de fallback de loja/categoria sem histórico somando por cima das
-- participações reais em vez de renormalizar (caso real encontrado e
-- corrigido em 2026-06-25 - inflava o total em até 1/n_lojas_ativas).
WITH soma_rateio AS (
    SELECT
        mes,
        SUM(meta_padrao_valor) AS soma_padrao,
        SUM(meta_desafio_valor) AS soma_desafio
    FROM {{ ref('mart_meta_comercial') }}
    GROUP BY mes
)

SELECT
    sr.mes,
    sr.soma_padrao,
    mp.meta_grupo_padrao_valor,
    sr.soma_desafio,
    mp.meta_grupo_desafio_valor
FROM soma_rateio sr
INNER JOIN {{ ref('stg_nocodb_meta_parametros') }} mp ON mp.mes = sr.mes
WHERE ABS(sr.soma_padrao - mp.meta_grupo_padrao_valor) > 1.0
    OR ABS(sr.soma_desafio - mp.meta_grupo_desafio_valor) > 1.0
