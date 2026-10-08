# sae-dolibarr - POC Dolibarr dockerisé (SAE51)

Dolibarr + MariaDB dans 2 conteneurs ; installation, import CSV et sauvegarde/restauration automatisés.

## Prérequis
Linux avec Docker et le plugin `docker compose`, `curl`.

## Utilisation
    ./install.sh                      # installe tout, affiche l'URL et les identifiants
    ./import_csv.sh                   # importe data/tiers.csv
    ./tests/test_tiers.sh             # vérifie
    ./backup.sh                       # sauvegarde -> backups/
    ./restore.sh backups/xxx.tar.gz   # PRA

## Arborescence
| Élément | Rôle |
|---|---|
| `docker-compose.yml` | définition des 2 conteneurs + volumes |
| `.env.example` | modèle de config (`.env` généré par install.sh, non versionné) |
| `install.sh` / `import_csv.sh` | scripts demandés |
| `backup.sh` / `restore.sh` | sauvegarde et PRA |
| `data/tiers.csv` | données fictives |
| `docs/` | documentation (PRA...) |
| `suivi_projet.md` | journal de bord |

## Format du CSV
`raison_sociale;type;adresse;code_postal;ville;telephone;email;siret`
avec `type` = `client`, `fournisseur` ou `both`. Séparateur `;`, UTF-8.

## Choix techniques
- Images officielles `dolibarr/dolibarr` et `mariadb`, 2 conteneurs séparés
- Import direct en SQL dans `llx_societe` (automatisable, contrairement au menu Outils)
- Volumes nommés Docker pour la persistance
