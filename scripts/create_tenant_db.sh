#!/usr/bin/env bash
set -euo pipefail

# Create a PostgreSQL database for a tenant using psql client in Docker
# Usage: ./scripts/create_tenant_db.sh TENANT
# Requires: DATABASE_ADMIN_URL pointing to the 'postgres' database, e.g.
# export DATABASE_ADMIN_URL="postgresql://postgres:xxx@free-database.cukfpauavjwz.us-east-1.rds.amazonaws.com:5432/postgres"

TENANT=${1:-}
if [[ -z "${TENANT}" ]]; then
  echo "Usage: $0 TENANT"
  exit 1
fi

if [[ -z "${DATABASE_ADMIN_URL:-}" ]]; then
  echo "ERROR: DATABASE_ADMIN_URL not set. Example: export DATABASE_ADMIN_URL='postgresql://postgres:xxx@host:5432/postgres'"
  exit 1
fi

echo "Creating database '${TENANT}' if not exists..."
docker run --rm -i --network host postgres:16-alpine \
  sh -c "psql \"${DATABASE_ADMIN_URL}\" -v ON_ERROR_STOP=1 -c \"CREATE DATABASE \"\"${TENANT}\"\";\" || echo 'Database may already exist'"

echo "Done."


