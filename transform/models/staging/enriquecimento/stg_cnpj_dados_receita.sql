WITH source AS (
    SELECT * FROM {{ source('enriquecimento', 'cnpj_dados_receita') }}
)

SELECT
    cnpj,
    situacao_cadastral,
    descricao_situacao_cadastral,
    opcao_pelo_simples,
    data_opcao_pelo_simples::DATE          AS data_opcao_pelo_simples,
    opcao_pelo_mei,
    data_opcao_pelo_mei::DATE              AS data_opcao_pelo_mei,
    porte,
    descricao_porte,
    capital_social,
    data_inicio_atividade::DATE            AS data_inicio_atividade,
    cnae_fiscal,
    cnae_fiscal_descricao,
    fonte_api,
    _loaded_at::TIMESTAMP                  AS carregado_em
FROM source
