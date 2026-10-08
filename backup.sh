#!/usr/bin/env bash
# Sauvegarde complète -> backups/dolibarr_backup_<date>.tar.gz
# Contenu : dump SQL, documents, conf.php, .env   (ATTENTION : contient des secrets)
set -euo pipefail
cd "$(dirname "$0")"
[ -f .env ] || { echo "ERREUR : .env absent"; exit 1; }
set -a; . ./.env; set +a

STAMP=$(date +%Y%m%d_%H%M%S)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p backups

echo ">> Dump de la base"
docker compose exec -T -e MYSQL_PWD="$DB_ROOT_PASSWORD" db \
  mariadb-dump -uroot --single-transaction --routines --add-drop-database --databases "$DB_NAME" \
  | gzip > "$TMP/db.sql.gz"

echo ">> Documents Dolibarr"
docker compose exec -T dolibarr tar czf - -C /var/www documents > "$TMP/documents.tar.gz"

echo ">> conf.php et .env"
docker compose cp dolibarr:/var/www/html/conf/conf.php "$TMP/conf.php"
cp .env "$TMP/env"

OUT="backups/dolibarr_backup_${STAMP}.tar.gz"
tar czf "$OUT" -C "$TMP" db.sql.gz documents.tar.gz conf.php env
chmod 600 "$OUT"
echo ">> Sauvegarde créée : $OUT ($(du -h "$OUT" | cut -f1))"
