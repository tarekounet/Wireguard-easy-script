#!/bin/bash

##############################
# 1. CRÉATION DES DOSSIERS ET DROITS
##############################
for dir in lib config logs; do
    if [[ ! -d "$dir" ]]; then
        mkdir "$dir"
        echo "Dossier $dir créé."
    fi
    # Si root, on attribue les droits à l'utilisateur réel
    if [[ $EUID -eq 0 ]]; then
        chown -R "$SUDO_USER":"$SUDO_USER" "$dir" 2>/dev/null || chown -R "$USER":"$USER" "$dir"
    fi
    chmod -R u+rwX "$dir"
    if [[ ! -w "$dir" || ! -r "$dir" || ! -x "$dir" ]]; then
        echo "Erreur : le dossier '$dir/' n'est pas accessible en lecture/écriture/exécution."
        exit 1
    fi
done

##############################
# 2. TÉLÉCHARGEMENT DES MODULES
##############################
GITHUB_USER="tarekounet"
GITHUB_REPO="Wireguard-easy-script"
BRANCH="main" # Valeur par défaut pour bootstrap

for mod in utils conf docker menu ; do
    if [[ ! -f "lib/$mod.sh" ]]; then
        echo "Téléchargement de lib/$mod.sh depuis GitHub ($BRANCH)..."
        curl -fsSL -o "lib/$mod.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/lib/$mod.sh"
        chmod +x "lib/$mod.sh"
    fi
    if [[ $EUID -eq 0 ]]; then
        chown "$SUDO_USER":"$SUDO_USER" "lib/$mod.sh" 2>/dev/null || chown "$USER":"$USER" "lib/$mod.sh"
    fi
    chmod u+rwX "lib/$mod.sh"
done

if [[ ! -f "auto_update.sh" ]]; then
    echo "Téléchargement de auto_update.sh depuis GitHub ($BRANCH)..."
    curl -fsSL -o "auto_update.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/auto_update.sh"
    chmod +x "auto_update.sh"
    if [[ $EUID -eq 0 ]]; then
        chown "$SUDO_USER":"$SUDO_USER" "auto_update.sh" 2>/dev/null || chown "$USER":"$USER" "auto_update.sh"
    fi
    chmod u+rwX "auto_update.sh"
fi

##############################
# 3. CHARGEMENT DES MODULES
##############################
source lib/conf.sh
source lib/utils.sh
source lib/menu.sh

##############################
# 4. VARIABLES GÉNÉRALES
##############################
CONF_FILE="config/wg-easy.conf"
VERSION_FILE="version.txt"
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/wg-easy-script.log"
CONFIG_LOG="$LOG_DIR/config-actions.log"
DOCKER_COMPOSE_DIR="/mnt/wireguard"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"
SCRIPT_BASE_VERSION_INIT="1.7.2"

##############################
# 5. LECTURE DU CANAL/BRANCHE
##############################
if [[ -f "$CONF_FILE" ]]; then
    SCRIPT_CHANNEL=$(grep '^SCRIPT_CHANNEL=' "$CONF_FILE" 2>/dev/null | cut -d'"' -f2)
    [[ -z "$SCRIPT_CHANNEL" ]] && SCRIPT_CHANNEL="stable"
else
    SCRIPT_CHANNEL="stable"
fi

if [[ "$SCRIPT_CHANNEL" == "beta" ]]; then
    BRANCH="beta"
else
    BRANCH="main"
fi

export GITHUB_USER
export GITHUB_REPO
export BRANCH

if [[ -f "$VERSION_FILE" ]]; then
    SCRIPT_BASE_VERSION_INIT=$(cat "$VERSION_FILE")
fi

##############################
# 6. INITIALISATION DE LA CONF
##############################
WG_EASY_VERSION_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/WG_EASY_VERSION"
WG_EASY_VERSION=$(curl -fsSL "$WG_EASY_VERSION_URL" | head -n1)
[[ -z "$WG_EASY_VERSION" ]] && WG_EASY_VERSION="inconnu"

if [[ ! -f "$CONF_FILE" ]]; then
    msg_warn "Le fichier de configuration n'existe pas. Création en cours..."

    PASS1=""
    PASS2=""
    HASH=""
    SALT=$(openssl rand -hex 8)
    while true; do
        read -sp "Entrez le nouveau mot de passe technique : " PASS1
        echo
        read -sp "Confirmez le nouveau mot de passe technique : " PASS2
        echo
        if [[ -z "$PASS1" ]]; then
            echo "Le mot de passe ne peut pas être vide."
        elif [[ "$PASS1" != "$PASS2" ]]; then
            echo "Les mots de passe ne correspondent pas."
        else
            HASH=$(openssl passwd -6 -salt "$SALT" "$PASS1")
            break
        fi
    done

    # Crée le fichier de conf AVEC les bonnes valeurs
    cat > "$CONF_FILE" <<EOF
SCRIPT_CHANNEL="$SCRIPT_CHANNEL"
SCRIPT_BASE_VERSION="$SCRIPT_BASE_VERSION_INIT"
EXPECTED_HASH="$HASH"
BETA_CONFIRMED="0"
RAZ="1"
WG_EASY_VERSION="$WG_EASY_VERSION"
TECH_SALT="$SALT"
EOF
    msg_success "Fichier de configuration créé avec succès."
fi

set_conf_value "WG_EASY_VERSION" "$WG_EASY_VERSION"

##############################
# 7. VÉRIFICATION DU MOT DE PASSE
##############################
EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
while [[ -z "$EXPECTED_HASH" ]]; do
    msg_warn "Aucun mot de passe technique enregistré. Veuillez en définir un."
    set_tech_password
    EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
done

##############################
# 8. LOGS DE LANCEMENT
##############################
echo "$(date '+%F %T') [INFO] Script principal lancé" >> "$LOG_FILE"
echo "$(date '+%F %T') [CONF] Fichier de configuration créé" >> "$CONFIG_LOG"
echo "$(date '+%F %T') [UPDATE] Version Wireguard Easy : $WG_EASY_VERSION" >> "$LOG_FILE"

##############################
# 9. LANCEMENT DU SCRIPT
##############################
check_updates
main_menu