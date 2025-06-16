#!/bin/bash
set -euo pipefail

# =====================
# Variables globales
# =====================
GITHUB_USER="tarekounet"
GITHUB_REPO="Wireguard-easy-script"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"

# =====================
# Fonctions admin (root)
# =====================
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
                cp -r "$EXTRACTED_DIR"/* "$USER_HOME/"
                chmod -R +x "$USER_HOME/lib"/*.sh 2>/dev/null
                chown -R "$NEWUSER:$NEWUSER" "$USER_HOME"
                echo -e "\e[1;32mProjet complet copié dans $USER_HOME.\e[0m"
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
        add_script_autostart_to_user "$NEWUSER"
        echo "Script installé et lancement auto configuré pour $NEWUSER."
        break
    done
}

admin_list_users() {
    echo -e "\nUtilisateurs système disponibles :"
    awk -F: '($3>=1000)&&($1!="nobody")&&($1!="root")&&($7!="/usr/sbin/nologin") {print "- "$1}' /etc/passwd
}

admin_modify_user() {
    echo -e "\n[Modification d'un utilisateur]"
    admin_list_users
    read -p "Nom de l'utilisateur à modifier : " MODUSER
    if ! id "$MODUSER" &>/dev/null; then
        echo "Utilisateur introuvable."
        return
    fi
    read -s -p "Nouveau mot de passe : " NEWPASS; echo
    echo "$MODUSER:$NEWPASS" | chpasswd
    echo "Mot de passe de $MODUSER modifié."
}

admin_delete_user() {
    echo -e "\n[Suppression d'un utilisateur]"
    admin_list_users
    read -p "Nom de l'utilisateur à supprimer : " DELUSER
    if ! id "$DELUSER" &>/dev/null; then
        echo "Utilisateur introuvable."
        return
    fi
    read -p "Confirmer la suppression de $DELUSER ? (o/N) : " CONFIRM
    if [[ "$CONFIRM" =~ ^[OoYy]$ ]]; then
        userdel -r "$DELUSER"
        echo "Utilisateur $DELUSER supprimé."
    else
        echo "Suppression annulée."
    fi
}

add_script_autostart_to_user() {
    TARGETUSER="$1"
    PROFILE="/home/$TARGETUSER/.bash_profile"
    SCRIPT_PATH="/home/$TARGETUSER/wireguard-script-manager/config_wg.sh"
    if ! grep -q "$SCRIPT_PATH" "$PROFILE" 2>/dev/null; then
        echo "[[ \$- == *i* ]] && bash \"$SCRIPT_PATH\"" >> "$PROFILE"
        chown "$TARGETUSER:$TARGETUSER" "$PROFILE"
    fi
}

admin_install_script_for_user() {
    echo -e "\n[Installation du script pour un utilisateur]"
    read -p "Nom de l'utilisateur : " TARGETUSER
    if ! id "$TARGETUSER" &>/dev/null; then
        echo "Utilisateur introuvable."
        return
    fi
    USER_HOME="/home/$TARGETUSER/wireguard-script-manager"
    mkdir -p "$USER_HOME"
    cp "$SCRIPT_DIR/config_wg.sh" "$USER_HOME/"
    chown -R "$TARGETUSER:$TARGETUSER" "$USER_HOME"
    add_script_autostart_to_user "$TARGETUSER"
    echo "Script installé et lancement auto configuré pour $TARGETUSER."
}

admin_menu() {
    while true; do
        echo -e "\n\e[1;33m===== MENU ADMINISTRATEUR =====\e[0m"
        echo "1) Créer un utilisateur"
        echo "2) Modifier le mot de passe d'un utilisateur"
        echo "3) Supprimer un utilisateur"
        echo "4) Installer le script sur la session d'un utilisateur"
        echo "Q) Quitter"
        read -p "> " CHOIX
        case "$CHOIX" in
            1) create_new_user ;;
            2) admin_modify_user ;;
            3) admin_delete_user ;;
            4) admin_install_script_for_user ;;
            [Qq]) exit 0 ;;
            *) echo "Choix invalide." ;;
        esac
    done
}

install_prerequisites() {
    echo "Installation des prérequis (curl, docker, etc.)..."
    apt-get update
    apt-get install -y curl vim btop sudo openssl unzip
}

install_docker_official() {
    install_prerequisites
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
}

# =====================
# Mode root : menu admin et installation
# =====================
if [ "$(id -u)" -eq 0 ]; then
    if ! command -v docker &>/dev/null || ! docker compose version &>/dev/null; then
        install_docker_official
    fi
    admin_menu
    exit 0
fi

# =====================
# ...suite du script utilisateur (modules, menu user, etc.)...
# =====================
#############################################
# Protection contre le sourcing infini
#############################################
if [[ -z "${CONFIG_WG_SOURCED:-}" ]]; then
    export CONFIG_WG_SOURCED=1
else
    return 0 2>/dev/null || exit 0
fi

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
# Bloc principal
#############################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
# Appel du menu adapté selon le privilège
if [ "$(id -u)" -eq 0 ]; then
    echo -e "\e[1;33m[MODE ADMINISTRATEUR]\e[0m"
    main_menu admin
else
    main_menu
fi
