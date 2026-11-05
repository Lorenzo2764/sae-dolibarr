#!/usr/bin/env bash
# Installation complète : Dolibarr + MariaDB (2 conteneurs Docker)
# Usage : ./install.sh 

# Pose une question ; Entrée = valeur par défaut. $3 = "secret" pour masquer la saisie.
infos_utiles() {
  local label="$1" def="$2" mode="${3:-}" val=""
  if [ "$mode" = "secret" ]; then
    read -r -s -p "$label [Entrée = $def] : " val || true
    echo >&2
  else
    read -r -p "$label [Entrée = $def] : " val || true
  fi
  echo "${val:-$def}"
}

  echo "=== Configuration  ==="
  ADMIN_PWD="$(infos_utiles 'Mot de passe admin Dolibarr' "$DEF_ADMIN_PWD" secret)"
  DB_PWD="$(infos_utiles 'Mot de passe de la base de données' "$DEF_DB_PWD" secret)"
  PORT="$(infos_utiles 'Port web' "$DEF_PORT")"
  echo

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
    ./import_csv.sh
    exit 0
  fi
  printf '.'; sleep 5
done

