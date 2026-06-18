WITH source AS (
    SELECT * FROM {{ source('consinco', 'mrl_custodia') }}
)

SELECT
    seqproduto::INTEGER                               AS produto_id,
    dtaentradasaida::DATE                             AS dta_movimento,
    nroempresa::INTEGER                               AS empresa_id,
    qtdestqinicial::NUMERIC                           AS qtd_estoque_inicial,
    qtdentrada::NUMERIC                               AS qtd_entrada,
    qtdsaida::NUMERIC                                 AS qtd_saida,
    qtdestqinicial + qtdentrada - qtdsaida            AS qtd_estoque_final,
    qtdcompra::NUMERIC                                AS qtd_compra,
    vlrtotalcompra::NUMERIC                           AS vlr_total_compra,
    qtdvda::NUMERIC                                   AS qtd_venda,
    vlrtotalvda::NUMERIC                              AS vlr_total_venda,
    vlrcusliquidovda::NUMERIC                         AS vlr_custo_liquido_venda,
    vlrcusbrutovda::NUMERIC                           AS vlr_custo_bruto_venda,
    qtddevol::NUMERIC                                 AS qtd_devolucao,
    vlrtotaldevol::NUMERIC                            AS vlr_total_devolucao,
    vlrcusliquidodevol::NUMERIC                       AS vlr_custo_liquido_devolucao,
    cmdiavlrnf::NUMERIC                               AS custo_medio_dia_nf,
    cmdiacusliquidoemp::NUMERIC                       AS custo_medio_dia_liquido,
    _loaded_at::TIMESTAMP                             AS carregado_em
FROM source
