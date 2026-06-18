-- =============================================================================
-- Setup: usuário e tabela para o enriquecimento de fornecedores via API de CNPJ
-- Executar como superuser (postgres) conectado ao database superque
-- Uso: psql -U postgres -d superque -f scripts/setup/02_pg_enrichment_user.sql
--
-- Aditivo apenas: não altera hop_user, dbt_user nem nenhuma grant existente.
-- Cria um usuário dedicado para que o schema bronze continue tendo um único
-- "dono" de escrita por origem de dado (Hop = hop_user, este script = enrichment_user).
-- =============================================================================

DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'enrichment_user') THEN
        CREATE USER enrichment_user WITH PASSWORD 'taPjZLBKUY1j7r2wbCt8H0+7LNnsGzfc' NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
END $$;

GRANT CONNECT ON DATABASE superque TO enrichment_user;

-- -------------------------
-- Schema bronze: enrichment_user só pode criar/gerenciar a própria tabela
-- (não recebe ALL PRIVILEGES no schema todo, então nunca toca nas tabelas do Hop)
-- -------------------------
GRANT USAGE, CREATE ON SCHEMA bronze TO enrichment_user;

CREATE TABLE IF NOT EXISTS bronze.cnpj_dados_receita (
    cnpj                          VARCHAR(14) PRIMARY KEY,
    situacao_cadastral            VARCHAR(50),
    descricao_situacao_cadastral  VARCHAR(50),
    opcao_pelo_simples            BOOLEAN,
    data_opcao_pelo_simples       DATE,
    opcao_pelo_mei                BOOLEAN,
    data_opcao_pelo_mei           DATE,
    porte                         VARCHAR(50),
    descricao_porte               VARCHAR(50),
    capital_social                NUMERIC(18, 2),
    data_inicio_atividade         DATE,
    cnae_fiscal                   VARCHAR(10),
    cnae_fiscal_descricao         VARCHAR(200),
    fonte_api                     VARCHAR(20),
    _loaded_at                    TIMESTAMP NOT NULL DEFAULT now()
);

ALTER TABLE bronze.cnpj_dados_receita OWNER TO enrichment_user;

-- dbt (silver/gold) só lê — mesmo padrão usado para as tabelas do Hop
GRANT SELECT ON bronze.cnpj_dados_receita TO dbt;

-- -------------------------
-- Schema gold: enrichment_user só lê a dimensão de fornecedores (para obter os CNPJs)
-- -------------------------
GRANT USAGE ON SCHEMA gold TO enrichment_user;
GRANT SELECT ON gold.dim_fornecedor_info TO enrichment_user;

-- Verificação
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole
FROM pg_roles
WHERE rolname = 'enrichment_user';
