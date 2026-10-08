#!/usr/bin/env bash
# Sauvegarde complète -> backups/dolibarr_backup_<date>.tar.gz (dump SQL + documents)
set -euo pipefail
cd "$(dirname "$0")"

STAMP=$(date +%Y%m%d_%H%M%S)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p backups

echo ">> Dump de la base"
docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb-dump -uroot --single-transaction --routines --add-drop-database --databases dolibarr' \
  | gzip > "$TMP/db.sql.gz"

echo ">> Documents Dolibarr"
docker compose exec -T dolibarr tar czf - -C /var/www documents > "$TMP/documents.tar.gz"

OUT="backups/dolibarr_backup_${STAMP}.tar.gz"
tar czf "$OUT" -C "$TMP" db.sql.gz documents.tar.gz
echo ">> Sauvegarde créée : $OUT ($(du -h "$OUT" | cut -f1))"
