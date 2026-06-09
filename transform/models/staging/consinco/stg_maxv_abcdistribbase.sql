WITH source AS (
    SELECT * FROM {{ source('consinco', 'maxv_abcdistribbase') }}
)

SELECT
    datahora::TIMESTAMP                                     AS datahora_venda,
    datahora::DATE                                          AS data_venda,
    EXTRACT(HOUR FROM datahora)::INTEGER                    AS hora_venda,
    nroempresa::INTEGER                                     AS empresa_id,
    nrodocto::BIGINT                                        AS documento_numero,
    seriedocto::TEXT                                        AS serie_documento,
    checkout::INTEGER                                       AS checkout_id,
    LPAD(nroempresa::TEXT, 2, '0')
        || '-' || LPAD(nrodocto::TEXT, 9, '0')
        || '-' || seriedocto::TEXT
        || '-' || LPAD(checkout::TEXT, 2, '0')              AS documento_chave,
    nroformapagto::INTEGER                                  AS forma_pagto_id,
    nrosegmento::INTEGER                                    AS segmento_id,
    codgeraloper::INTEGER                                   AS cod_operacao,
    seqproduto::INTEGER                                     AS produto_id,
    seqoperador::INTEGER                                    AS operador_id,
    qtditem::NUMERIC                                        AS qtd_venda,
    qtddevolitem::NUMERIC                                   AS qtd_devolvido,
    (qtditem::NUMERIC - qtddevolitem::NUMERIC)              AS qtd_venda_liquida,
    vlritem::NUMERIC                                        AS valor_venda,
    vlrdevolitem::NUMERIC                                   AS valor_devolvido,
    (vlritem::NUMERIC - vlrdevolitem::NUMERIC)              AS valor_venda_liquido,
    vlrdescitem::NUMERIC                                    AS valor_desconto,
    vlrvendapromoc::NUMERIC                                 AS valor_venda_promocao,
    vlrlucro::NUMERIC                                       AS valor_lucro,
    ctobrutovda::NUMERIC                                    AS valor_custo_bruto,
    vlrctoliqvda::NUMERIC                                   AS valor_custo_liquido,
    _loaded_at::TIMESTAMP                                   AS carregado_em
FROM source