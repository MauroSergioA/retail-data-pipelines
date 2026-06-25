-- Regra de negócio: ajuste manual é sempre redistribuição zero-sum entre
-- lojas (tira de uma, leva pra outra) — nunca muda o total do grupo.
-- O teste falha se a soma dos ajustes de algum mês, em algum cenário
-- (padrão/desafio), não fechar em zero (tolerância de 1 centavo por
-- arredondamento).
SELECT
    mes,
    SUM(ajuste_padrao_valor) AS soma_ajuste_padrao,
    SUM(ajuste_desafio_valor) AS soma_ajuste_desafio
FROM {{ ref('stg_nocodb_meta_ajustes_loja') }}
GROUP BY mes
HAVING ABS(SUM(ajuste_padrao_valor)) > 0.01
    OR ABS(SUM(ajuste_desafio_valor)) > 0.01
