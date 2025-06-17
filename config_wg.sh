#!/bin/bash
# === MENU SPÉCIAL ROOT AUTONOME POUR LA GESTION DES UTILISATEURS ===
if [[ $EUID -eq 0 ]]; then
    user_admin_menu() {
        while true; do
            clear
            echo -e "\e[1;36m=== Menu Administrateur Utilisateurs ===\e[0m"
            echo "1) Créer un utilisateur"
            echo "2) Sélectionner un utilisateur pour éditer ou supprimer"
            echo "0) Quitter"
            read -p "Choix : " CHOIX
            case $CHOIX in
                1)
                    read -p "Nom du nouvel utilisateur : " NEWUSER
                    if id "$NEWUSER" &>/dev/null; then
                        echo "Utilisateur déjà existant."
                    else
                        read -s -p "Mot de passe : " NEWPASS; echo
                        useradd -m "$NEWUSER"
                        echo "$NEWUSER:$NEWPASS" | chpasswd
                        echo "Utilisateur $NEWUSER créé."
                        # Télécharger tout le dépôt dans le dossier wireguard-script-manager du nouvel utilisateur
                        su - "$NEWUSER" -c 'mkdir -p ~/wireguard-script-manager && cd ~/wireguard-script-manager && git clone https://github.com/tarekounet/Wireguard-easy-script.git . || (curl -fsSL -o config_wg.sh https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh && chmod +x config_wg.sh)'
                        # Télécharger le dossier lib si absent
                        su - "$NEWUSER" -c 'if [[ ! -d ~/wireguard-script-manager/lib ]]; then mkdir -p ~/wireguard-script-manager/lib; for mod in utils conf docker menu; do curl -fsSL -o ~/wireguard-script-manager/lib/$mod.sh https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/lib/$mod.sh; chmod +x ~/wireguard-script-manager/lib/$mod.sh; done; fi'
                        # Ajouter le lancement auto dans .bash_profile
                        su - "$NEWUSER" -c 'echo "~/wireguard-script-manager/config_wg.sh" >> ~/.bash_profile'
                        # Attribuer tous les droits à l'utilisateur sur wireguard-script-manager
                        chown -R "$NEWUSER":"$NEWUSER" "/home/$NEWUSER/wireguard-script-manager"
                        chmod -R u+rwx "/home/$NEWUSER/wireguard-script-manager"
                        echo "Dépôt complet téléchargé, modules lib installés, droits attribués et script principal configuré pour lancement automatique à la connexion."
                    fi
                    read -n1 -r -p "Appuie sur une touche pour continuer..." _
                    ;;
                2)
                    echo "Sélectionne un utilisateur :"
                    mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd)
                    for i in "${!USERS[@]}"; do
                        printf "%d) %s\n" $((i+1)) "${USERS[$i]}"
                    done
                    read -p "Numéro de l'utilisateur : " IDX
                    IDX=$((IDX-1))
                    if [[ $IDX -ge 0 && $IDX -lt ${#USERS[@]} ]]; then
                        SELECTED_USER="${USERS[$IDX]}"
                        echo "1) Modifier le mot de passe de $SELECTED_USER"
                        echo "2) Supprimer $SELECTED_USER"
                        echo "0) Retour"
                        read -p "Choix : " SUBCHOIX
                        case $SUBCHOIX in
                            1)
                                passwd "$SELECTED_USER"
                                ;;
                            2)
                                deluser --remove-home "$SELECTED_USER"
                                ;;
                            0)
                                ;;
                            *)
                                echo "Choix invalide."
                                ;;
                        esac
                    else
                        echo "Numéro invalide."
                    fi
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
VERSION_FILE="version.txt"
SCRIPT_VERSION="$(cat "$VERSION_FILE" 2>/dev/null || echo "inconnu")"
SCRIPT_BACKUP="config_wg.sh.bak"
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/wg-easy-script.log"
CONFIG_LOG="$LOG_DIR/config-actions.log"
INSTALL_LOG="$LOG_DIR/install.log"
DOCKER_WG_DIR="$HOME/docker-wireguard"
DOCKER_COMPOSE_FILE="$DOCKER_WG_DIR/docker-compose.yml"
WG_CONF_DIR="$DOCKER_WG_DIR/conf"
SCRIPT_BASE_VERSION_INIT="1.8.5"

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
#           LOGS             #
##############################

# Suppression des écritures dans les fichiers de logs

##############################
#   LANCEMENT DU SCRIPT      #
##############################

main_menu