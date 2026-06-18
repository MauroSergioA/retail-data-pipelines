WITH receita AS (
    SELECT * FROM {{ ref('stg_cnpj_dados_receita') }}
),

fornecedor AS (
    SELECT fornecedor_id, cnpj_cpf
    FROM {{ ref('dim_fornecedor_info') }}
    WHERE pessoa_tipo = 'JURÍDICA'
)

SELECT
    f.fornecedor_id,
    r.cnpj,
    r.situacao_cadastral,
    r.descricao_situacao_cadastral,
    CASE
        WHEN r.opcao_pelo_mei IS TRUE THEN 'MEI'
        WHEN r.opcao_pelo_simples IS TRUE THEN 'SIMPLES NACIONAL'
        WHEN r.opcao_pelo_simples IS FALSE THEN 'REGIME NORMAL (REAL/PRESUMIDO)'
        ELSE 'NÃO INFORMADO'
    END                                         AS regime_tributario,
    r.opcao_pelo_simples,
    r.data_opcao_pelo_simples,
    r.opcao_pelo_mei,
    r.data_opcao_pelo_mei,
    r.porte,
    r.descricao_porte,
    r.capital_social,
    r.data_inicio_atividade,
    r.cnae_fiscal,
    r.cnae_fiscal_descricao,
    r.fonte_api,
    r.carregado_em
FROM fornecedor                f
INNER JOIN receita              r ON r.cnpj = f.cnpj_cpf
