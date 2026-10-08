#!/usr/bin/env bash
# Restauration (PRA) : ./restore.sh <sauvegarde.tar.gz> [mdp_admin] [mdp_base] [port]
# Les mots de passe sont ceux donnés à install.sh (défauts : admin / dolibarr / 8080)
set -euo pipefail
cd "$(dirname "$0")"
BUNDLE="${1:?Usage : ./restore.sh <sauvegarde.tar.gz> [mdp_admin] [mdp_base] [port]}"
[ -f "$BUNDLE" ] || { echo "ERREUR : $BUNDLE introuvable"; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
tar xzf "$BUNDLE" -C "$TMP"

# 1. Réinstallation propre via le script d'install
./install.sh "${2:-admin}" "${3:-dolibarr}" "${4:-8080}"

# 2. Base de données (le dump supprime et recrée la base)
echo ">> Restauration de la base"
gunzip -c "$TMP/db.sql.gz" | docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot'

# 3. Documents
echo ">> Restauration des documents"
docker compose exec -T dolibarr tar xzf - -C /var/www < "$TMP/documents.tar.gz"

docker compose restart dolibarr
echo ">> Restauration terminée."
