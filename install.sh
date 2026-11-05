#!/usr/bin/env bash
# Installation complète : Dolibarr + MariaDB (2 conteneurs Docker)
# Usage : ./install.sh [mdp_admin] [mdp_base] [port]
#   Sans argument : le script pose les questions ; Entrée = valeur par défaut
#   défauts : admin / dolibarr / 8080
# Exemple sans questions : ./install.sh MonMdpAdmin MonMdpBase 8080
set -euo pipefail
cd "$(dirname "$0")"

command -v docker >/dev/null || { echo "ERREUR : Docker n'est pas installé / pas lancé."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERREUR : 'docker compose' indisponible."; exit 1; }

DEF_ADMIN_PWD="admin"
DEF_DB_PWD="dolibarr"
DEF_PORT="8080"

# Pose une question ; Entrée = valeur par défaut. $3 = "secret" pour masquer la saisie.
ask() {
  local label="$1" def="$2" mode="${3:-}" val=""
  if [ "$mode" = "secret" ]; then
    read -r -s -p "$label [Entrée = $def] : " val || true
    echo >&2
  else
    read -r -p "$label [Entrée = $def] : " val || true
  fi
  echo "${val:-$def}"
}

if [ $# -gt 0 ] || [ ! -t 0 ]; then
  # Arguments fournis (ou pas de terminal interactif) : pas de questions
  ADMIN_PWD="${1:-$DEF_ADMIN_PWD}"
  DB_PWD="${2:-$DEF_DB_PWD}"
  PORT="${3:-$DEF_PORT}"
else
  echo "=== Configuration (appuyer sur Entrée pour garder la valeur par défaut) ==="
  ADMIN_PWD="$(ask 'Mot de passe admin Dolibarr' "$DEF_ADMIN_PWD" secret)"
  DB_PWD="$(ask 'Mot de passe de la base de données' "$DEF_DB_PWD" secret)"
  PORT="$(ask 'Port web' "$DEF_PORT")"
  echo
fi

# Vérification du port
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo "ERREUR : port invalide ($PORT)"; exit 1
fi

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
