#!/usr/bin/env bash
# Import des tiers et Backup via les modules natifs de Dolibarr
# Usage : ./import_export.sh [fichier.csv] [ID_profil_import] [ID_profil_export]
set -euo pipefail
cd "$(dirname "$0")"

CSV="${1:-data/tiers.csv}"
IMPORT_ID="${2:-1}"
EXPORT_ID="${3:-1}"

[ -f "$CSV" ] || { echo "ERREUR : fichier $CSV introuvable"; exit 1; }

echo ">> Formatage du CSV pour le module natif..."
# Séparation de la colonne 'type' en deux colonnes booléennes distinctes
awk -F';' 'BEGIN {OFS=";"}
NR==1 {print $1, "client", "fournisseur", $3, $4, $5, $6, $7, $8}
NR>1 {
    c = ($2 == "client" || $2 == "both") ? 1 : 0;
    f = ($2 == "fournisseur" || $2 == "both") ? 1 : 0;
    print $1, c, f, $3, $4, $5, $6, $7, $8
}' "$CSV" > /tmp/tiers_natif.csv

echo ">> Transfert du fichier vers le conteneur Dolibarr..."
docker compose exec -T dolibarr sh -c 'cat > /tmp/tiers_natif.csv' < /tmp/tiers_natif.csv

echo ">> Lancement de l'import via le script natif (Profil ID : $IMPORT_ID)..."
docker compose exec -T dolibarr php /var/www/html/scripts/import/run_import.php "$IMPORT_ID" /tmp/tiers_natif.csv

echo ">> Création de la backup via le module Export natif (Profil ID : $EXPORT_ID)..."
docker compose exec -T dolibarr php /var/www/html/scripts/export/run_export.php "$EXPORT_ID"

echo ">> Nettoyage..."
docker compose exec -T dolibarr rm -f /tmp/tiers_natif.csv
rm -f /tmp/tiers_natif.csv

echo ">> Opération terminée avec succès."
