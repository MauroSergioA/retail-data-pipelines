#!/bin/bash
set -e

# Generate Hop environment config JSON from Docker env vars
source /home/hop/init-hop-vars.sh

# Register project in Hop config (idempotent)
echo "Registering Hop project..."
/opt/hop/hop-conf.sh \
  --project=superque \
  --project-create \
  --project-home='/home/hop/project' \
  --project-config-file='project-config.json' 2>&1 || true

# Register environment in Hop config (idempotent)
echo "Registering Hop environment..."
/opt/hop/hop-conf.sh \
  --environment-create \
  --environment=prod \
  --environment-project=superque \
  --environment-config-files='/tmp/hop-env.json' 2>&1 || true

echo "Starting Hop trigger server..."
exec python3 /opt/hop/hop-run-server.py
