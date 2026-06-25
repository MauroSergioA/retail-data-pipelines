-- =============================================================================
-- Setup: tabela de indicadores de mercado externo (IPCA via BCB, PMC via IBGE)
-- Executar como superuser (postgres) conectado ao database superque
-- Uso: psql -U postgres -d superque -f scripts/setup/04_pg_mercado_externo.sql
--
-- Aditivo apenas: nao altera nenhuma grant existente. Reusa o enrichment_user
-- ja criado em 02_pg_enrichment_user.sql (mesmo padrao de "um dono por origem
-- externa de dado" — ja tem USAGE+CREATE em bronze, so falta criar a tabela).
-- =============================================================================

CREATE TABLE IF NOT EXISTS bronze.indicadores_mercado_externo (
    data_referencia  DATE NOT NULL,
    indicador        TEXT NOT NULL,
    valor            NUMERIC NOT NULL,
    fonte            TEXT NOT NULL,
    _loaded_at       TIMESTAMP NOT NULL DEFAULT now(),
    PRIMARY KEY (data_referencia, indicador)
);

ALTER TABLE bronze.indicadores_mercado_externo OWNER TO enrichment_user;

-- dbt (silver/gold) so le — mesmo padrao usado para cnpj_dados_receita
GRANT SELECT ON bronze.indicadores_mercado_externo TO dbt;

-- Verificacao
SELECT schemaname, tablename, tableowner
FROM pg_tables
WHERE schemaname = 'bronze' AND tablename = 'indicadores_mercado_externo';
