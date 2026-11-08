#!/usr/bin/env bash
export MSYS_NO_PATHCONV=1
# Restauration de Dolibarr depuis une sauvegarde faite par sauvegarde.sh.
# Usage : ./restauration.sh
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

BDD="$DIR/backup_bdd.sql"
DOCS="$DIR/documents_dolibarr.tar.gz"

# Vérifications avant de toucher à quoi que ce soit.
for f in "$BDD" "$DOCS"; do
  if [ ! -s "$f" ]; then
    echo "Erreur : fichier introuvable ou vide : $f" >&2
    exit 1
  fi
done

#Vérifie que les conteneurs tournent
for service in db dolibarr; do
  if ! $DC exec -T "$service" true >/dev/null 2>&1; then
    echo "Erreur : le conteneur '$service' ne tourne pas. Lance d'abord les conteneurs (voir install.sh)." >&2
    exit 1
  fi
done

echo "Cette opération REMPLACE la base et les fichiers actuels par la sauvegarde backup_bdd."
read -r -p "Tape « Entrée » pour continuer : " rep
if ! [ -z $rep ]; then
  echo "Restauration annulée."
  exit 1
fi

# On arrête Dolibarr pour qu'il n'écrive pas dans la base pendant la restauration.
echo ">> Arrêt de Dolibarr"
$DC stop dolibarr

echo ">> Restauration de la base de données"
# La base est supprimée puis recréée, pour revenir exactement à l'état sauvegardé.
if ! $DC exec -T db sh -c 'MYSQL_PWD="$MARIADB_PASSWORD" exec mariadb -u"$MARIADB_USER" -e "DROP DATABASE IF EXISTS \`$MARIADB_DATABASE\`; CREATE DATABASE \`$MARIADB_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"'; then
  echo "Erreur : la base n'a pas pu être recréée. Dolibarr reste arrêté ($DC start dolibarr pour le relancer)." >&2
  exit 1
fi
if ! $DC exec -T db sh -c 'MYSQL_PWD="$MARIADB_PASSWORD" exec mariadb -u"$MARIADB_USER" "$MARIADB_DATABASE"' < "$BDD"; then
  echo "Erreur : l'import du dump a échoué. La base est dans un état incomplet : relance la restauration." >&2
  exit 1
fi

echo ">> Redémarrage de Dolibarr"
$DC start dolibarr
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
echo " Restauration terminée"
echo "=============================================="
