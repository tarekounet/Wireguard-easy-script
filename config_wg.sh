#!/bin/bash

##############################
# 0. INSTALLATION OFFICIELLE DE DOCKER ET DOCKER COMPOSE (Debian/Ubuntu)
##############################

install_docker_official() {
    echo "Installation officielle de Docker (dépôt Docker)..."
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
}

# Vérifie et installe curl (si besoin)
if ! command -v curl &>/dev/null; then
    echo "Installation de curl..."
    if [[ $EUID -ne 0 ]]; then
        echo "Ce script doit être lancé en root pour installer curl."
        exit 1
    fi
    apt-get update && apt-get install -y curl
fi

# Vérifie et installe docker et docker compose (méthode officielle)
if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null; then
    if [[ $EUID -ne 0 ]]; then
        echo "Ce script doit être lancé en root pour installer Docker."
        exit 1
    fi
    install_docker_official
fi

echo "Tous les prérequis (curl, docker, docker compose) sont installés."

# Vérifie et installe vim et btop (si besoin)
for pkg in vim btop; do
    if ! command -v "$pkg" &>/dev/null; then
        echo "Installation de $pkg..."
        if [[ $EUID -ne 0 ]]; then
            echo "Ce script doit être lancé en root pour installer $pkg."
            exit 1
        fi
        apt-get update && apt-get install -y "$pkg"
    fi
done

##############################
# 1. CRÉATION DES DOSSIERS ET DROITS
##############################
for dir in lib config logs; do
    if [[ ! -d "$dir" ]]; then
        mkdir "$dir"
        echo "Dossier $dir créé."
    fi
    chmod -R u+rwX "$dir"
    if [[ ! -w "$dir" || ! -r "$dir" || ! -x "$dir" ]]; then
        echo "Erreur : le dossier '$dir/' n'est pas accessible en lecture/écriture/exécution."
        exit 1
    fi
done

##############################
# 2. INITIALISATION UTILISATEUR (root uniquement, une seule fois)
##############################
USER_SETUP_FLAG="config/.user_setup_done"

if [[ $EUID -eq 0 && ! -f "$USER_SETUP_FLAG" ]]; then
    echo -e "\e[1;33mVous exécutez ce script en tant que root.\e[0m"
    echo "Configuration de l'utilisateur pour l'exécution automatique du script."

    # Demander le nom de l'utilisateur à créer
    while true; do
        read -p "Entrez le nom du nouvel utilisateur : " NEWUSER
        if [[ -z "$NEWUSER" || ${#NEWUSER} -lt 2 ]]; then
            echo "Nom invalide. 2 caractères minimum."
            continue
        elif id "$NEWUSER" &>/dev/null; then
            echo "Ce nom existe déjà. Veuillez en choisir un autre."
            continue
        fi

        # Demander le mot de passe
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

        # Créer l'utilisateur
        useradd -m -s /bin/bash "$NEWUSER"
        echo "$NEWUSER:$NEWPASS" | chpasswd
        echo -e "\e[1;32mUtilisateur '$NEWUSER' créé avec succès.\e[0m"
        # Ajouter l'utilisateur au groupe docker
        if ! id -nG "$NEWUSER" | grep -qw docker; then
            usermod -aG docker "$NEWUSER"
            echo -e "\e[1;32mUtilisateur '$NEWUSER' ajouté au groupe docker.\e[0m"
        else
            echo -e "\e[1;34mL'utilisateur '$NEWUSER' est déjà membre du groupe docker.\e[0m"
        fi
        break
    done

    # Configurer l'architecture dans le répertoire personnel de l'utilisateur
    USER_HOME="/home/$NEWUSER/wireguard-easy-script"
    mkdir -p "$USER_HOME/lib" "$USER_HOME/config" "$USER_HOME/logs"
    cp config_wg.sh "$USER_HOME/"
    cp auto_update.sh "$USER_HOME/"
    cp CHANGELOG.md "$USER_HOME/"
    cp README.md "$USER_HOME/"
    chown -R "$NEWUSER:$NEWUSER" "$USER_HOME"

    # Ajouter le lancement automatique du script à la connexion
    PROFILE_FILE="/home/$NEWUSER/.bash_profile"
    SCRIPT_PATH="$USER_HOME/config_wg.sh"
    echo "[[ \$- == *i* ]] && bash \"$SCRIPT_PATH\"" >> "$PROFILE_FILE"
    chown "$NEWUSER:$NEWUSER" "$PROFILE_FILE"

    # Créer le fichier témoin pour éviter de répéter cette étape
    touch "$USER_SETUP_FLAG"
    chown "$NEWUSER:$NEWUSER" "$USER_SETUP_FLAG"

    echo -e "\e[1;32mConfiguration terminée pour l'utilisateur '$NEWUSER'.\e[0m"
fi

##############################
# 3. TÉLÉCHARGEMENT DES MODULES
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
    chmod u+rwX "lib/$mod.sh"
done

if [[ ! -f "auto_update.sh" ]]; then
    echo "Téléchargement de auto_update.sh depuis GitHub ($BRANCH)..."
    curl -fsSL -o "auto_update.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/auto_update.sh"
    chmod +x "auto_update.sh"
    chmod u+rwX "auto_update.sh"
fi

##############################
# 4. CHARGEMENT DES MODULES
##############################
source lib/conf.sh
source lib/utils.sh
source lib/docker.sh
source lib/menu.sh

##############################
# 5. VARIABLES GÉNÉRALES
##############################
CONF_FILE="config/wg-easy.conf"
VERSION_FILE="version.txt"
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/wg-easy-script.log"
CONFIG_LOG="$LOG_DIR/config-actions.log"
DOCKER_COMPOSE_DIR="$HOME/wireguard"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"
SCRIPT_BASE_VERSION_INIT="1.7.3"

##############################
# 6. LECTURE DU CANAL/BRANCHE
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
# 7. INITIALISATION DE LA CONF
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
# 8. VÉRIFICATION DU MOT DE PASSE
##############################
EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
while [[ -z "$EXPECTED_HASH" ]]; do
    msg_warn "Aucun mot de passe technique enregistré. Veuillez en définir un."
    set_tech_password
    EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
done

##############################
# 9. LOGS DE LANCEMENT
##############################
echo "$(date '+%F %T') [INFO] Script principal lancé" >> "$LOG_FILE"
echo "$(date '+%F %T') [CONF] Fichier de configuration créé" >> "$CONFIG_LOG"
echo "$(date '+%F %T') [UPDATE] Version Wireguard Easy : $WG_EASY_VERSION" >> "$LOG_FILE"

##############################
# 10. LANCEMENT DU SCRIPT
##############################
check_updates
main_menu