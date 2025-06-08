#!/bin/bash
# Auto-bootstrap des modules si le dossier lib/ ou des modules sont manquants

##############################
#   VARIABLES GÉNÉRALES      #
##############################

GITHUB_USER="tarekounet"
GITHUB_REPO="Wireguard-easy-script"
CONF_FILE="wg-easy.conf"
VERSION_FILE="version.txt"
SCRIPT_BACKUP="config_wg.sh.bak"
LOG_FILE="/var/log/wg-easy-script.log"
DOCKER_COMPOSE_DIR="/mnt/wireguard"
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/docker-compose.yml"
SCRIPT_CHANNEL="stable"
SCRIPT_BASE_VERSION_INIT="1.7.0"

# Détecte le canal si déjà présent dans la conf
if [[ -f "$CONF_FILE" ]]; then
    SCRIPT_CHANNEL=$(grep '^SCRIPT_CHANNEL=' "$CONF_FILE" | cut -d'"' -f2)
    [[ -z "$SCRIPT_CHANNEL" ]] && SCRIPT_CHANNEL="stable"
fi

BRANCH="${SCRIPT_CHANNEL:-main}"

if [[ -f "$VERSION_FILE" ]]; then
    SCRIPT_BASE_VERSION_INIT=$(cat "$VERSION_FILE")
fi

##############################
#   AUTO-BOOTSTRAP MODULES   #
##############################

if [[ ! -d lib ]]; then
    mkdir lib
fi

for mod in utils conf docker menu debian_tools; do
    if [[ ! -f "lib/$mod.sh" ]]; then
        echo "Téléchargement de lib/$mod.sh depuis GitHub ($BRANCH)..."
        curl -fsSL -o "lib/$mod.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/lib/$mod.sh"
        chmod +x "lib/$mod.sh"
    fi
done

# Chargement des modules
for f in lib/*.sh; do
    source "$f"
done

##############################
#   INITIALISATION DE LA CONF
##############################

if [[ ! -f "$CONF_FILE" ]]; then
    msg_warn "Le fichier de configuration n'existe pas. Création en cours..."
    set_tech_password
    cat > "$CONF_FILE" <<EOF
SCRIPT_CHANNEL="$SCRIPT_CHANNEL"
SCRIPT_BASE_VERSION="$SCRIPT_BASE_VERSION_INIT"
EXPECTED_HASH="$(get_conf_value "EXPECTED_HASH")"
BETA_CONFIRMED="0"
RAZ="1"
EOF
    msg_success "Fichier de configuration créé avec succès."
fi

##############################
#   LANCEMENT DU SCRIPT      #
##############################

check_updates
main_menu