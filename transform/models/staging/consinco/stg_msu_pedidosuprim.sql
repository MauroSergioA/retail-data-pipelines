WITH source AS (
    SELECT * FROM {{ source('consinco', 'msu_pedidosuprim') }}
)

SELECT
    nropedidosuprim::BIGINT          AS pedido_id,
    nroempresa::INTEGER              AS empresa_id,
    CASE UPPER(centralloja)
        WHEN 'L' THEN 'LOJA'
        WHEN 'M' THEN 'MATRIZ'
        ELSE UPPER(centralloja)::TEXT
    END                              AS central_loja,
    seqcomprador::INTEGER            AS comprador_id,
    seqfornecedor::INTEGER           AS fornecedor_id,
    CASE UPPER(tippedidosuprim)
        WHEN 'X' THEN 'TRANSFERÊNCIA EXPEDIR'
        WHEN 'T' THEN 'TRANSFERÊNCIA A RECEBER'
        WHEN 'C' THEN 'COMPRA'
        WHEN 'B' THEN 'BONIF INCIDÊNCIA CUSTO'
        WHEN 'E' THEN 'BONIF SEM INCID CUSTO'
        WHEN 'I' THEN 'BRINDE'
        WHEN 'M' THEN 'IMPORTAÇÃO DIRETA'
        ELSE UPPER(tippedidosuprim)::TEXT
    END                              AS tip_pedido_suprim,
    CASE UPPER(situacaoped)
        WHEN 'L' THEN 'LIBERADO'
        WHEN 'A' THEN 'ANÁLISE'
        WHEN 'R' THEN 'ROTEIRIZAÇÃO'
        WHEN 'S' THEN 'SEPARAÇÃO'
        WHEN 'F' THEN 'FATURADO'
        WHEN 'C' THEN 'CANCELADO'
        WHEN 'D' THEN 'DIGITAÇÃO'
        WHEN 'P' THEN 'PRÉ-SEPARAÇÃO'
        WHEN 'W' THEN 'SEPARADO'
        ELSE UPPER(situacaoped)::TEXT
    END                              AS situacao_ped,
    dtaemissao::DATE                 AS dta_emissao,
    dtaemissaooriginal::DATE         AS dta_emissao_original,
    dtarecebto::DATE                 AS dta_recebto,
    dtarecebtooriginal::DATE         AS dta_recebto_original,
    dtalimiterecebto::DATE           AS dta_limite_recebto,
    dtahorinclusao::TIMESTAMP        AS dta_hor_inclusao,
    dtaaprovacao::DATE               AS dta_aprovacao,
    UPPER(usuaprovacao)::TEXT        AS usu_aprovacao,
    justificativaaprovacao::TEXT     AS justificativa_aprovacao,
    UPPER(pzopagamento)::TEXT        AS pzo_pagamento,
    UPPER(condicaofrete)::TEXT       AS condicao_frete,
    txvendor::NUMERIC                AS tx_vendor,
    UPPER(nropedfornecedor)::TEXT    AS nro_ped_fornecedor,
    UPPER(observacao)::TEXT          AS observacao,
    qtdtotsolicitada::NUMERIC        AS qtd_tot_solicitada,
    qtdtotrecebida::NUMERIC          AS qtd_tot_recebida,
    qtdtotcancelada::NUMERIC         AS qtd_tot_cancelada,
    qtdtottransito::NUMERIC          AS qtd_tot_transito,
    qtdtotaprovada::NUMERIC          AS qtd_tot_aprovada,
    vlrtotpedido::NUMERIC            AS vlr_tot_pedido,
    vlrtotcancelado::NUMERIC         AS vlr_tot_cancelado,
    vlrtotrecebido::NUMERIC          AS vlr_tot_recebido,
    codgeraloper::INTEGER            AS cod_geral_oper,
    seqtransportador::INTEGER        AS transportador_id,
    UPPER(motivopendencia)::TEXT     AS motivo_pendencia,
    codigopendencia::INTEGER         AS codigo_pendencia,
    diasprorrogacao::INTEGER         AS dias_prorrogacao,
    nropedsuprimorig::BIGINT         AS nro_ped_suprim_orig,
    nroempresaorig::INTEGER          AS empresa_orig_id,
    CASE UPPER(centrallojaorig)
        WHEN 'L' THEN 'LOJA'
        WHEN 'M' THEN 'MATRIZ'
        ELSE UPPER(centrallojaorig)::TEXT
    END                              AS central_loja_orig,
    UPPER(tipopedvenda)::TEXT        AS tipo_ped_venda,
    UPPER(indtransfempsec)::TEXT     AS ind_transf_emp_sec,
    nrorequisicao::BIGINT            AS nro_requisicao,
    _loaded_at::TIMESTAMP            AS carregado_em
FROM source
