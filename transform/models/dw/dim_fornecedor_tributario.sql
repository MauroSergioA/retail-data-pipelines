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
    r.descricao_situacao_cadastral,
    r.regime_tributario,
    r.data_opcao_pelo_simples,
    r.data_opcao_pelo_mei,
    r.porte,
    r.capital_social,
    r.data_inicio_atividade,
    r.cnae_fiscal,
    r.cnae_fiscal_descricao,
    r.carregado_em
FROM fornecedor                f
INNER JOIN receita              r ON r.cnpj = f.cnpj_cpf
