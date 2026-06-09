WITH source AS (
    SELECT * FROM {{ source('consinco', 'mrl_produtoempresa') }}
)

SELECT
    seqproduto::INTEGER                         AS produto_id,
    nroempresa::INTEGER                         AS empresa_id,
    -- status
    CASE UPPER(statuscompra)
        WHEN 'A' THEN 'ATIVO'
        WHEN 'I' THEN 'INATIVO'
        ELSE 'NÃO INFORMADO'
    END                                         AS status_compra,
    -- locais de estoque
    locentrada::INTEGER                         AS local_entrada_id,
    locsaida::INTEGER                           AS local_saida_id,
    -- estoques
    estqloja::NUMERIC                           AS estoque_loja,
    estqdeposito::NUMERIC                       AS estoque_deposito,
    estqtroca::NUMERIC                          AS estoque_troca,
    estqalmoxarifado::NUMERIC                   AS estoque_almoxarifado,
    estqoutro::NUMERIC                          AS estoque_outro,
    estqempresa::NUMERIC                        AS estoque_empresa,
    -- pedidos e recebimentos pendentes (colunas depreciadas no Oracle, mantidas para histórico)
    qtdpendpedcompra_depreciada::NUMERIC        AS qtd_pedido_compra_pendente,
    qtdpendpedexped_depreciada::NUMERIC         AS qtd_pedido_expedicao_pendente,
    qtdpedrectransito_depreciada::NUMERIC       AS qtd_recebimento_transito,
    -- médias de venda
    medvdiageral::NUMERIC                       AS media_venda_diaria,
    medvdiaforapromoc::NUMERIC                  AS media_venda_diaria_fora_promo,
    -- dias de estoque
    CASE
        WHEN medvdiageral IS NULL OR medvdiageral = 0 THEN NULL
        ELSE ROUND(estqloja / medvdiageral, 1)
    END                                         AS dias_estoque,
    -- custos
    cmultcusliquidoemp::NUMERIC                 AS ultimo_custo_liquido,
    cmultvlrnf::NUMERIC                         AS ultimo_valor_nf,
    -- indicadores
    CASE UPPER(indgeraruptura)
        WHEN 'S' THEN 'SIM'
        WHEN 'N' THEN 'NÃO'
        ELSE 'NÃO INFORMADO'
    END                                         AS gera_ruptura,
    -- datas de movimentação geral
    dtaultmovtacao::DATE                        AS dta_ultima_movimentacao,
    dtaultmoventrada::DATE                      AS dta_ultima_movimentacao_entrada,
    dtaultmovsaida::DATE                        AS dta_ultima_movimentacao_saida,
    -- última entrada (NF)
    dtaultentrada::DATE                         AS dta_ultima_entrada,
    qtdultentrada::NUMERIC                      AS qtd_ultima_entrada,
    -- última compra
    dtaultcompra::DATE                          AS dta_ultima_compra,
    qtdultcompra::NUMERIC                       AS qtd_ultima_compra,
    -- dias sem compra
    CASE
        WHEN dtaultcompra IS NULL THEN NULL
        ELSE (CURRENT_DATE - dtaultcompra::DATE)::INTEGER
    END                                         AS dias_sem_compra,
    -- última venda
    dtaultvenda::DATE                           AS dta_ultima_venda,
    qtdultvenda::NUMERIC                        AS qtd_ultima_venda,
    -- dias sem venda
    CASE
        WHEN dtaultvenda IS NULL THEN NULL
        ELSE (CURRENT_DATE - dtaultvenda::DATE)::INTEGER
    END                                         AS dias_sem_venda,
    -- dia sem venda desde última entrada
    CASE
        WHEN dtaultvenda IS NULL AND dtaultmoventrada IS NULL THEN NULL
        ELSE (CURRENT_DATE - GREATEST(
            COALESCE(dtaultvenda::DATE,        '1900-01-01'::DATE),
            COALESCE(dtaultmoventrada::DATE,   '1900-01-01'::DATE)
        ))::INTEGER
    END                                         AS dias_sem_venda_desde_ultima_entrada,
    -- último inventário
    dtaultinvfisico::DATE                       AS dta_ultimo_inventario,
    qtdultimoinventario::NUMERIC                AS qtd_ultimo_inventario,
    -- auditoria
    _loaded_at::TIMESTAMP                       AS carregado_em
FROM source
