# SAE51DOLI : déploiement de Dolibarr avec Docker

Ce projet déploie l'ERP/CRM **Dolibarr** et sa base de données **MariaDB** dans deux conteneurs Docker, importe des tiers (clients et fournisseurs) depuis des fichiers CSV, et fournit des scripts de sauvegarde et de restauration.

## Sommaire

1. [Prérequis](#prérequis)
2. [Installation](#installation)
3. [Import des tiers depuis les CSV](#import-des-tiers-depuis-les-csv)
4. [Sauvegarde et restauration](#sauvegarde-et-restauration)
5. [Utilisation sous Windows](#utilisation-sous-windows)
6. [Sécurité](#sécurité)
7. [Limite](#limite)

### Architecture

| Service | Image | Rôle | Volume |
|---|---|---|---|
| `db` | `mariadb:latest` | Base de données (UTF-8 `utf8mb4`) | `db_data` |
| `dolibarr` | `dolibarr/dolibarr:latest` | Application web, exposée sur le port choisi à l'installation | `documents` |

Dolibarr s'installe automatiquement au premier démarrage (`DOLI_INSTALL_AUTO=1`) avec :
- la société « SAE51DOLI », pays France, fuseau `Europe/Paris`.
- les modules **Societe**, **Import**, **Export** et **Fournisseur** activés.

## Prérequis

- **Docker** avec Docker Compose : la commande `docker compose` (v2) ou le binaire `docker-compose` (v1). Les scripts détectent automatiquement celui qui est disponible.
- **Bash** : Linux, macOS, WSL2, ou Git Bash sous Windows.
- `curl`, `tar` et `gzip` sur la machine qui exécute les scripts.
- Docker doit être démarré (sous Windows et macOS : Docker Desktop lancé).

**Remarque** : Dans la vraie vie sur une machine vierge, on aurait simplement installé Docker puis utilisé Docker compose. Pour ce cas, le script `install.sh` ne vérifie pas que Docker est installé : il suppose un environnement déjà prêt.

## Installation

L'installation se fait avec `install.sh` (pourvu qu'il soit exécutable) :

```bash
chmod +x install.sh import_csv.sh sauvegarde.sh restauration.sh
./install.sh
```

Le script demande :

| Question | Valeur par défaut |
|---|---|
| Mot de passe root de MariaDB | obligatoire |
| Utilisateur de la base | `dolibarr` |
| Mot de passe de cet utilisateur | obligatoire |
| Nom de la base | `dolibarr` |
| Nom du superadmin Dolibarr | `admin` |
| Mot de passe du superadmin | obligatoire |
| Port web | `8080` |

Les mots de passe ne peuvent pas être vides. Les réponses sont exportées comme variables d'environnement, puis lues par `docker-compose.yml` au démarrage des conteneurs. **Aucun mot de passe n'est écrit dans un fichier.**

Le script lance ensuite `docker compose up -d` et attend la fin de l'installation de Dolibarr. Le premier lancement télécharge les images et peut prendre plusieurs minutes.

Une fois terminé, Dolibarr est accessible à l'adresse `http://localhost:<port>/` (par défaut `http://localhost:8080/`), avec le login du superadmin choisi et son mot de passe.

## Import des tiers depuis les CSV

L'import se fait avec `import_csv.sh` :

```bash
./import_csv.sh
```

Le script importe `data/tiers_clients.csv` (tiers de nature *client*) puis `data/tiers_fournisseurs.csv` (nature *fournisseur*) directement dans la table `llx_societe` de la base.

### Format attendu des fichiers CSV

- Encodage **UTF-8**, séparateur **point-virgule** (`;`), guillemets facultatifs autour des valeurs.
- La **première ligne** (en-tête) est ignorée.
- Sept colonnes, dans cet ordre :

```
raison_sociale;adresse;code_postal;ville;telephone;email;siret
```

### Fonctionnement

1. Le CSV est copié dans le conteneur `db`.
2. Il est chargé dans une table temporaire `tmp_import_tiers` avec `LOAD DATA LOCAL INFILE`.
3. Les tiers sont insérés dans `llx_societe` s'il n'en existe pas déjà un du même nom (la comparaison ignore la casse et les accents). Relancer l'import ne crée donc pas de doublons.
4. Un code est généré en fonction du numéro de ligne pour chaque tiers importé : `CU-IMP-0...0[rowid]` pour un client, `SU-IMP-0...0[rowid]` pour un fournisseur (numéro de ligne sur 12 chiffres).
5. Chaque import est marqué d'un identifiant de lot (colonne `import_key`, par exemple `imp2611081133c`) et affiche des comptages : lignes du CSV, tiers importés, total en base.
6. La table temporaire et le fichier copié sont supprimés.

## Sauvegarde et restauration

### Sauvegarde

```bash
./sauvegarde.sh
```

Les conteneurs doivent tourner. Le script crée dans `sauvegardes/` :

- `backup_bdd.sql` : dump SQL de la base ;
- `documents_dolibarr.tar.gz` : archive du dossier de documents de Dolibarr.

Il vérifie l'intégrité de l'archive et supprime les fichiers en cas d'échec.

> **Chaque sauvegarde écrase la précédente** : les noms de fichiers sont fixes.

### Restauration


```bash
./restauration.sh
```

Les conteneurs doivent tourner. Il faut donc réexécuter `install.sh` en cas de perte des conteneurs/volumes.

Le script :

1. vérifie la présence des deux fichiers de sauvegarde ;
2. demande confirmation : appuyer sur **Entrée** continue, toute autre saisie annule ;
3. arrête Dolibarr, supprime puis recrée la base et y recharge le dump ;
4. redémarre Dolibarr, vide le dossier de documents et y extrait l'archive.

La base et les fichiers actuels sont **remplacés** par ceux de la sauvegarde.

## Utilisation sous Windows

Les scripts fonctionnent avec **Git Bash** ou **WSL2**, avec Docker Desktop démarré.
Les scripts de sauvegarde et de restauration exportent `MSYS_NO_PATHCONV=1`, ce qui empêche Git Bash de transformer les chemins Linux (`/var/www`) en chemins Windows avant de les passer à Docker.


## Sécurité

- Les mots de passe sont saisis à l'installation, exportés en variables d'environnement et **jamais écrits dans le dépôt**. `docker-compose.yml` ne contient que des références à ces variables.
- Les conteneurs conservent ces valeurs dans leur environnement : toute personne qui peut lancer `docker inspect` sur la machine peut les lire. (Point noir)
- Le dossier `sauvegardes/` contient les données des tiers (noms, adresses, e-mails, téléphones) et les hachages des mots de passe des utilisateurs de Dolibarr. Il est exclu de Git par `.gitignore` et ne doit pas être publié.

## Limite

- Les sauvegardes sont stockées sur la même machine que les données et chaque sauvegarde remplace la précédente. Dans la vraie vie, il faudrait copier sur un autre support physique (NAS, Cloud,...).
