#!/usr/bin/env bash
# Installation complète : Dolibarr + MariaDB (2 conteneurs Docker)
# Usage : ./install.sh [mdp_admin] [mdp_base] [port]
#   défauts : admin / dolibarr / 8080
# Exemple : ./install.sh MonMdpAdmin MonMdpBase 8080
set -euo pipefail
cd "$(dirname "$0")"

command -v docker >/dev/null || { echo "ERREUR : Docker n'est pas installé / pas lancé."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERREUR : 'docker compose' indisponible."; exit 1; }

ADMIN_PWD="${1:-admin}"
DB_PWD="${2:-dolibarr}"
PORT="${3:-8080}"

export DOLI_ADMIN_PASSWORD="$ADMIN_PWD"
export DB_PASSWORD="$DB_PWD"
export DB_ROOT_PASSWORD="$DB_PWD"
export DOLIBARR_PORT="$PORT"

echo ">> Démarrage des conteneurs (le 1er lancement télécharge les images)"
docker compose up -d

URL="http://localhost:${PORT}/"
echo ">> Attente de Dolibarr sur $URL (installation auto de la base au 1er démarrage)"
for i in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL" || true)
  if [ "$code" = "200" ] || [ "$code" = "302" ]; then
    echo
    echo "=============================================="
    echo " Dolibarr est prêt : $URL"
    echo " Login            : admin"
    echo " Mot de passe     : $ADMIN_PWD"
    echo " Mot de passe BDD : $DB_PWD  (utilisateur dolibarr, base dolibarr)"
    echo "=============================================="
    exit 0
  fi
  printf '.'; sleep 5
done
echo
echo "ERREUR : Dolibarr ne répond pas. Voir : docker compose logs dolibarr"
exit 1
