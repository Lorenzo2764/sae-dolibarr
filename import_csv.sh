#!/usr/bin/env bash
# Import des tiers (clients/fournisseurs) depuis un CSV directement dans MariaDB.
# La nature du tiers est déduite du nom du fichier :
#   data/tiers_clients.csv      -> client
#   data/tiers_fournisseurs.csv -> fournisseur
# Usage : ./import_csv.sh [fichier.csv ...]
#   Sans argument : importe data/tiers_clients.csv et data/tiers_fournisseurs.csv (ceux qui existent).
set -euo pipefail
cd "$(dirname "$0")"

# Exécute mariadb dans le conteneur (le mot de passe root est lu dans le conteneur)
dbexec() { docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot "$@"' sh "$@"; }

# Déduit la nature (client / fournisseur) du nom de fichier
nature_de() {
  case "$(basename "$1")" in
    *fournisseur*) echo fournisseur ;;
    *client*)      echo client ;;
    *)             echo "" ;;
  esac
}

# Liste des fichiers à importer
FILES=()
if [ $# -gt 0 ]; then
  FILES=("$@")
else
  for f in data/tiers_clients.csv data/tiers_fournisseurs.csv; do
    [ -f "$f" ] && FILES+=("$f")
  done
fi
[ "${#FILES[@]}" -gt 0 ] || { echo "ERREUR : aucun fichier à importer (data/tiers_clients.csv, data/tiers_fournisseurs.csv)"; exit 1; }

# Vérification de tous les fichiers avant de commencer
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "ERREUR : fichier $f introuvable"; exit 1; }
  [ -n "$(nature_de "$f")" ] || { echo "ERREUR : nature inconnue pour $f (le nom doit contenir 'client' ou 'fournisseur')"; exit 1; }
done

echo ">> Attente de la table llx_societe (créée par Dolibarr à l'installation)"
n=""
for i in $(seq 1 60); do
n=$(dbexec -N -e "SHOW TABLES FROM dolibarr LIKE 'llx_societe'" 2>/dev/null || true)
  [ -n "$n" ] && break
  printf '.'; sleep 5
done
[ -n "$n" ] || { echo; echo "ERREUR : table llx_societe introuvable (./install.sh lancé ?)"; exit 1; }
echo

import_file() {
  local CSV="$1"
  local NATURE IS_CLIENT IS_FOURN BATCH
  NATURE="$(nature_de "$CSV")"
  IS_CLIENT=0; IS_FOURN=0
  [ "$NATURE" = "client" ] && IS_CLIENT=1
  [ "$NATURE" = "fournisseur" ] && IS_FOURN=1
  # Suffixe c/f pour que deux imports dans la même minute aient des lots distincts
  BATCH="imp$(date +%y%m%d%H%M)${NATURE:0:1}"

  echo ">> Copie de $CSV dans le conteneur"
  tr -d '\r' < "$CSV" | docker compose exec -T db sh -c 'cat > /tmp/tiers.csv && chmod 644 /tmp/tiers.csv'

  echo ">> Import de $CSV en tant que $NATURE (lot $BATCH)"
  {
  echo "SET @batch='$BATCH', @is_client=$IS_CLIENT, @is_fourn=$IS_FOURN;"
  cat <<'SQL'
DROP TABLE IF EXISTS tmp_import_tiers;
CREATE TABLE tmp_import_tiers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  raison_sociale VARCHAR(128), adresse VARCHAR(255),
  code_postal VARCHAR(25), ville VARCHAR(50), telephone VARCHAR(30),
  email VARCHAR(128), siret VARCHAR(128)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

LOAD DATA INFILE '/tmp/tiers.csv' INTO TABLE tmp_import_tiers
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (raison_sociale, adresse, code_postal, ville, telephone, email, siret);

INSERT INTO llx_societe
  (nom, entity, status, client, fournisseur, address, zip, town, fk_pays, phone, email, siret, datec, import_key)
SELECT t.raison_sociale, 1, 1, @is_client, @is_fourn,
       t.adresse, t.code_postal, t.ville, 1, t.telephone, t.email, t.siret, NOW(), @batch
FROM tmp_import_tiers t
WHERE NOT EXISTS (
  SELECT 1 FROM llx_societe s
  WHERE s.entity = 1 AND s.nom = t.raison_sociale COLLATE utf8mb4_unicode_ci
);

UPDATE llx_societe SET code_client      = CONCAT('CU-IMP-', LPAD(rowid,5,'0')) WHERE import_key=@batch AND client=1;
UPDATE llx_societe SET code_fournisseur = CONCAT('SU-IMP-', LPAD(rowid,5,'0')) WHERE import_key=@batch AND fournisseur=1;

SELECT COUNT(*) AS lignes_dans_csv FROM tmp_import_tiers;
SELECT COUNT(*) AS tiers_importes  FROM llx_societe WHERE import_key=@batch;
SELECT COUNT(*) AS total_tiers     FROM llx_societe;

-- Lignes du CSV NON importées : tiers déjà présent en base avec le même nom
SELECT t.raison_sociale AS ligne_ignoree, s.rowid AS deja_en_base_rowid, s.nom AS nom_en_base, s.import_key
FROM tmp_import_tiers t
JOIN llx_societe s ON s.entity = 1 AND s.nom = t.raison_sociale COLLATE utf8mb4_unicode_ci
WHERE s.import_key IS NULL OR s.import_key <> @batch;

DROP TABLE tmp_import_tiers;
SQL
  } | dbexec -t dolibarr

  docker compose exec -T db rm -f /tmp/tiers.csv
}

for f in "${FILES[@]}"; do
  import_file "$f"
done

echo ">> Terminé. Vérifier dans Dolibarr : Tiers > Clients / Fournisseurs"
