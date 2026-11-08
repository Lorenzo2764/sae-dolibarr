#!/usr/bin/env bash
export MSYS_NO_PATHCONV=1
# Restauration de Dolibarr depuis une sauvegarde faite par sauvegarde.sh.
# Usage : ./restauration.sh AAAAMMJJ_HHMM
# Sans argument, le script liste les sauvegardes disponibles.
# ATTENTION : la base et les fichiers actuels sont remplacés par ceux de la sauvegarde.

# Se place dans le dossier du script (là où se trouve docker-compose.yml).
cd "$(dirname "$0")" || exit 1

# Choix de la commande Compose.
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"            # Compose v2 (plugin)
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"            # Compose v1 (binaire séparé)
else
  echo "Erreur : ni 'docker compose' ni 'docker-compose' n'est disponible." >&2
  exit 1
fi

DIR="sauvegardes"
HORO="$1"

if [ -z "$HORO" ]; then
  echo "Usage : ./restauration.sh AAAAMMJJ_HHMM"
  echo "Sauvegardes disponibles :"
  ls "$DIR"/bdd_*.sql 2>/dev/null | sed -e "s#^$DIR/bdd_##" -e 's#\.sql$##' | sed 's/^/  /'
  exit 1
fi

BDD="$DIR/bdd_$HORO.sql"
DOCS="$DIR/documents_$HORO.tar.gz"

# Vérifications avant de toucher à quoi que ce soit.
for f in "$BDD" "$DOCS"; do
  if [ ! -s "$f" ]; then
    echo "Erreur : fichier introuvable ou vide : $f" >&2
    exit 1
  fi
done
if ! gzip -t "$DOCS" 2>/dev/null; then
  echo "Erreur : l'archive $DOCS est corrompue." >&2
  exit 1
fi
if ! tail -n 1 "$BDD" | grep -q 'Dump completed'; then
  echo "Erreur : le dump $BDD est incomplet." >&2
  exit 1
fi
for service in db dolibarr; do
  if ! $DC exec -T "$service" true >/dev/null 2>&1; then
    echo "Erreur : le conteneur '$service' ne tourne pas. Lance d'abord les conteneurs (voir install.sh)." >&2
    exit 1
  fi
done

echo "Cette opération REMPLACE la base et les fichiers actuels par la sauvegarde $HORO."
read -r -p "Tape « oui » pour continuer : " rep || { echo >&2; echo "Entrée interrompue." >&2; exit 1; }
if [ "$rep" != "oui" ]; then
  echo "Restauration annulée."
  exit 1
fi

# On arrête Dolibarr pour qu'il n'écrive pas dans la base pendant la restauration.
echo ">> Arrêt de Dolibarr"
$DC stop dolibarr || { echo "Erreur : arrêt de Dolibarr impossible." >&2; exit 1; }

echo ">> Restauration de la base de données"
# La base est supprimée puis recréée, pour revenir exactement à l'état sauvegardé.
if ! $DC exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot -e "DROP DATABASE IF EXISTS \`$MARIADB_DATABASE\`; CREATE DATABASE \`$MARIADB_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"'; then
  echo "Erreur : la base n'a pas pu être recréée. Dolibarr reste arrêté ($DC start dolibarr pour le relancer)." >&2
  exit 1
fi
if ! $DC exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot "$MARIADB_DATABASE"' < "$BDD"; then
  echo "Erreur : l'import du dump a échoué. La base est dans un état incomplet : relance la restauration." >&2
  exit 1
fi

echo ">> Redémarrage de Dolibarr"
$DC start dolibarr || { echo "Erreur : redémarrage de Dolibarr impossible." >&2; exit 1; }
# Attend que le conteneur accepte de nouveau les commandes.
until $DC exec -T dolibarr true >/dev/null 2>&1; do
  printf '.'; sleep 2
done
echo

echo ">> Restauration des fichiers Dolibarr"
# Le contenu actuel du dossier est vidé, puis remplacé par celui de l'archive.
if ! $DC exec -T dolibarr sh -c 'find /var/www/documents -mindepth 1 -delete && tar xzf - -C /var/www' < "$DOCS"; then
  echo "Erreur : la restauration des fichiers a échoué." >&2
  exit 1
fi

echo
echo "=============================================="
echo " Restauration terminée (sauvegarde $HORO)"
echo "=============================================="
