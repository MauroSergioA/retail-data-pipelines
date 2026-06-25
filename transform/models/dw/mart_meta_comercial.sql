{{ config(
    materialized='table',
    tags=['monthly'],
    post_hook="{{ sync_meta_ajustes_calculado() }}"
) }}

{#
  Rateio da meta comercial do grupo (definida pela diretoria no NocoDB) por
  loja e categoria. Grao: mes x empresa_id x categoria_id - mesmo formato da
  planilha "Meta Vendas" que este model substitui (ver
  docs/negocio/redesign_dashboards.md, "Meta comercial - desenho fechado").

  Cascata:
  1. participacao % de cada loja no faturamento do grupo (empresa_id <> 1,
     so lojas ATIVAS hoje - like-for-like, mesmo criterio do
     mart_meta_referencia_grupo) + ajuste manual zero-sum -> meta da loja.
  2. participacao % de cada categoria dentro do faturamento da loja -> meta
     da loja x categoria.

  Em ambos os niveis, participacao usa o MESMO MES em cada um dos
  `anos_historico` anos anteriores (nao trailing consecutivo) - preserva o
  mix sazonal de categoria (ex.: Material Escolar pesa mais em jan/fev,
  Decoracao Natalina em dez; uma media flat de meses corridos dilui esse
  pico e sub-aloca a meta dessas categorias justamente no mes que importa).

  Fallback pra combinacao sem historico:
  - Loja nova (sem nenhuma venda nos meses de referencia): participacao =
    1 / numero de lojas ativas (peso igual entre todas).
  - Categoria nova numa loja especifica (existe em outras lojas mas nunca
    vendeu nessa): participacao = media da % dessa categoria nas OUTRAS
    lojas no mesmo mes (proxy de rede), depois normalizada pra somar 100%
    com as demais categorias da loja.
#}

WITH meta_parametros AS (
    SELECT * FROM {{ ref('stg_nocodb_meta_parametros') }}
),

ajustes_loja AS (
    SELECT * FROM {{ ref('stg_nocodb_meta_ajustes_loja') }}
),

lojas_ativas AS (
    SELECT empresa_id
    FROM {{ ref('dim_empresa_info') }}
    WHERE status_empresa = 'ATIVA' AND empresa_id <> 1
),

total_lojas_ativas AS (
    SELECT COUNT(*) AS qtd FROM lojas_ativas
),

-- Pra cada mes-meta, os meses do passado a olhar: mesmo mes do calendario,
-- k anos atras, k = 1 .. anos_historico.
meses_referencia AS (
    SELECT
        mp.mes AS mes_meta,
        mp.meta_grupo_padrao_valor,
        mp.meta_grupo_desafio_valor,
        (mp.mes - (gs.k * INTERVAL '12 months'))::DATE AS mes_historico
    FROM meta_parametros mp
    CROSS JOIN LATERAL generate_series(1, mp.anos_historico) AS gs(k)
),

vendas_categoria AS (
    SELECT
        DATE_TRUNC('month', v.data_venda)::DATE AS mes_historico,
        v.empresa_id,
        p.categoria_id,
        p.categoria_id_nome,
        SUM(v.valor_venda_liquido) AS faturamento
    FROM {{ ref('fato_venda') }} v
    INNER JOIN lojas_ativas l
        ON l.empresa_id = v.empresa_id
    INNER JOIN {{ ref('dim_produto_info') }} p
        ON p.produto_id = v.produto_id
    -- range sargable (usa o indice btree em data_venda) antes do filtro exato
    -- por DATE_TRUNC - sem isso, Postgres varre fato_venda inteira (111M+
    -- linhas) pra calcular DATE_TRUNC linha a linha antes de filtrar.
    WHERE v.data_venda >= (SELECT MIN(mes_historico) FROM meses_referencia)
        AND v.data_venda < (SELECT MAX(mes_historico) + INTERVAL '1 month' FROM meses_referencia)
        AND DATE_TRUNC('month', v.data_venda) IN (SELECT DISTINCT mes_historico FROM meses_referencia)
    GROUP BY 1, 2, 3, 4
),

historico_loja_categoria AS (
    SELECT
        mr.mes_meta,
        vc.empresa_id,
        vc.categoria_id,
        vc.categoria_id_nome,
        SUM(vc.faturamento) AS faturamento_historico
    FROM meses_referencia mr
    INNER JOIN vendas_categoria vc ON vc.mes_historico = mr.mes_historico
    GROUP BY 1, 2, 3, 4
),

historico_loja AS (
    SELECT
        mes_meta,
        empresa_id,
        SUM(faturamento_historico) AS faturamento_historico_loja
    FROM historico_loja_categoria
    GROUP BY 1, 2
),

historico_grupo AS (
    SELECT
        mes_meta,
        SUM(faturamento_historico_loja) AS faturamento_historico_grupo
    FROM historico_loja
    GROUP BY 1
),

-- Grade loja-ativa x mes-meta (inclusive lojas sem nenhuma venda nos meses de
-- referencia - lojas novas, que precisam do fallback de participacao igual).
lojas_por_mes AS (
    SELECT mp.mes AS mes_meta, l.empresa_id
    FROM meta_parametros mp
    CROSS JOIN lojas_ativas l
),

participacao_loja_bruta AS (
    SELECT
        lpm.mes_meta,
        lpm.empresa_id,
        COALESCE(
            hl.faturamento_historico_loja / hg.faturamento_historico_grupo,
            1.0 / (SELECT qtd FROM total_lojas_ativas)
        ) AS participacao_loja
    FROM lojas_por_mes lpm
    LEFT JOIN historico_loja hl
        ON hl.mes_meta = lpm.mes_meta AND hl.empresa_id = lpm.empresa_id
    LEFT JOIN historico_grupo hg
        ON hg.mes_meta = lpm.mes_meta
),

-- Renormaliza pra somar 100% por mes - o fallback de loja sem historico
-- (1/n_lojas_ativas) entraria por cima das participacoes reais (que ja
-- somam 100% entre as lojas COM historico), inflando o total do grupo.
participacao_loja AS (
    SELECT
        mes_meta,
        empresa_id,
        participacao_loja / SUM(participacao_loja) OVER (PARTITION BY mes_meta) AS participacao_loja
    FROM participacao_loja_bruta
),

meta_loja AS (
    SELECT
        mp.mes AS mes_meta,
        pl.empresa_id,
        mp.meta_grupo_padrao_valor * pl.participacao_loja + COALESCE(aj.ajuste_padrao_valor, 0)
            AS meta_loja_padrao_valor,
        mp.meta_grupo_desafio_valor * pl.participacao_loja + COALESCE(aj.ajuste_desafio_valor, 0)
            AS meta_loja_desafio_valor
    FROM participacao_loja pl
    INNER JOIN meta_parametros mp ON mp.mes = pl.mes_meta
    LEFT JOIN ajustes_loja aj
        ON aj.mes = pl.mes_meta AND aj.empresa_id = pl.empresa_id
),

participacao_categoria_na_loja AS (
    SELECT
        hlc.mes_meta,
        hlc.empresa_id,
        hlc.categoria_id,
        hlc.categoria_id_nome,
        hlc.faturamento_historico / hl.faturamento_historico_loja AS participacao_categoria
    FROM historico_loja_categoria hlc
    INNER JOIN historico_loja hl
        ON hl.mes_meta = hlc.mes_meta AND hl.empresa_id = hlc.empresa_id
    WHERE hl.faturamento_historico_loja > 0
),

-- Todas as categorias que tiveram venda em ALGUMA loja, por mes-meta -
-- universo completo de categorias que precisam de meta em toda loja ativa.
categorias_existentes AS (
    SELECT DISTINCT mes_meta, categoria_id, categoria_id_nome
    FROM historico_loja_categoria
),

-- Proxy de rede: media da participacao dessa categoria nas lojas onde ela
-- tem historico, por mes-meta - usado quando a loja especifica nao tem.
participacao_categoria_proxy_rede AS (
    SELECT
        mes_meta,
        categoria_id,
        AVG(participacao_categoria) AS participacao_categoria_media_rede
    FROM participacao_categoria_na_loja
    GROUP BY 1, 2
),

grade_loja_categoria AS (
    SELECT
        lpm.mes_meta,
        lpm.empresa_id,
        ce.categoria_id,
        ce.categoria_id_nome
    FROM lojas_por_mes lpm
    INNER JOIN categorias_existentes ce ON ce.mes_meta = lpm.mes_meta
),

participacao_categoria_bruta AS (
    SELECT
        g.mes_meta,
        g.empresa_id,
        g.categoria_id,
        g.categoria_id_nome,
        COALESCE(pc.participacao_categoria, pr.participacao_categoria_media_rede, 0)
            AS participacao_categoria
    FROM grade_loja_categoria g
    LEFT JOIN participacao_categoria_na_loja pc
        ON pc.mes_meta = g.mes_meta AND pc.empresa_id = g.empresa_id AND pc.categoria_id = g.categoria_id
    LEFT JOIN participacao_categoria_proxy_rede pr
        ON pr.mes_meta = g.mes_meta AND pr.categoria_id = g.categoria_id
),

-- Normaliza pra somar 100% por loja - o fallback de proxy de rede nao
-- garante isso por construcao (cada categoria foi estimada de forma
-- independente).
participacao_categoria_normalizada AS (
    SELECT
        *,
        participacao_categoria / SUM(participacao_categoria) OVER (PARTITION BY mes_meta, empresa_id)
            AS participacao_categoria_normalizada
    FROM participacao_categoria_bruta
    WHERE participacao_categoria > 0
)

SELECT
    ml.mes_meta                                                              AS mes,
    ml.empresa_id,
    pcn.categoria_id,
    pcn.categoria_id_nome,
    ROUND(ml.meta_loja_padrao_valor * pcn.participacao_categoria_normalizada, 2)
                                                                              AS meta_padrao_valor,
    ROUND(ml.meta_loja_desafio_valor * pcn.participacao_categoria_normalizada, 2)
                                                                              AS meta_desafio_valor,
    now()                                                                    AS carregado_em
FROM meta_loja ml
INNER JOIN participacao_categoria_normalizada pcn
    ON pcn.mes_meta = ml.mes_meta AND pcn.empresa_id = ml.empresa_id
ORDER BY ml.mes_meta, ml.empresa_id, pcn.categoria_id
