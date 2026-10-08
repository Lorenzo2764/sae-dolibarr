# Procédure de reprise après incident (PRA)

## Sauvegarde (régulière, ex. cron quotidien)
    ./backup.sh
Produit `backups/dolibarr_backup_<date>.tar.gz` (dump SQL, documents, conf.php, .env).
Copier ce fichier **hors du serveur** (autre machine, NAS...). Il contient des mots de passe : le protéger.

## Restauration sur un serveur vierge
1. Installer Docker + git
2. `git clone <url>/sae-dolibarr && cd sae-dolibarr`
3. Copier la sauvegarde dans `backups/`
4. `./restore.sh backups/dolibarr_backup_<date>.tar.gz`
5. Vérifier : `./tests/test_tiers.sh` puis connexion web

## Exemple de cron (tous les jours à 2h)
    0 2 * * * cd /opt/sae-dolibarr && ./backup.sh >> backups/cron.log 2>&1
