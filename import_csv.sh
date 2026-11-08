#!/usr/bin/env bash
# Import des tiers (clients/fournisseurs) depuis un CSV directement dans MariaDB.
# Usage : ./import_csv.sh
#Exécute mariadb dans le conteneur (le mot de passe root est lu dans le conteneur)

# Choix de la commande Compose.
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"            # Compose v2 (plugin)
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"            # Compose v1 (binaire séparé)
else
  echo "Erreur : ni 'docker compose' ni 'docker-compose' n'est disponible." >&2
  exit 1
fi

import_file() {
  local CSV="$1"
  local NATURE="$2"
  IS_CLIENT=0; IS_FOURN=0
  [ "$NATURE" = "client" ] && IS_CLIENT=1
  [ "$NATURE" = "fournisseur" ] && IS_FOURN=1
  # Suffixe c/f pour que deux imports dans la même minute aient des lots distincts
  BATCH="imp$(date +%y%m%d%H%M)${NATURE:0:1}"

  echo ">> Copie de $CSV dans le conteneur"
  tr -d '\r' < "$CSV" | $DC exec -T db sh -c 'cat > /tmp/tiers.csv && chmod 644 /tmp/tiers.csv'

  echo ">> Import de $CSV en tant que $NATURE (lot $BATCH)"
  {
  echo "SET @batch='$BATCH', @is_client=$IS_CLIENT, @is_fourn=$IS_FOURN;"
  cat <<'SQL'
CREATE TABLE tmp_import_tiers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  raison_sociale VARCHAR(128), adresse VARCHAR(255),
  code_postal VARCHAR(25), ville VARCHAR(50), telephone VARCHAR(30),
  email VARCHAR(128), siret VARCHAR(128)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

LOAD DATA LOCAL INFILE '/tmp/tiers.csv' INTO TABLE tmp_import_tiers
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

DROP TABLE tmp_import_tiers;
SQL
  } | $DC exec -T db sh -c 'MYSQL_PWD="$MARIADB_PASSWORD" exec mariadb -u"$MARIADB_USER" --local-infile=1 -t "$MARIADB_DATABASE"'

  $DC exec -T db rm -f /tmp/tiers.csv
}

import_file data/tiers_clients.csv "client"
import_file data/tiers_fournisseurs.csv "fournisseur"

echo ">> Installation et import terminé."