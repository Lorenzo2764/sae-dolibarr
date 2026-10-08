#!/usr/bin/env bash
# Test rapide : Dolibarr répond + des tiers sont présents en base
set -euo pipefail
cd "$(dirname "$0")/.."
set -a; . ./.env; set +a
code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${DOLIBARR_PORT:-8080}/")
echo "HTTP Dolibarr : $code"
n=$(docker compose exec -T -e MYSQL_PWD="$DB_ROOT_PASSWORD" db mariadb -uroot -N -e "SELECT COUNT(*) FROM \`$DB_NAME\`.llx_societe")
echo "Nombre de tiers : $n"
[ "$n" -gt 0 ] && echo "TEST OK" || { echo "TEST ECHEC"; exit 1; }
