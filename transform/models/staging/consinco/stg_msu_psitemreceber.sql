WITH source AS (
    SELECT * FROM {{ source('consinco', 'msu_psitemreceber') }}
)

SELECT
    nropedidosuprim::BIGINT          AS pedido_id,
    nroempresa::INTEGER              AS empresa_id,
    CASE UPPER(centralloja)
        WHEN 'L' THEN 'LOJA'
        WHEN 'M' THEN 'MATRIZ'
        ELSE UPPER(centralloja)::TEXT
    END                              AS central_loja,
    seqproduto::INTEGER              AS produto_id,
    seqitem::INTEGER                 AS item_seq,
    qtdsolicitada::NUMERIC           AS qtd_solicitada,
    qtdsolicitadaoriginal::NUMERIC   AS qtd_solicitada_original,
    qtdembalagem::NUMERIC            AS qtd_embalagem,
    qtdaprovada::NUMERIC             AS qtd_aprovada,
    qtdtotrecebida::NUMERIC          AS qtd_tot_recebida,
    qtdtotcancelada::NUMERIC         AS qtd_tot_cancelada,
    qtdtottransito::NUMERIC          AS qtd_tot_transito,
    CASE UPPER(statusitem)
        WHEN 'A' THEN 'ABERTO'
        WHEN 'C' THEN 'CANCELADO'
        WHEN 'P' THEN 'PENDENTE'
        ELSE UPPER(statusitem)::TEXT
    END                              AS status_item,
    dtaaprovacao::DATE               AS dta_aprovacao,
    dtarecebtoitem::DATE             AS dta_recebto_item,
    vlrunitario::NUMERIC             AS vlr_unitario,
    vlrembitem::NUMERIC              AS vlr_emb_item,
    vlrembipi::NUMERIC               AS vlr_emb_ipi,
    vlrembicmsst::NUMERIC            AS vlr_emb_icmsst,
    vlrembverbacompra::NUMERIC       AS vlr_emb_verba_compra,
    estoque::NUMERIC                 AS estoque,
    UPPER(observacaoitem)::TEXT      AS observacao_item,
    UPPER(motivopendencia)::TEXT     AS motivo_pendencia,
    dtaalteracao::DATE               AS dta_alteracao,
    UPPER(usualteracao)::TEXT        AS usu_alteracao,
    _loaded_at::TIMESTAMP            AS carregado_em
FROM source
