#!/usr/bin/env bash
# Installation complète : Dolibarr + MariaDB (2 conteneurs Docker)
set -euo pipefail
cd "$(dirname "$0")"

command -v docker >/dev/null || { echo "ERREUR : Docker n'est pas installé."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "ERREUR : le plugin 'docker compose' est manquant."; exit 1; }

gen() { head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

if [ ! -f .env ]; then
  echo ">> Création de .env avec des mots de passe aléatoires"
  sed -e "s/__DB_PASSWORD__/$(gen)/" \
      -e "s/__DB_ROOT_PASSWORD__/$(gen)/" \
      -e "s/__ADMIN_PASSWORD__/$(gen)/" .env.example > .env
  chmod 600 .env
fi

set -a; . ./.env; set +a

echo ">> Démarrage des conteneurs (le premier lancement télécharge les images)"
docker compose up -d

URL="http://localhost:${DOLIBARR_PORT:-8080}/"
echo ">> Attente de Dolibarr sur $URL (installation auto de la base au 1er démarrage)"
for i in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' "$URL" || true)
  if [ "$code" = "200" ] || [ "$code" = "302" ]; then
    echo
    echo "=============================================="
    echo " Dolibarr est prêt : $URL"
    echo " Login    : $DOLI_ADMIN_LOGIN"
    echo " Password : $DOLI_ADMIN_PASSWORD"
    echo "=============================================="
    exit 0
  fi
  printf '.'; sleep 5
done
echo
echo "ERREUR : Dolibarr ne répond pas après 7 min. Voir : docker compose logs dolibarr"
exit 1
