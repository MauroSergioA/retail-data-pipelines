WITH source AS (
    SELECT * FROM {{ source('consinco', 'max_empresa') }}
)

SELECT
    nroempresa::INTEGER                                                         AS empresa_id,
    nrodivisao::INTEGER                                                         AS divisao_id,
    UPPER(razaosocial)::TEXT                                                    AS razao_social,
    LPAD(seqpessoaemp::TEXT, 5, '0') || ' - ' || UPPER(razaosocial)::TEXT       AS pessoa_id_razao,
    UPPER(endereco)::TEXT                                                       AS logradouro,
    UPPER(bairro)::TEXT                                                         AS bairro,
    cep::TEXT                                                                   AS cep,
    UPPER(cidade)::TEXT                                                         AS cidade,
    UPPER(uf)::TEXT                                                             AS uf,
    CONCAT_WS(
        ' - ',
        UPPER(endereco)::TEXT,
        UPPER(bairro)::TEXT,
        UPPER(cep)::TEXT,
        UPPER(cidade)::TEXT,
        UPPER(uf)::TEXT
    )                                                                           AS endereco,
    LPAD(nrocgc::TEXT, 12, '0') || '-' || LPAD(digcgc::NUMERIC::TEXT, 2, '0')   AS cnpj,
    UPPER(inscricaoestadual)::TEXT                                              AS inscricao_estadual,
    nrometro2loja::NUMERIC                                                      AS metro_quadrado,
    seqpessoaemp::NUMERIC                                                       AS pessoa_id,
    nrosegmentoprinc::NUMERIC                                                   AS segmento_principal,
    CASE UPPER(indabertsabado)
        WHEN 'S' THEN 'SIM'
        ELSE 'NÃO'
    END                                                                         AS aberto_sabado,
    CASE UPPER(indabertdomingo)
        WHEN 'S' THEN 'SIM'
        ELSE 'NÃO'
    END                                                                         AS aberto_domingo,
    metagermargemlucro::NUMERIC                                                 AS meta_margem_lucro,
    metagerdiaestq::NUMERIC                                                     AS meta_dia_estoque,
    CASE 
        WHEN UPPER(status) = 'A' THEN 'ATIVA'
        ELSE 'INATIVA'
    END                                                                         AS status_empresa,
    dtafechafiscal::DATE                                                        AS dta_fechamento_fiscal,
    dtainiciomovestoque::DATE                                                   AS inicio_estoque,
    nronsunf::INTEGER                                                           AS nsu_nf,
    cgobaixasaidapdv::INTEGER                                                   AS cgo_baixa_saida_pdv,
    cgotransflocori::INTEGER                                                    AS cgo_transf_loc_ori,
    cgotransflocdest::INTEGER                                                   AS cgo_transf_loc_dest,
    cgobaixaproducao::INTEGER                                                   AS cgo_baixa_producao,
    cgoentrproducao::INTEGER                                                    AS cgo_entr_producao,
    cgobaixainventario::INTEGER                                                 AS cgo_baixa_inventario,
    cgoentrinventario::INTEGER                                                  AS cgo_entr_inventario,
    cgoemissnfvenda::INTEGER                                                    AS cgo_emiss_nf_venda,
    cgoenttransf::INTEGER                                                       AS cgo_entr_transf,
    cgodevfornec::INTEGER                                                       AS cgo_dev_fornec,
    cgoenttransfprod::INTEGER                                                   AS cgo_entr_transf_prod,
    cgosaitransfprod::INTEGER                                                   AS cgo_sai_transf_prod,
    cgobaixaperda::INTEGER                                                      AS cgo_baixa_perda,
    cgoajustecusto::INTEGER                                                     AS cgo_ajuste_custo,
    cgoajustecustoredu::INTEGER                                                 AS cgo_ajuste_custo_redu,
    _loaded_at::TIMESTAMP                                                       AS carregado_em
FROM source
