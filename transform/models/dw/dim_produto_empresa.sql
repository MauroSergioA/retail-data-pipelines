WITH pe AS (
    SELECT * FROM {{ ref('stg_mrl_produtoempresa') }}
),

empresa AS (
    SELECT
        empresa_id,
        status_empresa,
        segmento_principal
    FROM {{ ref('dim_empresa_info') }}
),

preco AS (
    SELECT * FROM {{ ref('stg_mrl_prodempseg') }}
),

fornec_produto AS (
    SELECT produto_id, fornecedor_principal_id
    FROM {{ ref('dim_produto_info') }}
),

fornec_ultima_entrada AS (
    SELECT DISTINCT ON (produto_id, empresa_id)
        produto_id,
        empresa_id,
        fornecedor_id AS fornecedor_ultima_entrada_id
    FROM {{ ref('fato_entrada') }}
    WHERE cod_geral_oper IN (1, 11, 105, 107, 200, 205)
    ORDER BY produto_id, empresa_id, dta_entrada DESC
),

tempo_entrega AS (
    SELECT
        fornecedor_id,
        empresa_id,
        media_leadtime          AS tempo_entrega_medio_dias,
        desvio_padrao_leadtime  AS tempo_entrega_desvio_padrao
    FROM {{ ref('mart_leadtime_fornecedor') }}
),

promoc_vigente AS (
    SELECT DISTINCT ON (pi.produto_id, pi.empresa_id, pi.segmento_id)
        pi.produto_id,
        pi.empresa_id,
        pi.segmento_id,
        pi.promocao_id,
        pi.preco_promocional,
        pi.perc_desconto,
        COALESCE(pi.dta_inicio_item, p.dta_inicio)  AS dta_inicio_promoc,
        COALESCE(pi.dta_fim_item,    p.dta_fim)      AS dta_fim_promoc
    FROM {{ ref('stg_mrl_promocaoitem') }}    pi
    INNER JOIN {{ ref('stg_mrl_promocao') }}  p
           ON  p.promocao_id  = pi.promocao_id
           AND p.empresa_id   = pi.empresa_id
           AND p.segmento_id  = pi.segmento_id
           AND p.central_loja = pi.central_loja
    WHERE pi.status = 'ATIVO'
      AND COALESCE(pi.dta_inicio_item, p.dta_inicio) <= CURRENT_DATE
      AND COALESCE(pi.dta_fim_item,    p.dta_fim)    >= CURRENT_DATE
    ORDER BY pi.produto_id, pi.empresa_id, pi.segmento_id,
             COALESCE(pi.dta_fim_item, p.dta_fim) ASC
)

SELECT
    -- chaves de relacionamento
    pe.produto_id,
    pe.empresa_id,
    -- conveniência: filtro de loja ativa sem precisar de join
    e.status_empresa,
    -- fornecedores (FK para dim_fornecedor_info)
    fp.fornecedor_principal_id,
    fue.fornecedor_ultima_entrada_id,
    -- tempo de entrega (do fornecedor da última entrada — snapshot mensal)
    te.tempo_entrega_medio_dias,
    te.tempo_entrega_desvio_padrao,
    -- status por loja
    pe.status_compra,
    pr.status_venda,
    pe.gera_ruptura,
    -- promoção vigente
    CASE 
        WHEN pv.promocao_id IS NULL THEN 'NÃO'
        ELSE 'SIM'
    END                             AS ind_em_promoc,
    pv.promocao_id                  AS promocao_vigente_id,
    pv.preco_promocional            AS preco_promoc_vigente,
    pv.perc_desconto                AS perc_desconto_promoc,
    pv.dta_inicio_promoc,
    pv.dta_fim_promoc,
    -- locais de estoque
    pe.local_entrada_id,
    pe.local_saida_id,
    -- estoques
    pe.estoque_loja,
    pe.estoque_deposito,
    pe.estoque_troca,
    pe.estoque_almoxarifado,
    pe.estoque_outro,
    pe.estoque_empresa,
    -- pedidos pendentes
    pe.qtd_pedido_compra_pendente,
    pe.qtd_pedido_expedicao_pendente,
    pe.qtd_recebimento_transito,
    -- médias de venda
    pe.media_venda_diaria,
    pe.media_venda_diaria_fora_promo,
    -- dias de estoque calculado (estoque_loja ÷ media_venda_diaria)
    pe.dias_estoque,
    -- preços pelo segmento principal da loja
    pr.preco_base_normal,
    pr.preco_ger_normal,
    pr.preco_valido_normal,
    pr.preco_ger_promoc,
    pr.preco_valido_promoc,
    pr.margem_lucro,
    pr.custo_liq_precificacao,
    pr.motivo_preco_valido,
    pr.dta_geracao_preco,
    pr.dta_validacao_preco,
    pr.dta_hora_alteracao           AS dta_hora_alteracao_preco,
    pr.dta_hora_alt_status_venda,
    pr.preco_ger_programado,
    pr.dta_preco_programado,
    pr.ind_revisao_preco,
    pr.promocao_id,
    -- custos (mrl_produtoempresa)
    pe.ultimo_custo_liquido,
    pe.ultimo_valor_nf,
    -- datas de movimentação
    pe.dta_ultima_movimentacao,
    pe.dta_ultima_movimentacao_entrada,
    pe.dta_ultima_movimentacao_saida,
    -- última entrada (NF)
    pe.dta_ultima_entrada,
    pe.qtd_ultima_entrada,
    -- última compra
    pe.dta_ultima_compra,
    pe.qtd_ultima_compra,
    pe.dias_sem_compra,
    -- última venda
    pe.dta_ultima_venda,
    pe.qtd_ultima_venda,
    pe.dias_sem_venda,
    pe.dias_sem_venda_desde_ultima_entrada,
    -- último inventário
    pe.qtd_ultimo_inventario,
    -- auditoria
    pe.carregado_em
FROM pe
LEFT JOIN fornec_produto       fp  ON fp.produto_id          = pe.produto_id
LEFT JOIN fornec_ultima_entrada fue ON fue.produto_id         = pe.produto_id
                                   AND fue.empresa_id         = pe.empresa_id
LEFT JOIN tempo_entrega        te  ON te.fornecedor_id        = fue.fornecedor_ultima_entrada_id
                                   AND te.empresa_id          = pe.empresa_id
LEFT JOIN empresa              e   ON e.empresa_id            = pe.empresa_id
LEFT JOIN preco          pr ON pr.produto_id   = pe.produto_id
                           AND pr.empresa_id   = pe.empresa_id
                           AND pr.segmento_id  = e.segmento_principal
                           AND pr.qtd_embalagem = 1
LEFT JOIN promoc_vigente pv ON pv.produto_id   = pe.produto_id
                           AND pv.empresa_id   = pe.empresa_id
                           AND pv.segmento_id  = e.segmento_principal
