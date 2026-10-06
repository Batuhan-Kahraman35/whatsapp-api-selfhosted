#!/usr/bin/env bash
# Backs up WhatsApp sessions (Docker volume) and the database.
# Usage: DB_PASS=... ./scripts/backup.sh /path/to/backups
set -euo pipefail

DEST="${1:-./backups}"
DB_NAME="${DB_NAME:-evolution}"
DB_USER="${DB_USER:-evolution_user}"
STAMP="$(date +%Y%m%d-%H%M%S)"
PROJECT="$(basename "$PWD")"

mkdir -p "$DEST"

docker run --rm \
  -v "${PROJECT}_evolution_instances:/data:ro" \
  -v "$(realpath "$DEST"):/backup" \
  alpine tar czf "/backup/instances-${STAMP}.tar.gz" -C /data .

mysqldump -u "$DB_USER" -p"${DB_PASS:?DB_PASS is required}" --single-transaction "$DB_NAME" \
  | gzip > "${DEST}/db-${STAMP}.sql.gz"

echo "Backup written to ${DEST} (${STAMP})"
