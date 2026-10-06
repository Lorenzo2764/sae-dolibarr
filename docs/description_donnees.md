# Données CSV fictives – SAE51 (Dolibarr, module « Tiers »)

Toutes les données sont **fictives** (entreprises inventées, téléphones dans la plage réservée
aux fiction `02 61 91 xx xx`, domaines `*.example.com`). SIREN/SIRET valides (algorithme de Luhn),
n° de TVA intracommunautaire calculé selon la règle française.

## Fichiers

| Fichier | Contenu | Lignes |
|---|---|---|
| `tiers_clients.csv` | 30 clients (dont 3 prospects et 2 clients également fournisseurs) | 30 |
| `tiers_fournisseurs.csv` | 15 fournisseurs | 15 |
| `tiers_complet.csv` | concaténation des deux | 45 |
| `generer_donnees.py` | script de génération (graine fixe → reproductible) | – |

Format : UTF-8, séparateur `,`, guillemets `"` si besoin, 1re ligne = en-têtes.

## Description des colonnes

| Colonne | Champ Dolibarr (table `llx_societe`) | Description / valeurs |
|---|---|---|
| `code_client` | `code_client` | Code client `CUxxxx` (vide si non client) |
| `code_fournisseur` | `code_fournisseur` | Code fournisseur `SUxxxx` (vide si non fournisseur) |
| `nom` | `nom` | Raison sociale (obligatoire) |
| `alias` | `name_alias` | Nom commercial court |
| `type_tiers` | – (informatif) | Client / Prospect / Fournisseur / Client + Fournisseur |
| `client` | `client` | 0 = non, 1 = client, 2 = prospect, 3 = client + prospect |
| `fournisseur` | `fournisseur` | 0 = non, 1 = oui |
| `forme_juridique` | `fk_forme_juridique` | SARL, SAS, SASU, EURL, SA, SELARL, Association (texte à mapper sur le code Dolibarr à l'import) |
| `adresse` | `address` | N° + voie |
| `code_postal` | `zip` | 5 chiffres (Normandie) |
| `ville` | `town` | Commune |
| `pays` | `fk_pays` | Code ISO `FR` |
| `telephone` | `phone` | Format `02 61 91 xx xx` |
| `email` | `email` | `contact@<société>.example.com` |
| `site_web` | `url` | `https://www.<société>.example.com` |
| `siren` | `siren` | 9 chiffres |
| `siret` | `siret` | 14 chiffres (SIREN + NIC) |
| `tva_intra` | `tva_intra` | `FR` + clé + SIREN |
| `capital` | `capital` | Capital social en € (vide pour une association) |
| `statut` | `status` | 1 = actif |
| `note` | `note_private` | Mention « Donnée fictive » |

## Utilisation avec Dolibarr

Menu **Outils → Import de données → Tiers (sociétés)** : choisir le séparateur `,` et l'encodage
UTF-8, puis faire correspondre les colonnes du fichier aux champs Dolibarr (colonne
`type_tiers` à ignorer). Pour un import direct en base (`import_csv.sh`), la table cible est
`llx_societe`.
