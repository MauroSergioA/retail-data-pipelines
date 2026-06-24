-- =============================================================================
-- Setup: tabela de log de duração por pipeline dentro de cada workflow do Hop
-- Executar como superuser (postgres) conectado ao database superque
-- Uso: psql -U postgres -d superque -f scripts/setup/03_pg_hop_execution_log.sql
--
-- Aditivo apenas: não altera nenhuma grant existente.
-- Escrita: hop_user (via hop-run-server.py, depois de cada execução de workflow).
-- Leitura: dbt_user (via role dbt), usado pelo dbt-server.py pra montar o resumo
-- de tempo que entra na notificação do Telegram do workflow 02/05 do n8n.
-- =============================================================================

CREATE TABLE IF NOT EXISTS bronze.hop_execution_log (
    id                BIGSERIAL PRIMARY KEY,
    execution_id      TIMESTAMP NOT NULL,
    workflow_name     TEXT NOT NULL,
    pipeline_name     TEXT NOT NULL,
    started_at        TIMESTAMP NOT NULL,
    finished_at       TIMESTAMP NOT NULL,
    duration_seconds  NUMERIC NOT NULL,
    logged_at         TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hop_execution_log_execution_id
    ON bronze.hop_execution_log (execution_id);

ALTER TABLE bronze.hop_execution_log OWNER TO hop_user;

-- dbt (silver/gold) só lê — mesmo padrão usado para cnpj_dados_receita
GRANT SELECT ON bronze.hop_execution_log TO dbt;

-- Verificação
SELECT schemaname, tablename, tableowner
FROM pg_tables
WHERE schemaname = 'bronze' AND tablename = 'hop_execution_log';
