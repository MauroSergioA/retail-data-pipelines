-- Conecta o banco "superque" (onde dbt roda) ao banco "nocodb" (onde o NocoDB
-- guarda os dados das bases que a diretoria edita, ex.: Meta Comercial) via
-- postgres_fdw. Sem isso, dbt nao consegue ler tabelas do NocoDB: Postgres
-- nao permite query direta entre bancos diferentes, mesmo no mesmo servidor.
--
-- Rodar cada bloco como uma transacao separada (nao colar tudo num psql -c
-- so) - se IMPORT FOREIGN SCHEMA falhar no meio, um unico -c com ; mata tudo
-- via rollback implicito da transacao simples do protocolo do psql.
--
-- Toda vez que uma BASE NOVA for criada no NocoDB (cada base = um schema
-- Postgres com nome aleatorio dentro do banco "nocodb", ex. "p9o21o8pe6v138w"),
-- repetir o bloco "Por base nova" abaixo trocando o nome do schema.

-- ===== Uma vez, no banco nocodb =====
-- Role de leitura minima, sem acesso a nada alem das tabelas que o FDW precisa.
CREATE ROLE dbt_fdw_reader LOGIN PASSWORD 'TROCAR_SENHA_FORTE';

-- ===== Uma vez, no banco superque =====
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

-- host = IP do container do Postgres na rede docker (nao usar 'localhost':
-- pg_hba.conf tem "host all all 127.0.0.1/32 trust", e postgres_fdw recusa
-- mapeamento de usuario nao-superuser contra um servidor sem autenticacao
-- por senha real - precisa cair na regra "scram-sha-256" do catch-all.
-- Achar o IP atual: docker inspect <container_postgres> --format '{{json .NetworkSettings.Networks}}'
-- ATENCAO: esse IP pode mudar se o container for recriado (nao so reiniciado)
-- - se o FDW comecar a falhar do nada, checar o IP atual e rodar
-- ALTER SERVER nocodb_server OPTIONS (SET host '<ip novo>');
CREATE SERVER nocodb_server FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS (host 'TROCAR_PELO_IP_DO_CONTAINER', port '5432', dbname 'nocodb');

CREATE USER MAPPING FOR dbt_user SERVER nocodb_server
  OPTIONS (user 'dbt_fdw_reader', password 'TROCAR_SENHA_FORTE');

CREATE SCHEMA IF NOT EXISTS nocodb;
GRANT USAGE ON SCHEMA nocodb TO dbt_user;

-- ===== Por base nova do NocoDB =====
-- 1. No banco nocodb: dar SELECT pro dbt_fdw_reader no schema da base nova
--    (achar o nome do schema via GET /api/v2/meta/bases/{baseId} -> sources[0].config)
--    GRANT USAGE ON SCHEMA "<schema_da_base>" TO dbt_fdw_reader;
--    GRANT SELECT ON ALL TABLES IN SCHEMA "<schema_da_base>" TO dbt_fdw_reader;
--    ALTER DEFAULT PRIVILEGES IN SCHEMA "<schema_da_base>" GRANT SELECT ON TABLES TO dbt_fdw_reader;
--
-- 2. No banco superque: importar as tabelas pro schema "nocodb" (postgres
--    precisa de uma user mapping temporaria pra rodar o IMPORT, ja que ele
--    nao tem uma propria por padrao):
--    CREATE USER MAPPING FOR postgres SERVER nocodb_server OPTIONS (user 'dbt_fdw_reader', password 'TROCAR_SENHA_FORTE');
--    IMPORT FOREIGN SCHEMA "<schema_da_base>" FROM SERVER nocodb_server INTO nocodb;
--    GRANT SELECT ON ALL TABLES IN SCHEMA nocodb TO dbt_user;
--    DROP USER MAPPING FOR postgres SERVER nocodb_server;

-- Base "Meta Comercial" (criada em 2026-06-25, schema p9o21o8pe6v138w):
-- ja importada -> nocodb.meta_parametros, nocodb.meta_ajustes_loja

-- ===== Caso especial: dbt ESCREVE numa tabela do NocoDB =====
-- meta_ajustes_loja recebe colunas calculadas escritas por
-- macros/sync_meta_ajustes_calculado.sql (post-hook do mart_meta_comercial)
-- - assim a diretoria ve o rateio calculado na mesma tela onde ajusta. Ver
-- docs/operacao/nocodb.md, secao "dbt escrevendo no NocoDB".
--
-- No banco nocodb:
--   GRANT INSERT, UPDATE ON "p9o21o8pe6v138w".meta_ajustes_loja TO dbt_fdw_reader;
-- No banco superque:
--   GRANT INSERT, UPDATE ON nocodb.meta_ajustes_loja TO dbt_user;
--   ALTER FOREIGN TABLE nocodb.meta_ajustes_loja ADD COLUMN participacao_loja_calculada NUMERIC;
--   ALTER FOREIGN TABLE nocodb.meta_ajustes_loja ADD COLUMN meta_padrao_sem_ajuste NUMERIC;
--   ALTER FOREIGN TABLE nocodb.meta_ajustes_loja ADD COLUMN meta_desafio_sem_ajuste NUMERIC;
-- (colunas Formula do NocoDB, ex. meta_padrao_final, NUNCA sao importadas -
-- sao calculadas pelo proprio NocoDB, nao existem como coluna real no Postgres)
