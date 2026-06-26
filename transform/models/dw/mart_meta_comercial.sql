{{ config(
    materialized='table',
    post_hook="{{ sync_meta_ajustes_calculado() }}"
) }}

{#
  Rateio da meta comercial do grupo (definida pela diretoria no NocoDB) por
  loja e categoria. Grao: mes x empresa_id x categoria_id - mesmo formato da
  planilha "Meta Vendas" que este model substitui (ver
  docs/negocio/redesign_dashboards.md, "Meta comercial - desenho fechado").

  So aplica a meta sobre a participacao JA CALCULADA em
  mart_meta_participacao_historica (mesma logica de mesmo-mes-ano-anterior,
  fallback de loja/categoria nova, etc. - ver lah pro detalhe) - nao escaneia
  fato_venda. Por isso roda em segundos, mesmo com 111M+ linhas de venda:
  toda a parte pesada jah foi pre-calculada antes de qualquer meta existir.
#}

WITH meta_parametros AS (
    SELECT * FROM {{ ref('stg_nocodb_meta_parametros') }}
),

ajustes_loja AS (
    SELECT * FROM {{ ref('stg_nocodb_meta_ajustes_loja') }}
),

participacao AS (
    SELECT * FROM {{ ref('mart_meta_participacao_historica') }}
),

-- participacao_loja_normalizada repete por categoria no mart de origem -
-- volta pro grao loja antes de aplicar a meta, senao a meta seria contada
-- uma vez por categoria (duplicada).
participacao_loja AS (
    SELECT DISTINCT mes, anos_historico, empresa_id, participacao_loja_normalizada
    FROM participacao
),

meta_loja AS (
    SELECT
        mp.mes AS mes_meta,
        pl.empresa_id,
        mp.meta_grupo_padrao_valor * pl.participacao_loja_normalizada + COALESCE(aj.ajuste_padrao_valor, 0)
            AS meta_loja_padrao_valor,
        mp.meta_grupo_desafio_valor * pl.participacao_loja_normalizada + COALESCE(aj.ajuste_desafio_valor, 0)
            AS meta_loja_desafio_valor
    FROM meta_parametros mp
    INNER JOIN participacao_loja pl
        ON pl.mes = mp.mes AND pl.anos_historico = mp.anos_historico
    LEFT JOIN ajustes_loja aj
        ON aj.mes = mp.mes AND aj.empresa_id = pl.empresa_id
)

SELECT
    ml.mes_meta                                                              AS mes,
    ml.empresa_id,
    p.categoria_id,
    p.categoria_id_nome,
    ROUND(ml.meta_loja_padrao_valor * p.participacao_categoria_normalizada, 2)
                                                                              AS meta_padrao_valor,
    ROUND(ml.meta_loja_desafio_valor * p.participacao_categoria_normalizada, 2)
                                                                              AS meta_desafio_valor,
    now()                                                                    AS carregado_em
FROM meta_loja ml
INNER JOIN meta_parametros mp ON mp.mes = ml.mes_meta
INNER JOIN participacao p
    ON p.mes = ml.mes_meta AND p.anos_historico = mp.anos_historico AND p.empresa_id = ml.empresa_id
ORDER BY ml.mes_meta, ml.empresa_id, p.categoria_id
