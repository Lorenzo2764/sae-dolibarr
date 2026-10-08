#!/usr/bin/env bash
# Restauration (PRA) depuis une sauvegarde : ./restore.sh backups/dolibarr_backup_XXXX.tar.gz
set -euo pipefail
cd "$(dirname "$0")"
BUNDLE="${1:?Usage : ./restore.sh <sauvegarde.tar.gz>}"
[ -f "$BUNDLE" ] || { echo "ERREUR : $BUNDLE introuvable"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
tar xzf "$BUNDLE" -C "$TMP"

# 1. .env : on reprend celui de la sauvegarde (mots de passe cohérents avec conf.php)
if [ -f .env ] && ! cmp -s .env "$TMP/env"; then
  echo "Le .env actuel diffère de celui de la sauvegarde."
  echo "Les conteneurs ET volumes existants seront SUPPRIMÉS (docker compose down -v)."
  read -r -p "Taper OUI pour continuer : " rep
  [ "$rep" = "OUI" ] || { echo "Abandon."; exit 1; }
  docker compose down -v
  cp .env .env.before-restore
fi
cp "$TMP/env" .env && chmod 600 .env
set -a; . ./.env; set +a

# 2. Réinstallation propre via le script d'install
./install.sh

# 3. Base de données
echo ">> Restauration de la base"
gunzip -c "$TMP/db.sql.gz" | docker compose exec -T -e MYSQL_PWD="$DB_ROOT_PASSWORD" db mariadb -uroot

# 4. Documents + conf.php
echo ">> Restauration des documents et de conf.php"
docker compose exec -T dolibarr tar xzf - -C /var/www < "$TMP/documents.tar.gz"
docker compose cp "$TMP/conf.php" dolibarr:/var/www/html/conf/conf.php
docker compose exec -T dolibarr sh -c 'chown www-data:www-data /var/www/html/conf/conf.php && chmod 440 /var/www/html/conf/conf.php'

docker compose restart dolibarr
echo ">> Restauration terminée."
