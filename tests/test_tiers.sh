#!/usr/bin/env bash
# Test rapide : Dolibarr répond + des tiers sont présents en base
set -euo pipefail
cd "$(dirname "$0")/.."
PORT=$(docker compose port dolibarr 80 | sed 's/.*://')
code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/")
echo "HTTP Dolibarr : $code"
n=$(docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot -N -e "SELECT COUNT(*) FROM dolibarr.llx_societe"')
echo "Nombre de tiers : $n"
[ "$n" -gt 0 ] && echo "TEST OK" || { echo "TEST ECHEC"; exit 1; }
