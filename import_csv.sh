#!/usr/bin/env bash
# Import automatisé des tiers via SQL et génération d'une sauvegarde
# Usage : ./import_csv.sh [fichier.csv] (défaut : tiers.csv)
set -euo pipefail
cd "$(dirname "$0")"

CSV="${1:-tiers.csv}"
[ -f "$CSV" ] || { echo "ERREUR : fichier $CSV introuvable"; exit 1; }

# Fonction pour exécuter MariaDB directement dans le conteneur db
dbexec() { docker compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot "$@"' sh "$@"; }

echo ">> 1. Attente de l'installation de Dolibarr (table llx_societe)..."
n=""
for i in $(seq 1 60); do
  n=$(dbexec -N -e "SHOW TABLES FROM dolibarr LIKE 'llx_societe'" 2>/dev/null || true)
  [ -n "$n" ] && break
  printf '.'; sleep 5
done
[ -n "$n" ] || { echo; echo "ERREUR : table llx_societe introuvable (./install.sh lancé ?)"; exit 1; }
echo

BATCH="imp$(date +%y%m%d%H%M)"

echo ">> 2. Copie du fichier CSV dans le conteneur de base de données..."
tr -d '\r' < "$CSV" | docker compose exec -T db sh -c 'cat > /tmp/tiers.csv && chmod 644 /tmp/tiers.csv'[cite: 2]

echo ">> 3. Exécution de l'import via SQL (lot $BATCH)..."
{
echo "SET @batch='$BATCH';"
cat <<'SQL'
DROP TABLE IF EXISTS tmp_import_tiers;
CREATE TABLE tmp_import_tiers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  raison_sociale VARCHAR(128), type VARCHAR(16), adresse VARCHAR(255),
  code_postal VARCHAR(25), ville VARCHAR(50), telephone VARCHAR(30),
  email VARCHAR(128), siret VARCHAR(128)
) DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;[cite: 2]

LOAD DATA INFILE '/tmp/tiers.csv' INTO TABLE tmp_import_tiers
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ';' OPTIONALLY ENCLOSED BY '"'
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (raison_sociale, type, adresse, code_postal, ville, telephone, email, siret);[cite: 2]

-- Insertion dans la table native de Dolibarr
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
);[cite: 2]

-- Mise à jour automatique des codes clients et fournisseurs
UPDATE llx_societe SET code_client      = CONCAT('CU-', LPAD(rowid,5,'0')) WHERE import_key=@batch AND client=1;
UPDATE llx_societe SET code_fournisseur = CONCAT('SU-', LPAD(rowid,5,'0')) WHERE import_key=@batch AND fournisseur=1;

DROP TABLE tmp_import_tiers;
SQL
} | dbexec -t dolibarr[cite: 2]

echo ">> 4. Nettoyage du fichier d'import..."
docker compose exec -T db rm -f /tmp/tiers.csv[cite: 2]

echo "=============================================="
echo " Importation SQL terminée avec succès !"
echo "=============================================="
