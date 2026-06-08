#!/bin/bash
# Sourced by load-and-execute.sh via HOP_CUSTOM_ENTRYPOINT_EXTENSION_SHELL_FILE_PATH.
# Generates a Hop environment config JSON from Docker env vars and registers it.

ENVFILE=/tmp/hop-env.json

printf '{
  "variables" : [
    { "name" : "PG_HOSTNAME",         "value" : "%s", "description" : "" },
    { "name" : "PG_PORT",             "value" : "%s", "description" : "" },
    { "name" : "PG_DATABASE",         "value" : "%s", "description" : "" },
    { "name" : "PG_USERNAME",         "value" : "%s", "description" : "" },
    { "name" : "PG_PASSWORD",         "value" : "%s", "description" : "" },
    { "name" : "PG_URL",              "value" : "%s", "description" : "" },
    { "name" : "CONSINCO_HOSTNAME",   "value" : "%s", "description" : "" },
    { "name" : "CONSINCO_PORT",       "value" : "%s", "description" : "" },
    { "name" : "CONSINCO_DATABASE",   "value" : "%s", "description" : "" },
    { "name" : "CONSINCO_USERNAME",   "value" : "%s", "description" : "" },
    { "name" : "CONSINCO_PASSWORD",   "value" : "%s", "description" : "" },
    { "name" : "CONSINCO_URL",        "value" : "%s", "description" : "" }
  ]
}' \
  "${PG_HOSTNAME:-}"       \
  "${PG_PORT:-}"           \
  "${PG_DATABASE:-}"       \
  "${PG_USERNAME:-}"       \
  "${PG_PASSWORD:-}"       \
  "${PG_URL:-}"            \
  "${CONSINCO_HOSTNAME:-}" \
  "${CONSINCO_PORT:-}"     \
  "${CONSINCO_DATABASE:-}" \
  "${CONSINCO_USERNAME:-}" \
  "${CONSINCO_PASSWORD:-}" \
  "${CONSINCO_URL:-}"      \
  > "$ENVFILE"

export HOP_ENVIRONMENT_CONFIG_FILE_NAME_PATHS="$ENVFILE"
