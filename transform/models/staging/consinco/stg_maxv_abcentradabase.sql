WITH source AS (
    SELECT * FROM {{ source('consinco', 'maxv_abcentradabase') }}
)

SELECT
    nroempresa::INTEGER                                      AS empresa_id,
    dtaentrada::DATE                                         AS dta_entrada,
    dtaemissao::DATE                                         AS dta_emissao,
    (dtaentrada::DATE - dtaemissao::DATE)::INTEGER           AS dias_leadtime,
    seqproduto::INTEGER                                      AS produto_id,
    nrodocto::BIGINT                                         AS nro_docto,
    seqfornecedor::INTEGER                                   AS fornecedor_id,
    nrodocumento::TEXT                                       AS nro_documento,
    codgeraloper::INTEGER                                    AS cod_geral_oper,
    operador::INTEGER                                        AS operador_id,
    qtdembalagem::NUMERIC                                    AS qtd_embalagem,
    quantidade::NUMERIC                                      AS quantidade,
    vlrentrada::NUMERIC                                      AS vlr_entrada,
    vlrcustobruto::NUMERIC                                   AS vlr_custo_bruto,
    vlrcustoliquido::NUMERIC                                 AS vlr_custo_liquido,
    vlrproduto::NUMERIC                                      AS vlr_produto,
    vlrtotalnf::NUMERIC                                      AS vlr_total_nf,
    vlrdescontos::NUMERIC                                    AS vlr_descontos,
    custofiscaltotalentrada::NUMERIC                         AS vlr_custo_fiscal_total,
    prazomediopag::NUMERIC                                   AS prazo_medio_pagamento,
    _loaded_at::TIMESTAMP                                    AS carregado_em
FROM source
