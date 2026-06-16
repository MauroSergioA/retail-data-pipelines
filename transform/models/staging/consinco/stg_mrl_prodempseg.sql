WITH source AS (
    SELECT * FROM {{ source('consinco', 'mrl_prodempseg') }}
)

SELECT
    -- chave composta
    seqproduto::INTEGER                         AS produto_id,
    qtdembalagem::NUMERIC                       AS qtd_embalagem,
    nrosegmento::INTEGER                        AS segmento_id,
    nroempresa::INTEGER                         AS empresa_id,
    -- status de venda
    CASE UPPER(statusvenda)
        WHEN 'A' THEN 'ATIVO'
        WHEN 'I' THEN 'INATIVO'
        ELSE 'NÃO INFORMADO'
    END                                         AS status_venda,
    -- preços normais
    precobasenormal::NUMERIC                    AS preco_base_normal,
    precogernormal::NUMERIC                     AS preco_ger_normal,
    precovalidnormal::NUMERIC                   AS preco_valido_normal,
    -- preços em promoção
    precogerpromoc::NUMERIC                     AS preco_ger_promoc,
    precovalidpromoc::NUMERIC                   AS preco_valido_promoc,
    precoemitidopromoc::NUMERIC                 AS preco_emitido_promoc,
    -- margem e custo para precificação
    margemlucroprodempseg::NUMERIC              AS margem_lucro,
    vlrcustoliqdiaprecif::NUMERIC               AS custo_liq_precificacao,
    -- motivos de alteração de preço (auditoria)
    UPPER(motivoprecobase)::TEXT                AS motivo_preco_base,
    UPPER(motivoprecogerado)::TEXT              AS motivo_preco_gerado,
    UPPER(motivoprecovalido)::TEXT              AS motivo_preco_valido,
    -- datas de ciclo de preço
    dtageracaopreco::DATE                       AS dta_geracao_preco,
    dtavalidacaopreco::DATE                     AS dta_validacao_preco,
    dtaalteracao::DATE                          AS dta_alteracao,
    datahoraalteracao::TIMESTAMP                AS dta_hora_alteracao_preco,
    dtahoraltstatusvda::TIMESTAMP               AS dta_hora_alt_status_venda,
    -- preço programado (agendado para vigorar)
    precogernormalprog::NUMERIC                 AS preco_ger_programado,
    dtageracaoprecoprog::DATE                   AS dta_preco_programado,
    -- revisão de preço
    CASE UPPER(indrevisaopreco)
        WHEN 'S' THEN 'SIM'
        WHEN 'N' THEN 'NÃO'
        ELSE 'NÃO INFORMADO'
    END                                         AS ind_revisao_preco,
    -- vínculo com promoção
    seqpromocao::INTEGER                        AS promocao_id,
    -- auditoria
    _loaded_at::TIMESTAMP                       AS carregado_em
FROM source
