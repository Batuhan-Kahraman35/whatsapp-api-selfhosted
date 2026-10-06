#!/usr/bin/env bash
# Lists columns/tables/indexes that exist in Evolution API's MySQL Prisma schema
# but are missing from the live database (MySQL migrations can lag behind PostgreSQL).
# Run from the folder containing docker-compose.yml.
set -euo pipefail

docker compose exec -T evolution-api npx prisma migrate diff \
  --from-schema-datasource prisma/mysql-schema.prisma \
  --to-schema-datamodel prisma/mysql-schema.prisma \
  --script | grep -E "ADD COLUMN|CREATE TABLE|CREATE UNIQUE" || echo "OK: schema is in sync."
