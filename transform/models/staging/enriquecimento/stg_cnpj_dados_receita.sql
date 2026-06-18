WITH source AS (
    SELECT * FROM {{ source('enriquecimento', 'cnpj_dados_receita') }}
)

SELECT
    cnpj,
    upper(situacao_cadastral)                              AS situacao_cadastral,
    upper(descricao_situacao_cadastral)                    AS descricao_situacao_cadastral,
    opcao_pelo_simples,
    opcao_pelo_mei,
    CASE
        WHEN opcao_pelo_mei IS TRUE THEN 'MEI'
        WHEN opcao_pelo_simples IS TRUE THEN 'SIMPLES NACIONAL'
        WHEN opcao_pelo_simples IS FALSE THEN 'REGIME NORMAL (REAL/PRESUMIDO)'
        ELSE 'NÃO INFORMADO'
    END                                                    AS regime_tributario,
    data_opcao_pelo_simples::DATE                          AS data_opcao_pelo_simples,
    data_opcao_pelo_mei::DATE                              AS data_opcao_pelo_mei,
    upper(porte)                                           AS porte,
    capital_social::NUMERIC(18, 2)                         AS capital_social,
    data_inicio_atividade::DATE                            AS data_inicio_atividade,
    cnae_fiscal,
    upper(cnae_fiscal_descricao)                           AS cnae_fiscal_descricao,
    upper(fonte_api)                                       AS fonte_api,
    _loaded_at::TIMESTAMP                                  AS carregado_em
FROM source
