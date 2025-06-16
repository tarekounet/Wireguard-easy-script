#!/bin/bash

# Empêche le sourcing infini du script principal
if [[ -z "$CONFIG_WG_SOURCED" ]]; then
    export CONFIG_WG_SOURCED=1
else
    return 0 2>/dev/null || exit 0
fi

# Inclusion du module de gestion de la conf et du mot de passe technique
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/conf.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/menu.sh"

########################################
# 1. INITIALISATION & VARIABLES GLOBALES
########################################
CONF_DIR="$SCRIPT_DIR/config"
CONF_FILE="$CONF_DIR/wg-easy.conf"
VERSION_FILE="$SCRIPT_DIR/version.txt"
FIRST_RUN_DIR="/var/tmp/wireguard"
FIRST_RUN_FLAG="$FIRST_RUN_DIR/.first_run_done"
USER_HOME="$HOME/wireguard-easy-script"
USER_FLAG="$USER_HOME/.structure_done"
GITHUB_USER="tarekounet"
GITHUB_REPO="Wireguard-easy-script"
BRANCH="main"

# Définition du chemin du log
LOG_FILE="$SCRIPT_DIR/wg-easy-script.log"

# Fonction utilitaire pour écrire dans le log
log_action() {
    echo "$(date '+%F %T') [LOG] $1" >> "$LOG_FILE"
}

# Exemple d'utilisation : log du lancement du script
log_action "Script principal lancé par $USER (UID=$EUID)"
log_action "Début du script principal"

########################################
# 2. FONCTIONS UTILITAIRES
########################################
msg_success() { echo -e "\e[1;32m$1\e[0m"; }
msg_warn()    { echo -e "\e[1;33m$1\e[0m"; }
msg_error()   { echo -e "\e[1;31m$1\e[0m"; }

########################################
# 3. GESTION DU FLAG DE PREMIÈRE CRÉATION UTILISATEUR (ROOT)
########################################
if [[ $EUID -eq 0 ]]; then
    FIRST_RUN_FLAG="/var/tmp/wireguard/.first_user_created"
    if [[ -f "$FIRST_RUN_FLAG" ]]; then
        echo "Installation déjà réalisée. Connectez-vous avec l'utilisateur créé."
        exit 0
    fi

    # Installation Docker officielle
    install_docker_official() {
        echo "Installation officielle de Docker (dépôt Docker)..."
        apt-get update
        apt-get install -y ca-certificates curl gnupg lsb-release
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
          > /etc/apt/sources.list.d/docker.list
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        systemctl enable --now docker
    }

    # Vérifie et installe curl (si besoin)
    if ! command -v curl &>/dev/null; then
        echo "Installation de curl..."
        apt-get update && apt-get install -y curl
    fi
    # Vérifie et installe docker et docker compose (méthode officielle)
    if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null; then
        install_docker_official
    fi
    echo "Tous les prérequis (curl, docker, docker compose) sont installés."
    for pkg in vim btop sudo openssl; do
        if ! command -v "$pkg" &>/dev/null; then
            echo "Installation de $pkg..."
            apt-get update && apt-get install -y "$pkg"
        fi
    done

    # Création du nouvel utilisateur
    while true; do
            # Désactive l'utilisateur 'system' si présent
        # if id "system" &>/dev/null; then
        #     echo -e "\e[1;31mL'utilisateur 'system' existe. Il va être désactivé.\e[0m"
        #     usermod -L -s /usr/sbin/nologin system
        #     echo -e "\e[1;32mL'utilisateur 'system' a été désactivé.\e[0m"
        # fi
        read -p "Entrez le nom du nouvel utilisateur : " NEWUSER
        if [[ -z "$NEWUSER" || ${#NEWUSER} -lt 2 ]]; then
            echo "Nom invalide. 2 caractères minimum."
            continue
        elif id "$NEWUSER" &>/dev/null; then
            echo "Ce nom existe déjà. Veuillez en choisir un autre."
            continue
        fi
        while true; do
            read -s -p "Entrez le mot de passe (8 caractères mini) : " NEWPASS
            echo
            read -s -p "Confirmez le mot de passe : " NEWPASS2
            echo
            if [[ ${#NEWPASS} -lt 8 ]]; then
                echo "Mot de passe trop court."
            elif [[ "$NEWPASS" != "$NEWPASS2" ]]; then
                echo "Les mots de passe ne correspondent pas."
            else
                break
            fi
        done
        useradd -m -s /bin/bash -G docker "$NEWUSER"
        echo "$NEWUSER:$NEWPASS" | chpasswd
        echo -e "\e[1;32mNouvel utilisateur '$NEWUSER' créé et ajouté au groupe docker.\e[0m"
        log_action "Nouvel utilisateur créé : $NEWUSER"
        # Copier le script principal dans le dossier wireguard-easy-script du nouvel utilisateur
        USER_HOME="/home/$NEWUSER/wireguard-easy-script"
        mkdir -p "$USER_HOME"
        chmod u+rwX "$USER_HOME"
        cp "$0" "$USER_HOME/"
        chown -R "$NEWUSER:$NEWUSER" "$USER_HOME"
        # Ajouter le lancement auto du script à la connexion
        PROFILE="/home/$NEWUSER/.bash_profile"
        SCRIPT_PATH="$USER_HOME/$(basename "$0")"
        if ! grep -q "$SCRIPT_PATH" "$PROFILE" 2>/dev/null; then
            echo "[[ \$- == *i* ]] && bash \"$SCRIPT_PATH\"" >> "$PROFILE"
            chown "$NEWUSER:$NEWUSER" "$PROFILE"
            echo -e "\e[1;32mLe script sera lancé automatiquement à la connexion de $NEWUSER.\e[0m"
        fi

        # Vérification et création des dossiers /mnt/wireguard et /mnt/wireguard/config
        WG_DIR="/mnt/wireguard"
        WG_CONFIG_DIR="$WG_DIR/config"

        # Création des dossiers si besoin
        if [[ ! -d "$WG_DIR" ]]; then
            mkdir -p "$WG_CONFIG_DIR"
            echo "Dossier $WG_CONFIG_DIR créé."
        elif [[ ! -d "$WG_CONFIG_DIR" ]]; then
            mkdir -p "$WG_CONFIG_DIR"
            echo "Dossier $WG_CONFIG_DIR créé."
        fi

        # Attribution des droits lecture/écriture à l'utilisateur
        chown -R "$NEWUSER":"$NEWUSER" "$WG_DIR"
        chmod -R u+rwX "$WG_DIR"

        break
    done
    touch "$FIRST_RUN_FLAG"
    echo "Installation terminée. Connectez-vous avec l'utilisateur '$NEWUSER' pour continuer."
    log_action "Fin de l'installation, prêt à l'emploi."
    exit 0
fi

########################################
# 5. STRUCTURE UTILISATEUR & MODULES
########################################
if [[ ! -f "$USER_FLAG" ]]; then
    mkdir -p "$USER_HOME/lib" "$USER_HOME/config" "$USER_HOME/logs"
    cp "$SCRIPT_DIR/config_wg.sh" "$USER_HOME/"
    cp "$SCRIPT_DIR/CHANGELOG.md" "$USER_HOME/" 2>/dev/null || true
    cp "$SCRIPT_DIR/README.md" "$USER_HOME/" 2>/dev/null || true
    for mod in utils conf docker menu; do
        MOD_PATH="$USER_HOME/lib/$mod.sh"
        if [[ ! -f "$MOD_PATH" ]]; then
            echo "Téléchargement de lib/$mod.sh depuis GitHub ($BRANCH)..."
            curl -fsSL -o "$MOD_PATH" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/lib/$mod.sh"
        fi
        chmod u+rwX "$MOD_PATH"
        chmod +x "$MOD_PATH"
    done
    touch "$USER_FLAG"
    log_action "Modules téléchargés/copés dans $USER_HOME/lib"
    msg_success "Structure et modules téléchargés dans $USER_HOME."
fi

########################################
# 6. CHARGEMENT DES MODULES
########################################
CONFIG_WG_PATH="$USER_HOME/config_wg.sh"
if [[ -z "$CONFIG_WG_SOURCED" ]]; then
    source "$CONFIG_WG_PATH"
fi

########################################
# 7. CONFIGURATION & LECTURE DES FICHIERS
########################################
CONF_FILE="$SCRIPT_DIR/config/wg-easy.conf"
VERSION_FILE="$SCRIPT_DIR/version.txt"
DOCKER_COMPOSE_DIR="$HOME/wireguard"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"
SCRIPT_BASE_VERSION_INIT="1.8.0"

##############################
# 7. LECTURE DU CANAL/BRANCHE
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

if [[ -f "$VERSION_FILE" ]]; then
    SCRIPT_BASE_VERSION_INIT=$(cat "$VERSION_FILE")
fi

##############################
# 8. INITIALISATION DE LA CONF
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
# 9. VÉRIFICATION DU MOT DE PASSE
##############################
EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
while [[ -z "$EXPECTED_HASH" ]]; do
    msg_warn "Aucun mot de passe technique enregistré. Veuillez en définir un."
    set_tech_password
    EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
done

########################################
# 11. LANCEMENT DU MENU PRINCIPAL OU LOGIQUE UTILISATEUR
########################################
check_updates
main_menu
export CONFIG_WG_SOURCED=1