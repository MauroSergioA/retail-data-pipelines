WITH source AS (
    SELECT * FROM {{ source('consinco', 'mrl_promocaoitem') }}
)

SELECT
    -- chave composta (qtdembalagem = 1 filtrado na extração Oracle)
    seqproduto::INTEGER                         AS produto_id,
    qtdembalagem::NUMERIC                       AS qtd_embalagem,
    seqpromocao::INTEGER                        AS promocao_id,
    nroempresa::INTEGER                         AS empresa_id,
    nrosegmento::INTEGER                        AS segmento_id,
    UPPER(centralloja)::TEXT                    AS central_loja,
    -- preços
    precopromocional::NUMERIC                   AS preco_promocional,
    precosugerido::NUMERIC                      AS preco_sugerido,
    -- status e desconto
    CASE UPPER(status)
        WHEN 'A' THEN 'ATIVO'
        WHEN 'I' THEN 'INATIVO'
        ELSE 'NÃO INFORMADO'
    END                                         AS status,
    percdescpromoc::NUMERIC                     AS perc_desconto,
    -- vigência do item (pode sobrescrever o cabeçalho)
    dtainicioprom::DATE                         AS dta_inicio_item,
    dtafimprom::DATE                            AS dta_fim_item,
    -- métricas de vendas na promoção
    qtdprevistavda::NUMERIC                     AS qtd_prevista_venda,
    qtdtotalvda::NUMERIC                        AS qtd_total_vendida,
    vlrtotalvda::NUMERIC                        AS vlr_total_vendido,
    qtdmediavdapromoc::NUMERIC                  AS media_venda_promoc,
    -- acordo comercial
    nroacordo::INTEGER                          AS acordo_id,
    -- auditoria
    dtainclusao::DATE                           AS dta_inclusao,
    dtageracao::DATE                            AS dta_geracao,
    dtahoraalteracao::TIMESTAMP                 AS dta_hora_alteracao,
    UPPER(usualteracao)::TEXT                   AS usuario_alteracao,
    _loaded_at::TIMESTAMP                       AS carregado_em
FROM source
