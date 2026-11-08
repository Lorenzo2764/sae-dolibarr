#!/usr/bin/env bash
#Permet de ne pas faire confondre les chemins Windows et des conteneurs. Ca évite de crash s'il est exécuté sur git bash sous windows.
export MSYS_NO_PATHCONV=1
# Sauvegarde de Dolibarr : base MariaDB (dump SQL) + fichiers (volume documents du conteneur dolibarr).
# Usage : ./sauvegarde.sh
# Les conteneurs doivent tourner. Les fichiers sont créés dans ./sauvegardes/

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

BDD="sauvegardes/backup_bdd.sql"
DOCS="sauvegardes/documents_dolibarr.tar.gz"
#Recréé le dossier sauvegardes.
mkdir -p sauvegardes || exit 1

# Les deux conteneurs doivent répondre.
for service in db dolibarr; do
  if ! $DC exec -T "$service" true >/dev/null 2>&1; then
    echo "Erreur : le conteneur '$service' ne tourne pas." >&2
    exit 1
  fi
done

echo ">> Sauvegarde de la base de données"
# --single-transaction : copie cohérente sans verrouiller les tables.
if ! $DC exec -T db sh -c 'MYSQL_PWD="$MARIADB_PASSWORD" exec mariadb-dump -u"$MARIADB_USER" --single-transaction --routines --triggers "$MARIADB_DATABASE"' > "$BDD"; then
  echo "Erreur : le dump de la base a échoué." >&2
  rm -f "$BDD"
  exit 1
fi

echo ">> Sauvegarde des fichiers Dolibarr"
if ! $DC exec -T dolibarr tar czf - -C /var/www documents > "$DOCS"; then
  echo "Erreur : l'archive des fichiers n'a pas pu être créée." >&2
  rm -f "$DOCS"
  exit 1
fi

#Vérification de l'archive
if ! gzip -t "$DOCS" 2>/dev/null; then
  echo "Erreur : l'archive des fichiers est corrompue." >&2
  rm -f "$DOCS" "$BDD"
  exit 1
fi

echo
echo "=============================================="
echo " Sauvegarde terminée "
echo " Base    : $BDD"
echo " Fichiers: $DOCS"
echo " Pour restaurer : ./restauration.sh "
echo "=============================================="
