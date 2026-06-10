-- =============================================================================
-- Setup: usuários e permissões no database superque
-- Executar como superuser (postgres) conectado ao database superque
-- Uso: psql -U postgres -d superque -f scripts/setup/01_pg_dbt_user.sql
-- =============================================================================

-- Usuários (criar apenas se não existirem)
DO $$ BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'hop_user') THEN
        CREATE USER hop_user WITH PASSWORD 'SUBSTITUIR' NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dbt_user') THEN
        CREATE USER dbt_user WITH PASSWORD 'SUBSTITUIR' NOSUPERUSER NOCREATEDB NOCREATEROLE;
    END IF;
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dbt') THEN
        CREATE ROLE dbt NOSUPERUSER NOCREATEDB NOCREATEROLE NOLOGIN;
    END IF;
END $$;

GRANT CONNECT ON DATABASE superque TO hop_user;
GRANT CONNECT ON DATABASE superque TO dbt_user;

-- -------------------------
-- Schema bronze: hop_user escreve, dbt lê
-- -------------------------
GRANT USAGE, CREATE ON SCHEMA bronze TO hop_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA bronze TO hop_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA bronze GRANT ALL ON TABLES TO hop_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA bronze GRANT ALL ON SEQUENCES TO hop_user;

GRANT USAGE ON SCHEMA bronze TO dbt;
GRANT SELECT ON ALL TABLES IN SCHEMA bronze TO dbt;
ALTER DEFAULT PRIVILEGES IN SCHEMA bronze GRANT SELECT ON TABLES TO dbt;

-- -------------------------
-- Schema silver: dbt_user cria e gerencia (staging views)
-- -------------------------
GRANT USAGE, CREATE ON SCHEMA silver TO dbt_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA silver TO dbt_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA silver GRANT ALL ON TABLES TO dbt_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA silver GRANT ALL ON SEQUENCES TO dbt_user;

-- -------------------------
-- Schema gold: dbt_user cria e gerencia (dims, fatos, marts)
-- -------------------------
GRANT USAGE, CREATE ON SCHEMA gold TO dbt_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA gold TO dbt_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA gold GRANT ALL ON TABLES TO dbt_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA gold GRANT ALL ON SEQUENCES TO dbt_user;

-- dbt_user herda leitura do bronze via role dbt
GRANT dbt TO dbt_user;

-- Search paths
ALTER USER hop_user  SET search_path TO bronze, public;
ALTER USER dbt_user  SET search_path TO gold, silver, bronze, public;

-- Verificação
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole
FROM pg_roles
WHERE rolname IN ('hop_user', 'dbt_user', 'dbt');
