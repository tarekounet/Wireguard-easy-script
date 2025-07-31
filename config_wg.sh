#!/bin/bash

add_script_autostart_to_user() {
    TARGETUSER="$1"
    PROFILE="/home/$TARGETUSER/.bash_profile"
    SCRIPT_PATH="/home/$TARGETUSER/wireguard-script-manager/config_wg.sh"
    if ! grep -q "$SCRIPT_PATH" "$PROFILE" 2>/dev/null; then
        echo '[[ $- == *i* ]] && cd ~/wireguard-script-manager && bash ./config_wg.sh' >> "$PROFILE"
        chown "$TARGETUSER:$TARGETUSER" "$PROFILE"
    fi
}

##############################
#   VARIABLES GÉNÉRALES      #
##############################

GITHUB_USER="tarekounet"
GITHUB_REPO="Wireguard-easy-script"
BRANCH="main"
CONF_FILE="config/wg-easy.conf"
VERSION_FILE="version.txt"
SCRIPT_VERSION="$(cat "$VERSION_FILE" 2>/dev/null || echo "inconnu")"
SCRIPT_BACKUP="config_wg.sh.bak"
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/wg-easy-script.log"
CONFIG_LOG="$LOG_DIR/config-actions.log"
INSTALL_LOG="$LOG_DIR/install.log"
# Détection du bon HOME utilisateur même en sudo/root
if [[ $EUID -eq 0 && -n "$SUDO_USER" ]]; then
    USER_HOME="$(getent passwd $SUDO_USER | cut -d: -f6)"
else
    USER_HOME="$HOME"
fi
DOCKER_WG_DIR="$USER_HOME/docker-wireguard"
DOCKER_COMPOSE_FILE="$DOCKER_WG_DIR/docker-compose.yml"
WG_CONF_DIR="$DOCKER_WG_DIR/config"
SCRIPT_BASE_VERSION_INIT="1.8.6"

export GITHUB_USER
export GITHUB_REPO
export BRANCH

if [[ -f "$VERSION_FILE" ]]; then
    SCRIPT_BASE_VERSION_INIT=$(cat "$VERSION_FILE")
fi

##############################
#   AUTO-BOOTSTRAP MODULES   #
##############################

# Création des dossiers nécessaires
for dir in lib config logs; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo "Dossier créé : $dir/"
    fi
    if [[ ! -w "$dir" || ! -r "$dir" ]]; then
        echo "Erreur : le dossier '$dir/' n'est pas accessible en lecture/écriture."
        exit 1
    fi
done

# Téléchargement automatique des modules manquants
echo "Vérification et téléchargement des modules..."
for mod in utils conf docker menu ; do
    if [[ ! -f "lib/$mod.sh" ]]; then
        echo "Téléchargement de lib/$mod.sh depuis GitHub ($BRANCH)..."
        if curl -fsSL -o "lib/$mod.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/lib/$mod.sh"; then
            chmod +x "lib/$mod.sh"
            echo "✓ Module lib/$mod.sh téléchargé avec succès"
        else
            echo "✗ Échec du téléchargement de lib/$mod.sh"
            exit 1
        fi
    else
        echo "✓ Module lib/$mod.sh déjà présent"
    fi
done

# Téléchargement de auto_update.sh à la racine si absent
if [[ ! -f "auto_update.sh" ]]; then
    echo "Téléchargement de auto_update.sh depuis GitHub ($BRANCH)..."
    if curl -fsSL -o "auto_update.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/auto_update.sh"; then
        chmod +x "auto_update.sh"
        echo "✓ auto_update.sh téléchargé avec succès"
    else
        echo "✗ Échec du téléchargement de auto_update.sh"
    fi
fi

# Chargement des modules
echo "Chargement des modules..."
for f in lib/*.sh; do
    if [[ -f "$f" ]]; then
        echo "Chargement de $f"
        source "$f"
    else
        echo "Erreur : Module $f introuvable après téléchargement"
        exit 1
    fi
done
echo "✓ Tous les modules sont chargés"

##############################
#   INITIALISATION DE LA CONF
##############################

# 1. Récupération depuis GitHub
WG_EASY_VERSION_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/WG_EASY_VERSION"
WG_EASY_VERSION=$(curl -fsSL "$WG_EASY_VERSION_URL" | head -n1)
[[ -z "$WG_EASY_VERSION" ]] && WG_EASY_VERSION="inconnu"

# Vérification explicite de la version locale
WG_EASY_VERSION_LOCAL_FILE="WG_EASY_VERSION"
if [[ -f "$WG_EASY_VERSION_LOCAL_FILE" ]]; then
    WG_EASY_VERSION_LOCAL=$(head -n1 "$WG_EASY_VERSION_LOCAL_FILE")
else
    # Si le fichier n'existe pas, le récupérer depuis GitHub
    curl -fsSL "$WG_EASY_VERSION_URL" -o "$WG_EASY_VERSION_LOCAL_FILE"
    WG_EASY_VERSION_LOCAL=$(head -n1 "$WG_EASY_VERSION_LOCAL_FILE")
    echo -e "\e[32mLe fichier WG_EASY_VERSION a été récupéré depuis GitHub.\e[0m"
fi

# Vérification et comparaison après détection du fichier local
if [[ "$WG_EASY_VERSION_LOCAL" != "$WG_EASY_VERSION" && "$WG_EASY_VERSION" != "inconnu" ]]; then
    echo -e "\e[33mAttention : La version locale ($WG_EASY_VERSION_LOCAL) est différente de celle sur GitHub ($WG_EASY_VERSION)."\e[0m
    read -p $'Voulez-vous mettre à jour le docker-compose.yml avec la version GitHub ? (o/N) : ' CONFIRM_UPDATE
    if [[ "$CONFIRM_UPDATE" =~ ^[oO]$ ]]; then
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            sed -i "s|image: ghcr.io/wg-easy/wg-easy:.*|image: ghcr.io/wg-easy/wg-easy:$WG_EASY_VERSION|" "$DOCKER_COMPOSE_FILE"
            echo -e "\e[32mLe docker-compose.yml a été mis à jour avec la version $WG_EASY_VERSION.\e[0m"
        else
            echo -e "\e[31mLe fichier docker-compose.yml est introuvable.\e[0m"
        fi
    else
        echo -e "\e[33mAucune modification apportée au docker-compose.yml.\e[0m"
    fi
fi

# 2. Création du fichier de conf (si besoin)
if [[ ! -f "$CONF_FILE" ]]; then
    msg_warn "Le fichier de configuration n'existe pas. Création en cours..."
    set_tech_password
    EXPECTED_HASH="$(get_conf_value "EXPECTED_HASH")"
    HASH_SALT="$(get_conf_value "HASH_SALT")"
    cat > "$CONF_FILE" <<EOF
EXPECTED_HASH="$EXPECTED_HASH"
HASH_SALT="$HASH_SALT"
WG_EASY_VERSION="$WG_EASY_VERSION"
EOF
    msg_success "Fichier de configuration créé avec succès."
fi

# 3. Mise à jour de la version dans la conf à chaque lancement
set_conf_value "WG_EASY_VERSION" "$WG_EASY_VERSION"

# Vérification du mot de passe technique uniquement si le hash est encore vide
EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
if [[ -z "$EXPECTED_HASH" ]]; then
    msg_warn "Aucun mot de passe technique enregistré. Veuillez en définir un."
    set_tech_password
fi

##############################
#   LANCEMENT DU SCRIPT      #
##############################

# Lancement du menu principal uniquement si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main_menu
fi