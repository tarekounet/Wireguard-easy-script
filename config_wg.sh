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
SCRIPT_BASE_VERSION_INIT="1.8.5"

export GITHUB_USER
export GITHUB_REPO
export BRANCH

BRANCH="main"

if [[ -f "$VERSION_FILE" ]]; then
    SCRIPT_BASE_VERSION_INIT=$(cat "$VERSION_FILE")
fi

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
while true; do
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
        USER_HOME="/home/$NEWUSER/wireguard-script-manager"
        mkdir -p "$USER_HOME"
        chmod u+rwX "$USER_HOME"
        # Télécharger tout le projet depuis GitHub et le copier dans le dossier wireguard-script-manager de l'utilisateur
        read -p "Souhaitez-vous télécharger et copier tout le projet GitHub dans wireguard-script-manager de l'utilisateur ? (o/N) : " DL_ALL
        if [[ "$DL_ALL" =~ ^[oO]$ ]]; then
            BRANCH="main"  # ou récupère la branche depuis la conf si besoin
            TMP_UPDATE_DIR="/tmp/wg-easy-usercopy"
            rm -rf "$TMP_UPDATE_DIR"
            mkdir -p "$TMP_UPDATE_DIR"
            ZIP_URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/archive/refs/heads/${BRANCH}.zip"
            curl -fsSL "$ZIP_URL" -o "$TMP_UPDATE_DIR/update.zip"
            unzip -q "$TMP_UPDATE_DIR/update.zip" -d "$TMP_UPDATE_DIR"
            EXTRACTED_DIR=$(find "$TMP_UPDATE_DIR" -maxdepth 1 -type d -name "$GITHUB_REPO-*")
            if [[ -d "$EXTRACTED_DIR" ]]; then
            # Copier uniquement les fichiers nécessaires au fonctionnement du script
            cp -r "$EXTRACTED_DIR/lib" "$USER_HOME/"
            cp "$EXTRACTED_DIR/config_wg.sh" "$USER_HOME/"
            cp "$EXTRACTED_DIR/version.txt" "$USER_HOME/" 2>/dev/null || true
            chmod -R +x "$USER_HOME/lib"/*.sh 2>/dev/null
            chown -R "$NEWUSER:$NEWUSER" "$USER_HOME"
            echo -e "\e[1;32mFichiers nécessaires copiés dans $USER_HOME.\e[0m"
            else
            echo -e "\e[1;31mErreur lors de l'extraction du projet GitHub.\e[0m"
            fi
            rm -rf "$TMP_UPDATE_DIR"
        else
            cp "$0" "$USER_HOME/"
            chown "$NEWUSER:$NEWUSER" "$USER_HOME/$(basename "$0")"
        fi
        # Proposer le lancement auto à la connexion
        read -p "Souhaitez-vous lancer ce script automatiquement à la connexion de $NEWUSER ? (o/N) : " AUTOSTART
        if [[ "$AUTOSTART" =~ ^[oO]$ ]]; then
            PROFILE="/home/$NEWUSER/.bash_profile"
            SCRIPT_PATH="$USER_HOME/config_wg.sh"
            if ! grep -q "$SCRIPT_PATH" "$PROFILE" 2>/dev/null; then
                echo '[[ $- == *i* ]] && cd ~/wireguard-script-manager && bash ./config_wg.sh' >> "$PROFILE"
                chown "$NEWUSER:$NEWUSER" "$PROFILE"
                echo -e "\e[1;32mLe script sera lancé automatiquement à la connexion de $NEWUSER depuis $SCRIPT_PATH.\e[0m"
            fi
        fi
        # Préparation des dossiers Wireguard
        WG_DIR="${DOCKER_WG_DIR}"
        WG_CONFIG_DIR="$WG_DIR/config"
        if [[ ! -d "$WG_DIR" ]]; then
            mkdir -p "$WG_CONFIG_DIR"
            echo "Dossier $WG_CONFIG_DIR créé."
        elif [[ ! -d "$WG_CONFIG_DIR" ]]; then
            mkdir -p "$WG_CONFIG_DIR"
            echo "Dossier $WG_CONFIG_DIR créé."
        fi
        chown -R "$NEWUSER":"$NEWUSER" "$WG_DIR"
        add_script_autostart_to_user "$NEWUSER"
        echo "Script installé et lancement auto configuré pour $NEWUSER."
        break
    done
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

# Lancement du menu principal uniquement si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main_menu
fi