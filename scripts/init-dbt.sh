#!/bin/bash
# Generates ~/.dbt/profiles.yml from Docker env vars, then executes the given command.

mkdir -p /home/dbt_user/.dbt

cat > /home/dbt_user/.dbt/profiles.yml <<EOF
retail:
  target: prod
  outputs:
    prod:
      type: postgres
      host: ${PG_HOSTNAME}
      port: ${PG_PORT:-5432}
      user: ${DBT_USERNAME}
      password: ${DBT_PASSWORD}
      dbname: ${PG_DATABASE}
      schema: gold
      threads: 4
EOF

exec "$@"
