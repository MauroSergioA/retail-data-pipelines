#!/bin/bash
# Writes Docker env vars to hop.properties so Hop resolves ${VAR} in connection metadata
mkdir -p /home/hop/.hop
{
  echo "PG_HOSTNAME=${PG_HOSTNAME:-}"
  echo "PG_PORT=${PG_PORT:-}"
  echo "PG_DATABASE=${PG_DATABASE:-}"
  echo "PG_USERNAME=${PG_USERNAME:-}"
  echo "PG_PASSWORD=${PG_PASSWORD:-}"
  echo "PG_URL=${PG_URL:-}"
  echo "CONSINCO_HOSTNAME=${CONSINCO_HOSTNAME:-}"
  echo "CONSINCO_PORT=${CONSINCO_PORT:-}"
  echo "CONSINCO_DATABASE=${CONSINCO_DATABASE:-}"
  echo "CONSINCO_USERNAME=${CONSINCO_USERNAME:-}"
  echo "CONSINCO_PASSWORD=${CONSINCO_PASSWORD:-}"
  echo "CONSINCO_URL=${CONSINCO_URL:-}"
} > /home/hop/.hop/hop.properties
