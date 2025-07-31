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
SCRIPT_VERSION="2.0.0"  # Version par défaut
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

# Vérifier plusieurs emplacements possibles pour docker-wireguard
POSSIBLE_DOCKER_DIRS=(
    "$USER_HOME/docker-wireguard"
    "./docker-wireguard"
    "../docker-wireguard"
    "$USER_HOME/wireguard-script-manager/docker-wireguard"
    "docker-wireguard"
)

DOCKER_WG_DIR=""
DOCKER_COMPOSE_FILE=""

# Trouver le bon répertoire docker-wireguard
for dir in "${POSSIBLE_DOCKER_DIRS[@]}"; do
    if [[ -d "$dir" && -f "$dir/docker-compose.yml" ]]; then
        DOCKER_WG_DIR="$dir"
        DOCKER_COMPOSE_FILE="$DOCKER_WG_DIR/docker-compose.yml"
        echo "✓ Répertoire docker-wireguard trouvé : $DOCKER_WG_DIR"
        break
    fi
done

# Si aucun répertoire trouvé, utiliser le chemin par défaut
if [[ -z "$DOCKER_WG_DIR" ]]; then
    DOCKER_WG_DIR="$USER_HOME/docker-wireguard"
    DOCKER_COMPOSE_FILE="$DOCKER_WG_DIR/docker-compose.yml"
    echo "✗ Aucun répertoire docker-wireguard trouvé, utilisation du chemin par défaut : $DOCKER_WG_DIR"
fi

WG_CONF_DIR="$DOCKER_WG_DIR/config"
SCRIPT_BASE_VERSION_INIT="1.8.6"

export GITHUB_USER
export GITHUB_REPO
export BRANCH

# Détection de la version du script
if [[ -f "$VERSION_FILE" && -s "$VERSION_FILE" ]]; then
    SCRIPT_VERSION_FROM_FILE=$(cat "$VERSION_FILE" 2>/dev/null | head -n1 | tr -d '\n\r ')
    if [[ -n "$SCRIPT_VERSION_FROM_FILE" && "$SCRIPT_VERSION_FROM_FILE" != "" ]]; then
        SCRIPT_VERSION="$SCRIPT_VERSION_FROM_FILE"
        echo "✓ Version lue depuis $VERSION_FILE : $SCRIPT_VERSION"
    else
        echo "✗ Fichier $VERSION_FILE vide, utilisation de la version par défaut : $SCRIPT_VERSION"
    fi
    SCRIPT_BASE_VERSION_INIT="$SCRIPT_VERSION"
else
    # Créer le fichier version.txt s'il n'existe pas
    echo "$SCRIPT_VERSION" > "$VERSION_FILE"
    SCRIPT_BASE_VERSION_INIT="$SCRIPT_VERSION"
    echo "✓ Fichier $VERSION_FILE créé avec la version : $SCRIPT_VERSION"
fi

echo "Version du script : $SCRIPT_VERSION"

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
echo "Récupération de la version WG-Easy depuis GitHub..."

# Essayer de récupérer la version depuis GitHub
WG_EASY_VERSION=$(curl -fsSL --connect-timeout 10 "$WG_EASY_VERSION_URL" 2>/dev/null | head -n1 | tr -d '\n\r')

# Si échec, utiliser une version par défaut
if [[ -z "$WG_EASY_VERSION" ]]; then
    WG_EASY_VERSION="15.1.0"  # Version par défaut récente
    echo "✗ Impossible de récupérer la version depuis GitHub, utilisation de la version par défaut : $WG_EASY_VERSION"
else
    echo "✓ Version récupérée depuis GitHub : $WG_EASY_VERSION"
fi

# Vérification explicite de la version locale
WG_EASY_VERSION_LOCAL_FILE="WG_EASY_VERSION"
WG_EASY_VERSION_LOCAL=""

# D'abord, essayer de lire le fichier WG_EASY_VERSION local (dans le répertoire du script)
echo "Lecture du fichier WG_EASY_VERSION local..."
if [[ -f "$WG_EASY_VERSION_LOCAL_FILE" && -s "$WG_EASY_VERSION_LOCAL_FILE" ]]; then
    WG_EASY_VERSION_LOCAL=$(cat "$WG_EASY_VERSION_LOCAL_FILE" 2>/dev/null | head -n1 | tr -d '\n\r ')
    if [[ -n "$WG_EASY_VERSION_LOCAL" && "$WG_EASY_VERSION_LOCAL" != "" ]]; then
        echo "✓ Version locale trouvée dans WG_EASY_VERSION : $WG_EASY_VERSION_LOCAL"
    else
        echo "✗ Fichier WG_EASY_VERSION vide"
        WG_EASY_VERSION_LOCAL=""
    fi
else
    echo "✗ Fichier WG_EASY_VERSION non trouvé ou vide"
fi

# Si pas de version locale trouvée, créer le fichier avec la version GitHub
if [[ -z "$WG_EASY_VERSION_LOCAL" ]]; then
    echo "$WG_EASY_VERSION" > "$WG_EASY_VERSION_LOCAL_FILE"
    WG_EASY_VERSION_LOCAL="$WG_EASY_VERSION"
    echo "✓ Fichier WG_EASY_VERSION créé avec la version $WG_EASY_VERSION"
fi

# Si docker-compose.yml existe, extraire la version actuelle
echo "Vérification du fichier docker-compose.yml..."
echo "Chemin recherché : $DOCKER_COMPOSE_FILE"

if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
    echo "✓ Fichier docker-compose.yml trouvé dans $DOCKER_WG_DIR"
    CURRENT_VERSION_IN_COMPOSE=$(grep -o 'ghcr.io/wg-easy/wg-easy:[^[:space:]]*' "$DOCKER_COMPOSE_FILE" 2>/dev/null | cut -d: -f3 | head -n1)
    if [[ -n "$CURRENT_VERSION_IN_COMPOSE" ]]; then
        echo "Version actuelle dans docker-compose.yml : $CURRENT_VERSION_IN_COMPOSE"
        # Utiliser la version du docker-compose comme référence locale (priorité sur le fichier WG_EASY_VERSION)
        WG_EASY_VERSION_LOCAL="$CURRENT_VERSION_IN_COMPOSE"
    else
        echo "✗ Impossible d'extraire la version depuis docker-compose.yml"
        echo "→ Utilisation de la version du fichier WG_EASY_VERSION : $WG_EASY_VERSION_LOCAL"
    fi
else
    echo "✗ Fichier docker-compose.yml non trouvé"
    echo "→ Utilisation de la version du fichier WG_EASY_VERSION : $WG_EASY_VERSION_LOCAL"
    echo "✗ Emplacements vérifiés :"
    for dir in "${POSSIBLE_DOCKER_DIRS[@]}"; do
        echo "   - $dir/docker-compose.yml"
    done
fi

# Vérification et comparaison après détection du fichier local
echo "=== DIAGNOSTIC COMPLET ==="
echo "Répertoire de travail : $(pwd)"
echo "Répertoire docker-wireguard : $DOCKER_WG_DIR"
echo "Fichier version.txt : $VERSION_FILE (existe: $(test -f "$VERSION_FILE" && echo "OUI" || echo "NON"))"
echo "Fichier WG_EASY_VERSION : $WG_EASY_VERSION_LOCAL_FILE (existe: $(test -f "$WG_EASY_VERSION_LOCAL_FILE" && echo "OUI" || echo "NON"))"
echo "Fichier docker-compose : $DOCKER_COMPOSE_FILE (existe: $(test -f "$DOCKER_COMPOSE_FILE" && echo "OUI" || echo "NON"))"
echo "=========================="

echo "=== RÉSUMÉ DES VERSIONS ==="
echo "Version GitHub : ${WG_EASY_VERSION:-VIDE}"
echo "Version locale : ${WG_EASY_VERSION_LOCAL:-VIDE}"
echo "Version script : ${SCRIPT_VERSION:-VIDE}"
echo "=========================="

if [[ "$WG_EASY_VERSION_LOCAL" != "$WG_EASY_VERSION" && "$WG_EASY_VERSION" != "inconnu" && -n "$WG_EASY_VERSION_LOCAL" && "$WG_EASY_VERSION_LOCAL" != "inconnu" ]]; then
    echo -e "\e[33mNouvelle version Wireguard Easy disponible : $WG_EASY_VERSION (actuelle : $WG_EASY_VERSION_LOCAL)\e[0m"
    read -p $'Voulez-vous mettre à jour le docker-compose.yml avec la version $WG_EASY_VERSION ? (o/N) : ' CONFIRM_UPDATE
    if [[ "$CONFIRM_UPDATE" =~ ^[oO]$ ]]; then
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            # Sauvegarder le fichier avant modification
            cp "$DOCKER_COMPOSE_FILE" "$DOCKER_COMPOSE_FILE.bak"
            sed -i "s|image: ghcr.io/wg-easy/wg-easy:.*|image: ghcr.io/wg-easy/wg-easy:$WG_EASY_VERSION|" "$DOCKER_COMPOSE_FILE"
            # Mettre à jour le fichier de version locale
            echo "$WG_EASY_VERSION" > "$WG_EASY_VERSION_LOCAL_FILE"
            echo -e "\e[32mLe docker-compose.yml a été mis à jour avec la version $WG_EASY_VERSION.\e[0m"
            echo -e "\e[32mSauvegarde créée : $DOCKER_COMPOSE_FILE.bak\e[0m"
        else
            echo -e "\e[31mLe fichier docker-compose.yml est introuvable dans $DOCKER_COMPOSE_FILE.\e[0m"
        fi
    else
        echo -e "\e[33mAucune modification apportée au docker-compose.yml.\e[0m"
    fi
elif [[ "$WG_EASY_VERSION_LOCAL" == "$WG_EASY_VERSION" ]]; then
    echo -e "\e[32mVotre version Wireguard Easy est à jour : $WG_EASY_VERSION\e[0m"
elif [[ -z "$WG_EASY_VERSION_LOCAL" || "$WG_EASY_VERSION_LOCAL" == "inconnu" ]]; then
    echo -e "\e[31mImpossible de déterminer la version actuelle. Fichier docker-compose.yml introuvable.\e[0m"
    echo -e "\e[33mAssurez-vous que Wireguard Easy est installé et que le fichier docker-compose.yml existe.\e[0m"
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