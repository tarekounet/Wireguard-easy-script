#!/bin/bash
# Auto-bootstrap des modules si le dossier lib/ ou des modules sont manquants

for mod in utils conf docker menu ; do
    if [[ ! -f "lib/$mod.sh" ]]; then
        echo "Module manquant : lib/$mod.sh"
        exit 1
    fi
done
##############################
#   VARIABLES GÉNÉRALES      #
##############################

GITHUB_USER="tarekounet"
GITHUB_REPO="Wireguard-easy-script"
CONF_FILE="config/wg-easy.conf"
AUTO_UPDATE_CONF="config/auto_update.conf"
VERSION_FILE="version.txt"
SCRIPT_BACKUP="config_wg.sh.bak"
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/wg-easy-script.log"
UPDATE_LOG="$LOG_DIR/auto_update.log"
DOCKER_LOG="$LOG_DIR/docker-actions.log"
AUTH_LOG="$LOG_DIR/auth.log"
CONFIG_LOG="$LOG_DIR/config-actions.log"
INSTALL_LOG="$LOG_DIR/install.log"
DOCKER_WG_DIR="$HOME/docker-wireguard"
DOCKER_COMPOSE_FILE="$DOCKER_WG_DIR/docker-compose.yml"
WG_CONF_DIR="$DOCKER_WG_DIR/conf"
SCRIPT_BASE_VERSION_INIT="1.7.0"

export GITHUB_USER
export GITHUB_REPO
export BRANCH

BRANCH="main"

if [[ -f "$VERSION_FILE" ]]; then
    SCRIPT_BASE_VERSION_INIT=$(cat "$VERSION_FILE")
fi

##############################
#   AUTO-BOOTSTRAP MODULES   #
##############################

for dir in lib config logs; do
    if [[ ! -d "$dir" ]]; then
        mkdir "$dir"
    fi
    if [[ ! -w "$dir" || ! -r "$dir" ]]; then
        echo "Erreur : le dossier '$dir/' n'est pas accessible en lecture/écriture."
        exit 1
    fi
done

# Téléchargement des modules principaux
for mod in utils conf docker menu ; do
    if [[ ! -f "lib/$mod.sh" ]]; then
        echo "Téléchargement de lib/$mod.sh depuis GitHub ($BRANCH)..."
        curl -fsSL -o "lib/$mod.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/lib/$mod.sh"
        chmod +x "lib/$mod.sh"
    fi
done

# Téléchargement de auto_update.sh à la racine si absent
if [[ ! -f "auto_update.sh" ]]; then
    echo "Téléchargement de auto_update.sh depuis GitHub ($BRANCH)..."
    curl -fsSL -o "auto_update.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/auto_update.sh"
    chmod +x "auto_update.sh"
fi

# Chargement des modules
for f in lib/*.sh; do
    source "$f"
done

##############################
#   INITIALISATION DE LA CONF
##############################

# 1. Récupération depuis GitHub
WG_EASY_VERSION_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/WG_EASY_VERSION"
WG_EASY_VERSION=$(curl -fsSL "$WG_EASY_VERSION_URL" | head -n1)
[[ -z "$WG_EASY_VERSION" ]] && WG_EASY_VERSION="inconnu"

# 2. Création du fichier de conf (si besoin)
if [[ ! -f "$CONF_FILE" ]]; then
    msg_warn "Le fichier de configuration n'existe pas. Création en cours..."
    set_tech_password
    cat > "$CONF_FILE" <<EOF
SCRIPT_BASE_VERSION="$SCRIPT_BASE_VERSION_INIT"
EXPECTED_HASH="$(get_conf_value "EXPECTED_HASH")"
BETA_CONFIRMED="0"
RAZ="1"
WG_EASY_VERSION="$WG_EASY_VERSION"
EOF
    msg_success "Fichier de configuration créé avec succès."
fi

# 3. Mise à jour de la version dans la conf à chaque lancement
set_conf_value "WG_EASY_VERSION" "$WG_EASY_VERSION"

# verification du mot de passe technique
EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
while [[ -z "$EXPECTED_HASH" ]]; do
    msg_warn "Aucun mot de passe technique enregistré. Veuillez en définir un."
    set_tech_password
    EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
done
##############################
#           LOGS             #
##############################

echo "$(date '+%F %T') [INFO] Script principal lancé" >> "$LOG_FILE"
echo "$(date '+%F %T') [CONF] Fichier de configuration créé" >> "$CONFIG_LOG"
echo "$(date '+%F %T') [UPDATE] Nouvelle version détectée : $NEW_VERSION" >> "$LOG_FILE"

# === MENU SPÉCIAL ROOT AUTONOME POUR LA GESTION DES UTILISATEURS ===
if [[ $EUID -eq 0 ]]; then
    user_admin_menu() {
        while true; do
            clear
            echo -e "\e[1;36m=== Menu Administrateur Utilisateurs ===\e[0m"
            echo "1) Créer un utilisateur"
            echo "2) Modifier le mot de passe d'un utilisateur"
            echo "3) Supprimer un utilisateur"
            echo "4) Lister les utilisateurs (hors comptes système)"
            echo "0) Quitter"
            read -p "Choix : " CHOIX
            case $CHOIX in
                1)
                    read -p "Nom du nouvel utilisateur : " NEWUSER
                    if id "$NEWUSER" &>/dev/null; then
                        echo "Utilisateur déjà existant."
                    else
                        adduser "$NEWUSER"
                    fi
                    read -n1 -r -p "Appuie sur une touche pour continuer..." _
                    ;;
                2)
                    read -p "Utilisateur à modifier : " MODUSER
                    if id "$MODUSER" &>/dev/null; then
                        passwd "$MODUSER"
                    else
                        echo "Utilisateur introuvable."
                    fi
                    read -n1 -r -p "Appuie sur une touche pour continuer..." _
                    ;;
                3)
                    read -p "Utilisateur à supprimer : " DELUSER
                    if id "$DELUSER" &>/dev/null; then
                        deluser --remove-home "$DELUSER"
                    else
                        echo "Utilisateur introuvable."
                    fi
                    read -n1 -r -p "Appuie sur une touche pour continuer..." _
                    ;;
                4)
                    echo "Utilisateurs non système :"
                    awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd
                    read -n1 -r -p "Appuie sur une touche pour continuer..." _
                    ;;
                0)
                    exit 0
                    ;;
                *)
                    echo "Choix invalide."
                    read -n1 -r -p "Appuie sur une touche pour continuer..." _
                    ;;
            esac
        done
    }
    user_admin_menu
    exit 0
fi

##############################
#   LANCEMENT DU SCRIPT      #
##############################

check_updates
main_menu