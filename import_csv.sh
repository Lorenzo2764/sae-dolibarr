#!/usr/bin/env bash
# Import des tiers (clients/fournisseurs) depuis un CSV directement dans MariaDB.
# Usage : ./import_csv.sh [fichier.csv]     (défaut : data/tiers.csv)
set -euo pipefail
cd "$(dirname "$0")"

CSV="${1:-data/tiers.csv}"
[ -f "$CSV" ] || { echo "ERREUR : fichier $CSV introuvable"; exit 1; }

# Exécute mariadb dans le conteneur (le mot de passe root est lu dans le conteneur)
dbexec() { docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot "$@"' sh "$@"; }

echo ">> Attente de la table llx_societe (créée par Dolibarr à l'installation)"
n=""
for i in $(seq 1 60); do
  n=$(dbexec -N -e "SHOW TABLES FROM dolibarr LIKE 'llx_societe'" 2>/dev/null || true)
  [ -n "$n" ] && break
  printf '.'; sleep 5
done
[ -n "$n" ] || { echo; echo "ERREUR : table llx_societe introuvable (./install.sh lancé ?)"; exit 1; }
echo

BATCH="imp$(date +%y%m%d%H%M)"

echo ">> Copie du CSV dans le conteneur"
tr -d '\r' < "$CSV" | docker compose exec -T db sh -c 'cat > /tmp/tiers.csv && chmod 644 /tmp/tiers.csv'

echo ">> Import (lot $BATCH)"
{
echo "SET @batch='$BATCH';"
cat <<'SQL'
DROP TABLE IF EXISTS tmp_import_tiers;
CREATE TABLE tmp_import_tiers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  raison_sociale VARCHAR(128), type VARCHAR(16), adresse VARCHAR(255),
  code_postal VARCHAR(25), ville VARCHAR(50), telephone VARCHAR(30),
  email VARCHAR(128), siret VARCHAR(128)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

LOAD DATA INFILE '/tmp/tiers.csv' INTO TABLE tmp_import_tiers
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (raison_sociale, type, adresse, code_postal, ville, telephone, email, siret);

INSERT INTO llx_societe
  (nom, entity, status, client, fournisseur, address, zip, town, fk_pays, phone, email, siret, datec, import_key)
SELECT t.raison_sociale, 1, 1,
       CASE WHEN t.type IN ('client','both') THEN 1 ELSE 0 END,
       CASE WHEN t.type IN ('fournisseur','both') THEN 1 ELSE 0 END,
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
} | dbexec -t dolibarr

docker compose exec -T db rm -f /tmp/tiers.csv
echo ">> Terminé. Vérifier dans Dolibarr : Tiers > Liste"
