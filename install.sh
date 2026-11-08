#!/usr/bin/env bash
# Installation complète : Dolibarr + MariaDB (2 conteneurs Docker)
# Usage : ./install.sh
# POINT D'ATTENTION : En situation réelle sur une machine vierge, on aurait directement installé Docker puis utilisé Docker compose.
#					  Ici, on le rend fonctionnel avec Docker compose et le binaire Docker-compose mais on ne vérifie pas l'installation de Docker.

# Demande un mot de passe obligatoire : refuse les mdp vides.
mot_de_passe() {
  local label="$1"
  while true; do
    read -r -s -p "$label (Le mot de passe ne peut pas être vide) : " val
	#Saut de ligne
    echo >&2
	#Vérifie que le mdp ne soit pas vide
    if [ -z "$val" ]; then
      echo "Le mot de passe ne peut pas être vide." >&2
    else
      echo "$val"
      return 0
    fi
  done
}

#Vérifie si docker compose existe pour l'utiliser comme commande de démarrage des conteneurs.
#S'il n'existe pas, on vérifie docker-compose et on l'utilise s'il existe, le script s'arrête si aucun des deux existent (ce qui devrait ne pas arriver).
if docker compose version >/dev/null 2>/dev/null; then
  DC="docker compose"            # Compose v2 (plugin)
elif command -v docker-compose >/dev/null 2>/dev/null; then
  DC="docker-compose"            # Compose v1 (binaire séparé)
else
  echo "Erreur : ni 'docker compose' ni 'docker-compose' n'est disponible."
  exit 1
fi

echo "=== Configuration ==="
DB_ROOT_PWD="$(mot_de_passe "Mot de passe de l'utilisateur root de MariaDB")"
read -p "Utilisateur de la BDD [dolibarr] : " DB_USER
DB_USER="${DB_USER:-dolibarr}"
DB_PWD="$(mot_de_passe 'Mot de passe')"
read -p "Nom de la BDD [dolibarr] : " DB_NAME
DB_NAME="${DB_NAME:-dolibarr}"
read -p "Nom du superadmin de Dolibarr [admin] : " ADMIN_NAME
ADMIN_NAME="${ADMIN_NAME:-admin}"
ADMIN_PWD="$(mot_de_passe 'Mot de passe admin Dolibarr')"
read -p "Port [8080] : " PORT
PORT="${PORT:-8080}"

#Envoie les variables dans les processus enfants (démarrage des conteneurs).
export DB_ROOT_PASSWORD="$DB_ROOT_PWD"
export DB_USER="$DB_USER"
export DB_PASSWORD="$DB_PWD"
export DB_NAME="$DB_NAME"
export DOLI_ADMIN_NAME="$ADMIN_NAME"
export DOLI_ADMIN_PASSWORD="$ADMIN_PWD"
export DOLIBARR_PORT=$PORT

echo
echo ">> Démarrage des conteneurs (le 1er lancement télécharge les images)"
if ! $DC up -d; then
  echo "Erreur : '$DC up -d' a échoué."
  exit 1
fi

URL="http://localhost:${PORT}/"

#Vérifie que la redirection vers ADRESSE:8080/install ne se fait plus (ce qui veut dire que Dolibarr a fini l'installation).
dolibarr_pret() {
  local url_finale
  #Envoi d'une requete HTTP pour récupérer l'URL final en suivant les redirections, renvoi automatiquement 1 en cas d'erreur de la commande (conteneur injoignable).
  url_finale=$(curl -s -L -o /dev/null -w '%{http_code} %{url_effective}' "$URL" 2>/dev/null) || return 1
  #Si l'URL contient le mot "install", ça veut dire que la requête a été redirigée sur la page d'installation et que dolibarr n'est pas prêt, on renvoi donc 1 pour false.
  case "install" in "$url_finale") return 1 ;; esac
}

#Attends que la BDD soit prête pour commencer l'import.
echo ">> Attente de l'installation complète de Dolibarr sur $URL (installation auto de la base au 1er démarrage)"
until dolibarr_pret; do
  printf '.'; sleep 5
done

#Vu le temps qu'un import devrait prendre, Dolibarr devrait avoir le temps de s'installer.
#Pour les tests avec un petit import, Dolibarr sera presque prêt une fois l'import finalisé.
echo
echo "=============================================="
echo " Dolibarr est prêt : $URL"
echo " Login Dolibarr    : $ADMIN_NAME"
echo " Login DB          : $DB_USER"
echo " Nom de la BDD     : $DB_NAME"
echo "=============================================="