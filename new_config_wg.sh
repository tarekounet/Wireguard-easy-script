#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#############################################
# Protection contre le sourcing infini
#############################################
if [[ -z "$CONFIG_WG_SOURCED" ]]; then
    export CONFIG_WG_SOURCED=1
else
    return 0 2>/dev/null || exit 0
fi

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
#############################################
# Définition des chemins principaux
#############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="$SCRIPT_DIR/config/wg-easy.conf"
USER_HOME="$HOME/wireguard-easy-script"
USER_FLAG="$USER_HOME/.structure_done"
SCRIPT_BASE_VERSION_INIT="1.8.0"  # Version initiale par défaut
#############################################
# Lecture de la version depuis version.txt
#############################################
SCRIPT_BASE_VERSION=""
if [[ -f "$SCRIPT_DIR/version.txt" ]]; then
    SCRIPT_BASE_VERSION=$(head -n1 "$SCRIPT_DIR/version.txt" | tr -d '\r\n')
else
    # Valeur de secours si version.txt absent
    SCRIPT_BASE_VERSION="$SCRIPT_BASE_VERSION_INIT"
fi

#############################################
# Variables GitHub (à adapter)
#############################################
GITHUB_USER="TON_GITHUB_USER"
GITHUB_REPO="Wireguard-easy-script"

#############################################
# Sourcing des modules
#############################################
source "$SCRIPT_DIR/lib/conf.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/docker.sh"
source "$SCRIPT_DIR/lib/menu.sh"

#############################################
# Fonction de mise à jour basée sur version.txt
#############################################
update_if_new_version() {
    local branch remote_version local_version
    branch=$(grep -E '^SCRIPT_CHANNEL=' "$CONF_FILE" | cut -d'"' -f2)
    [[ -z "$branch" ]] && branch="main"

    local_version="$SCRIPT_BASE_VERSION"
    remote_version=$(curl -fsSL "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$branch/version.txt" | head -n1 | tr -d '\r\n')

    if [[ -n "$remote_version" && "$local_version" != "$remote_version" ]]; then
        echo -e "\e[33mNouvelle version disponible ($remote_version), mise à jour en cours...\e[0m"
        TMP_UPDATE_DIR="/tmp/wg-easy-update"
        rm -rf "$TMP_UPDATE_DIR"
        mkdir -p "$TMP_UPDATE_DIR"
        ZIP_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/archive/refs/heads/${branch}.zip"
        curl -fsSL "$ZIP_URL" -o "$TMP_UPDATE_DIR/update.zip"
        unzip -q "$TMP_UPDATE_DIR/update.zip" -d "$TMP_UPDATE_DIR"
        EXTRACTED_DIR=$(find "$TMP_UPDATE_DIR" -maxdepth 1 -type d -name "${GITHUB_REPO}-*")
        if [[ -d "$EXTRACTED_DIR" ]]; then
            cp -r "$EXTRACTED_DIR"/* "$SCRIPT_DIR/"
            chmod -R +x "$SCRIPT_DIR/lib/"*.sh 2>/dev/null
            echo -e "\e[32mMise à jour appliquée avec succès !\e[0m"
            rm -rf "$TMP_UPDATE_DIR"
            echo -e "\nAppuyez sur une touche pour relancer le script..."
            read -n 1 -s
            exec "$0"
        else
            echo -e "\e[31mErreur lors de l'extraction de la mise à jour.\e[0m"
            rm -rf "$TMP_UPDATE_DIR"
        fi
    else
        echo -e "\e[32mAucune mise à jour disponible (version $local_version).\e[0m"
    fi
}

#############################################
# Fonctions réservées à root
#############################################
install_prerequisites() {
    echo "Installation des prérequis (curl, docker, etc.)..."
    apt-get update
    apt-get install -y curl vim btop sudo openssl
}

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

create_new_user() {
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
        USER_HOME="/home/$NEWUSER/script"
        mkdir -p "$USER_HOME"
        chmod u+rwX "$USER_HOME"
        # Récupérer le script principal depuis GitHub et le copier dans le dossier utilisateur
        read -p "Souhaitez-vous télécharger la dernière version du script depuis GitHub pour cet utilisateur ? (o/N) : " DL_SCRIPT
        if [[ "$DL_SCRIPT" =~ ^[oO]$ ]]; then
            BRANCH="main"  # ou récupère la branche depuis la conf si besoin
            SCRIPT_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/config_wg.sh"
            curl -fsSL "$SCRIPT_URL" -o "$USER_HOME/config_wg.sh"
            chmod +x "$USER_HOME/config_wg.sh"
            chown "$NEWUSER:$NEWUSER" "$USER_HOME/config_wg.sh"
        else
            cp "$0" "$USER_HOME/"
            chown "$NEWUSER:$NEWUSER" "$USER_HOME/$(basename "$0")"
        fi
        # Télécharger tout le projet depuis GitHub et le copier dans le dossier script de l'utilisateur
        read -p "Souhaitez-vous télécharger et copier tout le projet GitHub dans script de l'utilisateur ? (o/N) : " DL_ALL
        if [[ "$DL_ALL" =~ ^[oO]$ ]]; then
            BRANCH="main"  # ou récupère la branche depuis la conf si besoin
            TMP_UPDATE_DIR="/tmp/wg-easy-usercopy"
            rm -rf "$TMP_UPDATE_DIR"
            mkdir -p "$TMP_UPDATE_DIR"
            ZIP_URL="https://github.com/$GITHUB_USER/$GITHUB_REPO/archive/refs/heads/${BRANCH}.zip"
            curl -fsSL "$ZIP_URL" -o "$TMP_UPDATE_DIR/update.zip"
            unzip -q "$TMP_UPDATE_DIR/update.zip" -d "$TMP_UPDATE_DIR"
            EXTRACTED_DIR=$(find "$TMP_UPDATE_DIR" -maxdepth 1 -type d -name "$GITHUB_REPO-*")
            USER_SCRIPT_DIR="$USER_HOME/script"
            mkdir -p "$USER_SCRIPT_DIR"
            if [[ -d "$EXTRACTED_DIR" ]]; then
                cp -r "$EXTRACTED_DIR"/* "$USER_SCRIPT_DIR/"
                chmod -R +x "$USER_SCRIPT_DIR/lib"/*.sh 2>/dev/null
                chown -R "$NEWUSER:$NEWUSER" "$USER_SCRIPT_DIR"
                echo -e "\e[1;32mProjet complet copié dans $USER_SCRIPT_DIR.\e[0m"
            else
                echo -e "\e[1;31mErreur lors de l'extraction du projet GitHub.\e[0m"
            fi
            rm -rf "$TMP_UPDATE_DIR"
        else
            cp "$0" "$USER_HOME/"
            chown "$NEWUSER:$NEWUSER" "$USER_HOME/$(basename "$0")"
            USER_SCRIPT_DIR="$USER_HOME"
        fi
        # Proposer le lancement auto à la connexion
        read -p "Souhaitez-vous lancer ce script automatiquement à la connexion de $NEWUSER ? (o/N) : " AUTOSTART
        if [[ "$AUTOSTART" =~ ^[oO]$ ]]; then
            PROFILE="/home/$NEWUSER/.bash_profile"
            SCRIPT_PATH="$USER_HOME/script/config_wg.sh"
            if ! grep -q "$SCRIPT_PATH" "$PROFILE" 2>/dev/null; then
                echo "[[ \$- == *i* ]] && bash \"$SCRIPT_PATH\"" >> "$PROFILE"
                chown "$NEWUSER:$NEWUSER" "$PROFILE"
                echo -e "\e[1;32mLe script sera lancé automatiquement à la connexion de $NEWUSER depuis $SCRIPT_PATH.\e[0m"
            fi
        fi
        # Préparation des dossiers Wireguard
        WG_DIR="/mnt/wireguard"
        WG_CONFIG_DIR="$WG_DIR/config"
        if [[ ! -d "$WG_DIR" ]]; then
            mkdir -p "$WG_CONFIG_DIR"
            echo "Dossier $WG_CONFIG_DIR créé."
        elif [[ ! -d "$WG_CONFIG_DIR" ]]; then
            mkdir -p "$WG_CONFIG_DIR"
            echo "Dossier $WG_CONFIG_DIR créé."
        fi
        chown -R "$NEWUSER":"$NEWUSER" "$WG_DIR"
        chmod -R u+rwX "$WG_DIR"
        break
    done
}

edit_users() {
    echo "=== Gestion des utilisateurs Wireguard ==="
    echo "Utilisateurs existants dans le groupe docker :"
    getent group docker | awk -F: '{print $4}' | tr ',' '\n' | nl
    echo "Actions possibles :"
    echo "1) Modifier le mot de passe d'un utilisateur"
    echo "2) Supprimer un utilisateur"
    echo "3) Retour"
    read -p "Votre choix : " CHOICE
    case "$CHOICE" in
        1)
            read -p "Nom de l'utilisateur à modifier : " USERNAME
            if id "$USERNAME" &>/dev/null; then
                passwd "$USERNAME"
                echo "Mot de passe modifié pour $USERNAME."
            else
                echo "Utilisateur introuvable."
            fi
            ;;
        2)
            read -p "Nom de l'utilisateur à supprimer : " USERNAME
            if id "$USERNAME" &>/dev/null; then
                userdel -r "$USERNAME"
                echo "Utilisateur $USERNAME supprimé."
            else
                echo "Utilisateur introuvable."
            fi
            ;;
        3) return ;;
        *) echo "Choix invalide." ;;
    esac
}

list_real_users() {
    echo "Utilisateurs système (hors root et comptes de service) :"
    awk -F: '($3>=1000)&&($1!="nobody")&&($1!="root") {print $1}' /etc/passwd
}

add_script_autostart_to_user() {
    list_real_users
    read -p "Nom de l'utilisateur auquel ajouter le lancement auto : " TARGET_USER
    USER_HOME="/home/$TARGET_USER/wireguard-easy-script/script"
    SCRIPT_PATH="$USER_HOME/new_config_wg.sh"
    PROFILE="/home/$TARGET_USER/.bash_profile"
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo -e "\e[33mScript non trouvé dans $USER_HOME. Téléchargement depuis GitHub...\e[0m"
        BRANCH="main"  # ou récupère la branche depuis la conf si besoin
        mkdir -p "$USER_HOME"
        SCRIPT_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/new_config_wg.sh"
        curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        chown "$TARGET_USER:$TARGET_USER" "$SCRIPT_PATH"
    fi
    if ! grep -q "$SCRIPT_PATH" "$PROFILE" 2>/dev/null; then
        echo "[[ \$- == *i* ]] && bash \"$SCRIPT_PATH\"" >> "$PROFILE"
        chown "$TARGET_USER:$TARGET_USER" "$PROFILE"
        echo -e "\e[1;32mLe script sera lancé automatiquement à la connexion de $TARGET_USER depuis $SCRIPT_PATH.\e[0m"
    else
        echo -e "\e[1;33mLe script est déjà présent dans le .bash_profile de $TARGET_USER.\e[0m"
    fi
}

#############################################
# Bloc principal
#############################################
if [[ $EUID -eq 0 ]]; then
    while true; do
        echo "=== Menu administrateur (root) ==="
        echo "1) Créer un nouvel utilisateur"
        echo "2) Modifier le mot de passe d'un utilisateur"
        echo "3) Supprimer un utilisateur"
        echo "4) Lister les utilisateurs système"
        echo "5) Ajouter le lancement auto du script à un utilisateur existant"
        echo "6) Quitter"
        read -p "Votre choix : " CHOICE
        case "$CHOICE" in
            1)
                create_new_user
                ;;
            2)
                list_real_users
                read -p "Nom de l'utilisateur à modifier : " USERNAME
                if id "$USERNAME" &>/dev/null; then
                    passwd "$USERNAME"
                    echo "Mot de passe modifié pour $USERNAME."
                else
                    echo "Utilisateur introuvable."
                fi
                ;;
            3)
                list_real_users
                read -p "Nom de l'utilisateur à supprimer : " USERNAME
                if id "$USERNAME" &>/dev/null; then
                    userdel -r "$USERNAME"
                    echo "Utilisateur $USERNAME supprimé."
                else
                    echo "Utilisateur introuvable."
                fi
                ;;
            4)
                list_real_users
                ;;
            5)
                add_script_autostart_to_user
                ;;
            6)
                exit 0
                ;;
            *)
                echo "Choix invalide."
                ;;
        esac
    done
fi

if [[ $EUID -ne 0 ]]; then
    main_menu
fi

#############################################
# Initialisation de la structure utilisateur
#############################################
if [[ ! -f "$USER_FLAG" ]]; then
    mkdir -p "$USER_HOME/lib" "$USER_HOME/config" "$USER_HOME/logs"
    touch "$USER_FLAG"
    echo "Structure initialisée dans $USER_HOME."
fi

#############################################
# Vérification et mise à jour si besoin
#############################################
update_if_new_version

#############################################
# Lancement du menu principal
#############################################
main_menu
