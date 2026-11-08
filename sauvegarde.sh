#!/usr/bin/env bash
export MSYS_NO_PATHCONV=1
# Sauvegarde de Dolibarr : base MariaDB (dump SQL) + fichiers (volume documents).
# Usage : ./sauvegarde.sh
# Les conteneurs doivent tourner. Les fichiers sont créés dans ./sauvegardes/
# avec le même horodatage : bdd_AAAAMMJJ_HHMM.sql et documents_AAAAMMJJ_HHMM.tar.gz

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
HORO="$(date +%Y%m%d_%H%M)"
BDD="$DIR/bdd_$HORO.sql"
DOCS="$DIR/documents_$HORO.tar.gz"
mkdir -p "$DIR" || exit 1

# Les deux conteneurs doivent répondre.
for service in db dolibarr; do
  if ! $DC exec -T "$service" true >/dev/null 2>&1; then
    echo "Erreur : le conteneur '$service' ne tourne pas." >&2
    exit 1
  fi
done

echo ">> Sauvegarde de la base de données"
# --single-transaction : copie cohérente sans verrouiller les tables.
if ! $DC exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb-dump -uroot --single-transaction --routines --triggers "$MARIADB_DATABASE"' > "$BDD"; then
  echo "Erreur : le dump de la base a échoué." >&2
  rm -f "$BDD"
  exit 1
fi
# Un dump complet se termine par une ligne « Dump completed ».
if ! tail -n 1 "$BDD" | grep -q 'Dump completed'; then
  echo "Erreur : le dump de la base est incomplet." >&2
  rm -f "$BDD"
  exit 1
fi

echo ">> Sauvegarde des fichiers Dolibarr"
if ! $DC exec -T dolibarr tar czf - -C /var/www documents > "$DOCS"; then
  echo "Erreur : l'archive des fichiers n'a pas pu être créée." >&2
  rm -f "$DOCS" "$BDD"
  exit 1
fi
if ! gzip -t "$DOCS" 2>/dev/null; then
  echo "Erreur : l'archive des fichiers est corrompue." >&2
  rm -f "$DOCS" "$BDD"
  exit 1
fi

echo
echo "=============================================="
echo " Sauvegarde terminée ($HORO)"
echo " Base    : $BDD"
echo " Fichiers: $DOCS"
echo " Pour restaurer : ./restauration.sh $HORO"
echo "=============================================="
