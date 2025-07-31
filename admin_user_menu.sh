#!/bin/bash
# Advanced Technical Administration Menu for Wireguard Environment
# Version: 2.0
# Author: Technical Administration Team

set -euo pipefail

# Color definitions for technical output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Technical constants
readonly SCRIPT_VERSION="2.0.0"
readonly MIN_PASSWORD_LENGTH=12
readonly DOCKER_COMPOSE_FILE="docker-compose.yml"
readonly WG_CONFIG_DIR="config"

# Logging function
log_action() {
    local level="$1"
    local message="$2"
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "/var/log/wireguard-admin.log" 2>/dev/null || echo -e "[$level] $message"
}

# Error handling
error_exit() {
    log_action "ERROR" "$1"
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

# Input validation
validate_username() {
    local username="$1"
    [[ "$username" =~ ^[a-z][a-z0-9_-]{1,31}$ ]] || return 1
}

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

# Check if user is a human user (not system/service account)
is_human_user() {
    local username="$1"
    local user_info=$(getent passwd "$username" 2>/dev/null)
    [[ -n "$user_info" ]] || return 1
    
    local uid=$(echo "$user_info" | cut -d: -f3)
    local shell=$(echo "$user_info" | cut -d: -f7)
    
    # Check UID >= 1000 and valid shell
    [[ "$uid" -ge 1000 ]] || return 1
    [[ "$shell" != "/usr/sbin/nologin" ]] || return 1
    [[ "$shell" != "/bin/false" ]] || return 1
    [[ "$shell" != "/sbin/nologin" ]] || return 1
    [[ -n "$shell" ]] || return 1
    
    # Exclude common system account patterns
    [[ "$username" != "nobody" ]] || return 1
    [[ "$username" != _* ]] || return 1
    [[ "$username" != systemd* ]] || return 1
    [[ "$username" != daemon* ]] || return 1
    [[ "$username" != "mail" ]] || return 1
    [[ "$username" != "ftp" ]] || return 1
    [[ "$username" != "www-data" ]] || return 1
    [[ "$username" != "backup" ]] || return 1
    [[ "$username" != "list" ]] || return 1
    [[ "$username" != "proxy" ]] || return 1
    [[ "$username" != "uucp" ]] || return 1
    [[ "$username" != "news" ]] || return 1
    [[ "$username" != "gnats" ]] || return 1
    [[ "$username" != "sshd" ]] || return 1
    [[ "$username" != "messagebus" ]] || return 1
    [[ "$username" != "uuidd" ]] || return 1
    
    return 0
}

# Technical administration menu
technical_admin_menu() {
    while true; do
        clear
        echo -e "${CYAN}==== MENU ADMINISTRATION v${SCRIPT_VERSION} ====${NC}"
        echo -e "${WHITE}1) Gestion des utilisateurs"
        echo -e "2) Mise à jour du système"
        echo -e "3) Redémarrage/Arrêt"
        echo -e "0) Quitter${NC}"
        echo -ne "${WHITE}Choix : ${NC}"
        read -r CHOICE
        case $CHOICE in
            1) user_management_menu ;;
            2) system_update_menu ;;
            3) power_management_menu ;;
            0)
                log_action "INFO" "Fin session admin"
                echo -e "${GREEN}Session terminée.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Choix invalide.${NC}"
                read -n1 -r -p "Appuyez sur une touche..." _
                ;;
        esac
    done
}

# User Management & Security Module
user_management_menu() {
    while true; do
        clear
        echo -e "${PURPLE}==== GESTION UTILISATEURS ====${NC}"
        echo -e "${WHITE}1) Créer utilisateur"
        echo -e "2) Modifier utilisateur"
        echo -e "3) Supprimer utilisateur"
        echo -e "0) Retour${NC}"
        echo -ne "${WHITE}Choix : ${NC}"
        read -r SUB_CHOICE
        case $SUB_CHOICE in
            1) create_technical_user ;;
            2) modify_user_menu ;;
            3) remove_user_secure ;;
            0) break ;;
            *) echo -e "${RED}Choix invalide.${NC}"; read -n1 -r -p "Appuyez sur une touche..." _ ;;
        esac
    done
}

# Enhanced user creation with technical validation
create_technical_user() {
    clear
    echo -e "${YELLOW}═══ CRÉATION D'UN UTILISATEUR TECHNIQUE ═══${NC}"
    while true; do
        echo -ne "${WHITE}Nom d'utilisateur (minuscules, chiffres, 2-32 caractères) : ${NC}"
        read -r NEWUSER
        if ! validate_username "$NEWUSER"; then
            echo -e "${RED}Format du nom invalide. Utilisez uniquement des lettres minuscules, chiffres, tiret ou underscore.${NC}"
            continue
        elif id "$NEWUSER" &>/dev/null; then
            echo -e "${RED}L'utilisateur '$NEWUSER' existe déjà.${NC}"
            continue
        elif [[ "$NEWUSER" =~ ^(root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|ftp|nobody|systemd.*|_.*|sshd|messagebus|uuidd)$ ]]; then
            echo -e "${RED}Nom d'utilisateur réservé au système. Choisissez un autre nom.${NC}"
            continue
        fi
        break
    done
    while true; do
        echo -ne "${WHITE}Mot de passe (${MIN_PASSWORD_LENGTH} caractères minimum, complexe) : ${NC}"
        read -rs NEWPASS
        echo
        echo -ne "${WHITE}Confirmez le mot de passe : ${NC}"
        read -rs NEWPASS2
        echo
        if [[ ${#NEWPASS} -lt $MIN_PASSWORD_LENGTH ]]; then
            echo -e "${RED}Mot de passe trop court (minimum ${MIN_PASSWORD_LENGTH} caractères).${NC}"
        elif [[ "$NEWPASS" != "$NEWPASS2" ]]; then
            echo -e "${RED}Les mots de passe ne correspondent pas.${NC}"
        else
            break
        fi
    done
    log_action "INFO" "Création de l'utilisateur : $NEWUSER"
    useradd -m -s /bin/bash -G docker,sudo "$NEWUSER" || error_exit "Échec de la création de l'utilisateur"
    echo "$NEWUSER:$NEWPASS" | chpasswd || error_exit "Échec de la définition du mot de passe"
    USER_HOME="/home/$NEWUSER"
    SCRIPT_DIR="$USER_HOME/wireguard-script-manager"
    mkdir -p "$SCRIPT_DIR"
    chown -R "$NEWUSER:$NEWUSER" "$SCRIPT_DIR"
    chmod 750 "$SCRIPT_DIR"
    echo -e "${GREEN}✓ Utilisateur '$NEWUSER' créé avec succès${NC}"
    echo -e "${GREEN}✓ Ajouté aux groupes docker et sudo${NC}"
    echo -e "${GREEN}✓ Dossier script : $SCRIPT_DIR${NC}"
    echo -ne "${YELLOW}Configurer le lancement automatique du script ? [o/N] : ${NC}"
    read -r AUTOSTART
    if [[ "$AUTOSTART" =~ ^[oOyY]$ ]]; then
        configure_user_autostart "$NEWUSER" "$SCRIPT_DIR"
    fi
    log_action "INFO" "Utilisateur $NEWUSER créé avec succès"
    read -n1 -r -p "Appuyez sur une touche pour continuer..." _
}
# User modification menu
modify_user_menu() {
    clear
    echo -e "${YELLOW}═══ MODIFICATION D'UN UTILISATEUR ═══${NC}"
    # Filter only real human users: UID >= 1000, valid shell, exclude system accounts
    mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody")&&($7!="/usr/sbin/nologin")&&($7!="/bin/false")&&($7!="/sbin/nologin")&&($7!="")&&($1!~"^_")&&($1!~"^systemd")&&($1!~"^daemon")&&($1!~"^mail")&&($1!~"^ftp")&&($1!~"^www-data")&&($1!~"^backup")&&($1!~"^list")&&($1!~"^proxy")&&($1!~"^uucp")&&($1!~"^news")&&($1!~"^gnats"){print $1}' /etc/passwd)
    if [[ ${#USERS[@]} -eq 0 ]]; then
        echo -e "${RED}Aucun utilisateur humain trouvé.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    echo -e "${WHITE}Utilisateurs humains disponibles :${NC}"
    for i in "${!USERS[@]}"; do
        local user="${USERS[$i]}"
        local groups=$(groups "$user" 2>/dev/null | cut -d: -f2)
        local shell=$(getent passwd "$user" | cut -d: -f7)
        local home=$(getent passwd "$user" | cut -d: -f6)
        printf "${WHITE}%2d)${NC} %-15s ${CYAN}Shell:${NC} %-15s ${BLUE}Home:${NC} %-20s ${CYAN}Groupes:${NC} %s\n" $((i+1)) "$user" "$shell" "$home" "$groups"
    done
    echo -ne "${WHITE}Numéro de l'utilisateur [1-${#USERS[@]}] : ${NC}"
    read -r IDX
    IDX=$((IDX-1))
    if [[ $IDX -ge 0 && $IDX -lt ${#USERS[@]} ]]; then
        local SELECTED_USER="${USERS[$IDX]}"
        user_modification_options "$SELECTED_USER"
    else
        echo -e "${RED}Sélection invalide.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
    fi
}

user_modification_options() {
    local user="$1"
    while true; do
        clear
        echo -e "${YELLOW}═══ MODIFICATION DE L'UTILISATEUR : $user ═══${NC}"
        echo -e "${WHITE}[1]${NC} Changer le mot de passe"
        echo -e "${WHITE}[2]${NC} Modifier les groupes"
        echo -e "${WHITE}[3]${NC} Verrouiller/Déverrouiller le compte"
        echo -e "${WHITE}[4]${NC} Définir l'expiration du mot de passe"
        echo -e "${WHITE}[5]${NC} Voir les informations de l'utilisateur"
        echo -e "${WHITE}[0]${NC} Retour"
        echo -ne "${WHITE}Votre choix [0-5] : ${NC}"
        read -r SUBCHOICE
        case $SUBCHOICE in
            1)
                echo -e "${YELLOW}Changement du mot de passe pour $user...${NC}"
                passwd "$user"
                log_action "INFO" "Mot de passe modifié pour l'utilisateur : $user"
                ;;
            2)
                modify_user_groups "$user"
                ;;
            3)
                toggle_user_lock "$user"
                ;;
            4)
                set_password_expiry "$user"
                ;;
            5)
                show_user_info "$user"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Sélection invalide.${NC}"
                ;;
        esac
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
    done
}

# Remove user with secure cleanup
remove_user_secure() {
    clear
    echo -e "${RED}═══ SUPPRESSION SÉCURISÉE D'UN UTILISATEUR ═══${NC}"
    # Filter only real human users: UID >= 1000, valid shell, exclude system accounts
    mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody")&&($7!="/usr/sbin/nologin")&&($7!="/bin/false")&&($7!="/sbin/nologin")&&($7!="")&&($1!~"^_")&&($1!~"^systemd")&&($1!~"^daemon")&&($1!~"^mail")&&($1!~"^ftp")&&($1!~"^www-data")&&($1!~"^backup")&&($1!~"^list")&&($1!~"^proxy")&&($1!~"^uucp")&&($1!~"^news")&&($1!~"^gnats"){print $1}' /etc/passwd)
    if [[ ${#USERS[@]} -eq 0 ]]; then
        echo -e "${RED}Aucun utilisateur humain trouvé.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    echo -e "${WHITE}Utilisateurs humains pouvant être supprimés :${NC}"
    for i in "${!USERS[@]}"; do
        local user="${USERS[$i]}"
        local shell=$(getent passwd "$user" | cut -d: -f7)
        local home=$(getent passwd "$user" | cut -d: -f6)
        printf "${WHITE}%2d)${NC} %-15s ${CYAN}Shell:${NC} %-15s ${BLUE}Home:${NC} %s\n" $((i+1)) "$user" "$shell" "$home"
    done
    echo -ne "${WHITE}Numéro de l'utilisateur à supprimer [1-${#USERS[@]}] : ${NC}"
    read -r IDX
    IDX=$((IDX-1))
    if [[ $IDX -ge 0 && $IDX -lt ${#USERS[@]} ]]; then
        local TARGET_USER="${USERS[$IDX]}"
        echo -e "${RED}ATTENTION : Ceci supprimera définitivement l'utilisateur '$TARGET_USER' et toutes ses données !${NC}"
        echo -ne "${RED}Tapez 'SUPPRIMER $TARGET_USER' pour confirmer : ${NC}"
        read -r CONFIRMATION
        if [[ "$CONFIRMATION" == "SUPPRIMER $TARGET_USER" ]]; then
            pkill -u "$TARGET_USER" 2>/dev/null || true
            sleep 2
            pkill -9 -u "$TARGET_USER" 2>/dev/null || true
            deluser --remove-home "$TARGET_USER" 2>/dev/null || userdel -r "$TARGET_USER"
            log_action "WARNING" "Utilisateur $TARGET_USER supprimé"
            echo -e "${GREEN}✓ Utilisateur '$TARGET_USER' supprimé avec succès${NC}"
        else
            echo -e "${YELLOW}Opération annulée.${NC}"
        fi
    else
        echo -e "${RED}Sélection invalide.${NC}"
    fi
    read -n1 -r -p "Appuyez sur une touche pour continuer..." _
}

# System Update Management
system_update_menu() {
    while true; do
        clear
        echo -e "${YELLOW}═══ MISE À JOUR DU SYSTÈME ═══${NC}"
        echo -e "${WHITE}[1]${NC} Vérifier les mises à jour disponibles"
        echo -e "${WHITE}[2]${NC} Mettre à jour la liste des paquets"
        echo -e "${WHITE}[3]${NC} Mettre à jour tous les paquets"
        echo -e "${WHITE}[4]${NC} Mettre à jour les paquets de sécurité uniquement"
        echo -e "${WHITE}[5]${NC} Nettoyer le cache des paquets"
        echo -e "${WHITE}[6]${NC} Redémarrer si nécessaire après mise à jour"
        echo -e "${WHITE}[0]${NC} Retour"
        echo -ne "${WHITE}Votre choix [0-6] : ${NC}"
        read -r UPDATE_CHOICE
        
        case $UPDATE_CHOICE in
            1)
                check_available_updates
                ;;
            2)
                update_package_list
                ;;
            3)
                full_system_update
                ;;
            4)
                security_updates_only
                ;;
            5)
                clean_package_cache
                ;;
            6)
                check_reboot_required
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Sélection invalide.${NC}"
                ;;
        esac
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
    done
}

# Power Management Menu
power_management_menu() {
    while true; do
        clear
        echo -e "${RED}═══ GESTION DE L'ALIMENTATION ═══${NC}"
        echo -e "${WHITE}[1]${NC} Redémarrer le système"
        echo -e "${WHITE}[2]${NC} Arrêter le système"
        echo -e "${WHITE}[3]${NC} Programmer un redémarrage"
        echo -e "${WHITE}[4]${NC} Programmer un arrêt"
        echo -e "${WHITE}[5]${NC} Annuler une programmation"
        echo -e "${WHITE}[6]${NC} Voir l'état des tâches programmées"
        echo -e "${WHITE}[0]${NC} Retour"
        echo -ne "${WHITE}Votre choix [0-6] : ${NC}"
        read -r POWER_CHOICE
        
        case $POWER_CHOICE in
            1)
                immediate_reboot
                ;;
            2)
                immediate_shutdown
                ;;
            3)
                schedule_reboot
                ;;
            4)
                schedule_shutdown
                ;;
            5)
                cancel_scheduled_task
                ;;
            6)
                show_scheduled_tasks
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Sélection invalide.${NC}"
                ;;
        esac
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
    done
}
# ═══════════════════════════════════════════════════════════════
# SYSTEM UPDATE FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Check available updates
check_available_updates() {
    clear
    echo -e "${YELLOW}═══ VÉRIFICATION DES MISES À JOUR ═══${NC}"
    
    if command -v apt &>/dev/null; then
        echo -e "${WHITE}Mise à jour de la liste des paquets...${NC}"
        apt update
        
        echo -e "\n${WHITE}Mises à jour disponibles :${NC}"
        local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
        updates=$((updates - 1))
        
        if [[ $updates -gt 0 ]]; then
            echo -e "${YELLOW}$updates mises à jour disponibles${NC}"
            apt list --upgradable
        else
            echo -e "${GREEN}Le système est à jour${NC}"
        fi
        
        echo -e "\n${WHITE}Mises à jour de sécurité :${NC}"
        local security_updates=$(apt list --upgradable 2>/dev/null | grep -i security | wc -l)
        if [[ $security_updates -gt 0 ]]; then
            echo -e "${RED}$security_updates mises à jour de sécurité disponibles${NC}"
        else
            echo -e "${GREEN}Aucune mise à jour de sécurité en attente${NC}"
        fi
        
    elif command -v yum &>/dev/null; then
        echo -e "${WHITE}Vérification avec YUM...${NC}"
        yum check-update
    elif command -v dnf &>/dev/null; then
        echo -e "${WHITE}Vérification avec DNF...${NC}"
        dnf check-update
    else
        echo -e "${RED}Gestionnaire de paquets non reconnu${NC}"
    fi
    
    log_action "INFO" "Vérification des mises à jour effectuée"
}

# Update package list
update_package_list() {
    clear
    echo -e "${YELLOW}═══ MISE À JOUR DE LA LISTE DES PAQUETS ═══${NC}"
    
    if command -v apt &>/dev/null; then
        echo -e "${WHITE}Mise à jour de la liste des paquets APT...${NC}"
        apt update
        echo -e "${GREEN}✓ Liste des paquets mise à jour${NC}"
    elif command -v yum &>/dev/null; then
        echo -e "${WHITE}Nettoyage du cache YUM...${NC}"
        yum clean all
        echo -e "${GREEN}✓ Cache YUM nettoyé${NC}"
    elif command -v dnf &>/dev/null; then
        echo -e "${WHITE}Nettoyage du cache DNF...${NC}"
        dnf clean all
        echo -e "${GREEN}✓ Cache DNF nettoyé${NC}"
    fi
    
    log_action "INFO" "Liste des paquets mise à jour"
}

# Full system update
full_system_update() {
    clear
    echo -e "${YELLOW}═══ MISE À JOUR COMPLÈTE DU SYSTÈME ═══${NC}"
    echo -e "${RED}ATTENTION : Cette opération peut prendre du temps et redémarrer certains services.${NC}"
    echo -ne "${WHITE}Continuer ? [o/N] : ${NC}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
        if command -v apt &>/dev/null; then
            echo -e "${WHITE}Mise à jour APT en cours...${NC}"
            apt update && apt upgrade -y
            echo -e "${GREEN}✓ Mise à jour APT terminée${NC}"
        elif command -v yum &>/dev/null; then
            echo -e "${WHITE}Mise à jour YUM en cours...${NC}"
            yum update -y
            echo -e "${GREEN}✓ Mise à jour YUM terminée${NC}"
        elif command -v dnf &>/dev/null; then
            echo -e "${WHITE}Mise à jour DNF en cours...${NC}"
            dnf update -y
            echo -e "${GREEN}✓ Mise à jour DNF terminée${NC}"
        fi
        
        log_action "INFO" "Mise à jour complète du système effectuée"
        
        # Check if reboot is required
        if [[ -f /var/run/reboot-required ]]; then
            echo -e "${YELLOW}Un redémarrage est requis pour finaliser les mises à jour.${NC}"
            echo -ne "${WHITE}Redémarrer maintenant ? [o/N] : ${NC}"
            read -r REBOOT_NOW
            if [[ "$REBOOT_NOW" =~ ^[oOyY]$ ]]; then
                echo -e "${RED}Redémarrage en cours...${NC}"
                log_action "INFO" "Redémarrage après mise à jour"
                shutdown -r now
            fi
        fi
    else
        echo -e "${YELLOW}Mise à jour annulée.${NC}"
    fi
}

# Security updates only
security_updates_only() {
    clear
    echo -e "${YELLOW}═══ MISES À JOUR DE SÉCURITÉ UNIQUEMENT ═══${NC}"
    
    if command -v apt &>/dev/null; then
        echo -e "${WHITE}Installation des mises à jour de sécurité...${NC}"
        apt update
        apt upgrade -y --security
        echo -e "${GREEN}✓ Mises à jour de sécurité installées${NC}"
    elif command -v yum &>/dev/null; then
        echo -e "${WHITE}Installation des mises à jour de sécurité YUM...${NC}"
        yum update --security -y
        echo -e "${GREEN}✓ Mises à jour de sécurité YUM installées${NC}"
    elif command -v dnf &>/dev/null; then
        echo -e "${WHITE}Installation des mises à jour de sécurité DNF...${NC}"
        dnf update --security -y
        echo -e "${GREEN}✓ Mises à jour de sécurité DNF installées${NC}"
    fi
    
    log_action "INFO" "Mises à jour de sécurité installées"
}

# Clean package cache
clean_package_cache() {
    clear
    echo -e "${YELLOW}═══ NETTOYAGE DU CACHE DES PAQUETS ═══${NC}"
    
    if command -v apt &>/dev/null; then
        echo -e "${WHITE}Nettoyage du cache APT...${NC}"
        apt autoclean
        apt autoremove -y
        echo -e "${GREEN}✓ Cache APT nettoyé${NC}"
    elif command -v yum &>/dev/null; then
        echo -e "${WHITE}Nettoyage du cache YUM...${NC}"
        yum clean all
        echo -e "${GREEN}✓ Cache YUM nettoyé${NC}"
    elif command -v dnf &>/dev/null; then
        echo -e "${WHITE}Nettoyage du cache DNF...${NC}"
        dnf clean all
        echo -e "${GREEN}✓ Cache DNF nettoyé${NC}"
    fi
    
    log_action "INFO" "Cache des paquets nettoyé"
}

# Check if reboot is required
check_reboot_required() {
    clear
    echo -e "${YELLOW}═══ VÉRIFICATION REDÉMARRAGE REQUIS ═══${NC}"
    
    if [[ -f /var/run/reboot-required ]]; then
        echo -e "${RED}Un redémarrage est requis.${NC}"
        if [[ -f /var/run/reboot-required.pkgs ]]; then
            echo -e "${WHITE}Paquets nécessitant un redémarrage :${NC}"
            cat /var/run/reboot-required.pkgs
        fi
        echo -ne "${WHITE}Redémarrer maintenant ? [o/N] : ${NC}"
        read -r REBOOT_NOW
        if [[ "$REBOOT_NOW" =~ ^[oOyY]$ ]]; then
            echo -e "${RED}Redémarrage en cours...${NC}"
            log_action "INFO" "Redémarrage manuel après vérification"
            shutdown -r now
        fi
    else
        echo -e "${GREEN}Aucun redémarrage requis.${NC}"
    fi
}

# ═══════════════════════════════════════════════════════════════
# POWER MANAGEMENT FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Immediate reboot
immediate_reboot() {
    clear
    echo -e "${RED}═══ REDÉMARRAGE IMMÉDIAT ═══${NC}"
    echo -e "${RED}ATTENTION : Le système va redémarrer immédiatement !${NC}"
    echo -ne "${WHITE}Confirmer le redémarrage ? [o/N] : ${NC}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
        log_action "WARNING" "Redémarrage immédiat demandé par l'administrateur"
        echo -e "${RED}Redémarrage en cours...${NC}"
        shutdown -r now
    else
        echo -e "${YELLOW}Redémarrage annulé.${NC}"
    fi
}

# Immediate shutdown
immediate_shutdown() {
    clear
    echo -e "${RED}═══ ARRÊT IMMÉDIAT ═══${NC}"
    echo -e "${RED}ATTENTION : Le système va s'arrêter immédiatement !${NC}"
    echo -ne "${WHITE}Confirmer l'arrêt ? [o/N] : ${NC}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
        log_action "WARNING" "Arrêt immédiat demandé par l'administrateur"
        echo -e "${RED}Arrêt en cours...${NC}"
        shutdown -h now
    else
        echo -e "${YELLOW}Arrêt annulé.${NC}"
    fi
}

# Schedule reboot
schedule_reboot() {
    clear
    echo -e "${YELLOW}═══ PROGRAMMER UN REDÉMARRAGE ═══${NC}"
    echo -e "${WHITE}Formats acceptés :${NC}"
    echo -e "  - +X (dans X minutes)"
    echo -e "  - HH:MM (heure spécifique)"
    echo -e "  - now (immédiatement)"
    echo -ne "${WHITE}Quand redémarrer ? : ${NC}"
    read -r WHEN
    
    if [[ -n "$WHEN" ]]; then
        echo -ne "${WHITE}Message optionnel : ${NC}"
        read -r MESSAGE
        
        if [[ -n "$MESSAGE" ]]; then
            shutdown -r "$WHEN" "$MESSAGE"
        else
            shutdown -r "$WHEN"
        fi
        
        echo -e "${GREEN}✓ Redémarrage programmé${NC}"
        log_action "INFO" "Redémarrage programmé pour : $WHEN"
    else
        echo -e "${RED}Heure invalide.${NC}"
    fi
}

# Schedule shutdown
schedule_shutdown() {
    clear
    echo -e "${YELLOW}═══ PROGRAMMER UN ARRÊT ═══${NC}"
    echo -e "${WHITE}Formats acceptés :${NC}"
    echo -e "  - +X (dans X minutes)"
    echo -e "  - HH:MM (heure spécifique)"
    echo -e "  - now (immédiatement)"
    echo -ne "${WHITE}Quand arrêter ? : ${NC}"
    read -r WHEN
    
    if [[ -n "$WHEN" ]]; then
        echo -ne "${WHITE}Message optionnel : ${NC}"
        read -r MESSAGE
        
        if [[ -n "$MESSAGE" ]]; then
            shutdown -h "$WHEN" "$MESSAGE"
        else
            shutdown -h "$WHEN"
        fi
        
        echo -e "${GREEN}✓ Arrêt programmé${NC}"
        log_action "INFO" "Arrêt programmé pour : $WHEN"
    else
        echo -e "${RED}Heure invalide.${NC}"
    fi
}

# Cancel scheduled task
cancel_scheduled_task() {
    clear
    echo -e "${YELLOW}═══ ANNULER UNE PROGRAMMATION ═══${NC}"
    
    if shutdown -c 2>/dev/null; then
        echo -e "${GREEN}✓ Tâche programmée annulée${NC}"
        log_action "INFO" "Tâche programmée annulée"
    else
        echo -e "${RED}Aucune tâche programmée ou erreur lors de l'annulation${NC}"
    fi
}

# Show scheduled tasks
show_scheduled_tasks() {
    clear
    echo -e "${YELLOW}═══ TÂCHES PROGRAMMÉES ═══${NC}"
    
    echo -e "${WHITE}Tâches shutdown/reboot :${NC}"
    if pgrep shutdown &>/dev/null; then
        echo -e "${YELLOW}Une tâche shutdown est active${NC}"
        ps aux | grep shutdown | grep -v grep
    else
        echo -e "${GREEN}Aucune tâche shutdown programmée${NC}"
    fi
    
    echo -e "\n${WHITE}Tâches cron système :${NC}"
    crontab -l 2>/dev/null | head -10 || echo "Aucune tâche cron utilisateur"
    
    echo -e "\n${WHITE}Timers systemd actifs :${NC}"
    systemctl list-timers --no-pager | head -10
}

# ═══════════════════════════════════════════════════════════════
# TECHNICAL FUNCTION IMPLEMENTATIONS
# ═══════════════════════════════════════════════════════════════

# Configure user autostart script
configure_user_autostart() {
    local user="$1"
    local script_dir="$2"
    local profile="/home/$user/.bash_profile"
    local script_path="$script_dir/config_wg.sh"
    local github_url="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh"
    
    echo -e "${YELLOW}Configuration du demarrage automatique pour $user...${NC}"
    
    # Télécharger le script config_wg.sh depuis GitHub
    echo -e "${WHITE}Telechargement du script config_wg.sh depuis GitHub...${NC}"
    if command -v curl &>/dev/null; then
        if curl -fsSL "$github_url" -o "$script_path"; then
            echo -e "${GREEN}✓ Script telecharge avec succes${NC}"
        else
            echo -e "${RED}✗ Echec du telechargement avec curl${NC}"
            # Essayer avec wget si curl echoue
            if command -v wget &>/dev/null; then
                echo -e "${WHITE}Tentative avec wget...${NC}"
                if wget -q "$github_url" -O "$script_path"; then
                    echo -e "${GREEN}✓ Script telecharge avec wget${NC}"
                else
                    echo -e "${RED}✗ Echec du telechargement avec wget${NC}"
                    echo -e "${YELLOW}Creation d'un script de demarrage basique...${NC}"
                    create_basic_startup_script "$script_path"
                fi
            else
                echo -e "${YELLOW}Creation d'un script de demarrage basique...${NC}"
                create_basic_startup_script "$script_path"
            fi
        fi
    elif command -v wget &>/dev/null; then
        if wget -q "$github_url" -O "$script_path"; then
            echo -e "${GREEN}✓ Script telecharge avec wget${NC}"
        else
            echo -e "${RED}✗ Echec du telechargement avec wget${NC}"
            echo -e "${YELLOW}Creation d'un script de demarrage basique...${NC}"
            create_basic_startup_script "$script_path"
        fi
    else
        echo -e "${RED}Ni curl ni wget disponible${NC}"
        echo -e "${YELLOW}Creation d'un script de demarrage basique...${NC}"
        create_basic_startup_script "$script_path"
    fi
    
    # Rendre le script executable
    chmod +x "$script_path"
    chown "$user:$user" "$script_path"
    
    # Configurer le demarrage automatique dans .bash_profile
    if ! grep -q "$script_path" "$profile" 2>/dev/null; then
        echo '# Auto-start Wireguard management script' >> "$profile"
        echo '[[ $- == *i* ]] && cd ~/wireguard-script-manager && bash ./config_wg.sh' >> "$profile"
        chown "$user:$user" "$profile"
        chmod 644 "$profile"
        echo -e "${GREEN}✓ Demarrage automatique configure pour $user${NC}"
        log_action "INFO" "Auto-start configured for user: $user with GitHub script"
    else
        echo -e "${YELLOW}Demarrage automatique deja configure pour $user${NC}"
    fi
}

# Create a basic startup script if download fails
create_basic_startup_script() {
    local script_path="$1"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Basic Wireguard Management Script
# This is a fallback script when GitHub download fails

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${WHITE}   WIREGUARD MANAGEMENT SCRIPT (Basic)   ${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo
echo -e "${YELLOW}Ce script est une version basique de secours.${NC}"
echo -e "${WHITE}Pour obtenir la version complete, executez :${NC}"
echo
echo -e "${GREEN}wget https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh${NC}"
echo -e "${GREEN}chmod +x config_wg.sh${NC}"
echo -e "${GREEN}./config_wg.sh${NC}"
echo
echo -e "${WHITE}Ou utilisez curl :${NC}"
echo -e "${GREEN}curl -fsSL https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh -o config_wg.sh${NC}"
echo
echo -e "${YELLOW}Appuyez sur Entrée pour continuer ou Ctrl+C pour quitter${NC}"
read -r

# Basic menu
while true; do
    clear
    echo -e "${BLUE}═══ MENU BASIQUE WIREGUARD ═══${NC}"
    echo -e "${WHITE}1) Telecharger la version complete${NC}"
    echo -e "${WHITE}2) Verifier Docker${NC}"
    echo -e "${WHITE}3) Quitter${NC}"
    echo -ne "${WHITE}Choix : ${NC}"
    read -r choice
    
    case $choice in
        1)
            echo -e "${YELLOW}Telechargement de la version complete...${NC}"
            if command -v curl &>/dev/null; then
                curl -fsSL https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh -o config_wg_full.sh
                chmod +x config_wg_full.sh
                echo -e "${GREEN}✓ Telecharge dans config_wg_full.sh${NC}"
                echo -e "${WHITE}Executer maintenant ? [o/N] : ${NC}"
                read -r run_now
                if [[ "$run_now" =~ ^[oOyY]$ ]]; then
                    exec ./config_wg_full.sh
                fi
            elif command -v wget &>/dev/null; then
                wget https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh -O config_wg_full.sh
                chmod +x config_wg_full.sh
                echo -e "${GREEN}✓ Telecharge dans config_wg_full.sh${NC}"
                echo -e "${WHITE}Executer maintenant ? [o/N] : ${NC}"
                read -r run_now
                if [[ "$run_now" =~ ^[oOyY]$ ]]; then
                    exec ./config_wg_full.sh
                fi
            else
                echo -e "${RED}Ni curl ni wget disponible${NC}"
            fi
            read -n1 -r -p "Appuyez sur une touche..."
            ;;
        2)
            echo -e "${YELLOW}Verification de Docker...${NC}"
            if command -v docker &>/dev/null; then
                echo -e "${GREEN}✓ Docker est installe${NC}"
                docker --version
                if systemctl is-active docker &>/dev/null; then
                    echo -e "${GREEN}✓ Docker est actif${NC}"
                else
                    echo -e "${RED}✗ Docker n'est pas actif${NC}"
                fi
            else
                echo -e "${RED}✗ Docker n'est pas installe${NC}"
            fi
            read -n1 -r -p "Appuyez sur une touche..."
            ;;
        3)
            echo -e "${GREEN}Au revoir !${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Choix invalide${NC}"
            read -n1 -r -p "Appuyez sur une touche..."
            ;;
    esac
done
EOF

    echo -e "${YELLOW}✓ Script basique cree${NC}"
}

# User group modification
modify_user_groups() {
    local user="$1"
    
    # Vérifier que c'est un utilisateur humain
    if ! is_human_user "$user"; then
        echo -e "${RED}Erreur : '$user' n'est pas un utilisateur humain valide.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    
    clear
    echo -e "${YELLOW}═══ MODIFICATION DES GROUPES POUR : $user ═══${NC}"
    
    echo -e "${WHITE}Groupes actuels :${NC}"
    groups "$user"
    
    echo -e "\n${WHITE}Groupes disponibles :${NC}"
    echo "docker, sudo, www-data, users, plugdev, netdev"
    
    echo -e "\n${WHITE}Options :${NC}"
    echo "[1] Ajouter à un groupe"
    echo "[2] Retirer d'un groupe"
    echo "[0] Retour"
    
    echo -ne "${WHITE}Votre choix [0-2] : ${NC}"
    read -r GROUP_CHOICE
    
    case $GROUP_CHOICE in
        1)
            echo -ne "${WHITE}Nom du groupe à ajouter : ${NC}"
            read -r GROUP_NAME
            if getent group "$GROUP_NAME" &>/dev/null; then
                usermod -a -G "$GROUP_NAME" "$user"
                echo -e "${GREEN}✓ Utilisateur $user ajouté au groupe $GROUP_NAME${NC}"
                log_action "INFO" "Utilisateur $user ajouté au groupe $GROUP_NAME"
            else
                echo -e "${RED}Groupe $GROUP_NAME introuvable${NC}"
            fi
            ;;
        2)
            echo -ne "${WHITE}Nom du groupe à retirer : ${NC}"
            read -r GROUP_NAME
            if groups "$user" | grep -q "$GROUP_NAME"; then
                gpasswd -d "$user" "$GROUP_NAME"
                echo -e "${GREEN}✓ Utilisateur $user retiré du groupe $GROUP_NAME${NC}"
                log_action "INFO" "Utilisateur $user retiré du groupe $GROUP_NAME"
            else
                echo -e "${RED}L'utilisateur $user n'est pas dans le groupe $GROUP_NAME${NC}"
            fi
            ;;
    esac
}

# Toggle user lock status
toggle_user_lock() {
    local user="$1"
    
    # Vérifier que c'est un utilisateur humain
    if ! is_human_user "$user"; then
        echo -e "${RED}Erreur : '$user' n'est pas un utilisateur humain valide.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    
    clear
    echo -e "${YELLOW}═══ VERROUILLAGE/DEVERROUILLAGE : $user ═══${NC}"
    
    # Check current lock status
    if passwd -S "$user" | grep -q " L "; then
        echo -e "${RED}L'utilisateur $user est actuellement VERROUILLE${NC}"
        echo -ne "${WHITE}Deverrouiller le compte ? [o/N] : ${NC}"
        read -r UNLOCK
        if [[ "$UNLOCK" =~ ^[oOyY]$ ]]; then
            passwd -u "$user"
            echo -e "${GREEN}✓ Compte $user deverrouille${NC}"
            log_action "INFO" "Compte $user deverrouille"
        fi
    else
        echo -e "${GREEN}L'utilisateur $user est actuellement DEVERROUILLE${NC}"
        echo -ne "${WHITE}Verrouiller le compte ? [o/N] : ${NC}"
        read -r LOCK
        if [[ "$LOCK" =~ ^[oOyY]$ ]]; then
            passwd -l "$user"
            echo -e "${RED}✓ Compte $user verrouille${NC}"
            log_action "INFO" "Compte $user verrouille"
        fi
    fi
}

# Set password expiry
set_password_expiry() {
    local user="$1"
    
    # Vérifier que c'est un utilisateur humain
    if ! is_human_user "$user"; then
        echo -e "${RED}Erreur : '$user' n'est pas un utilisateur humain valide.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    
    clear
    echo -e "${YELLOW}═══ EXPIRATION DU MOT DE PASSE : $user ═══${NC}"
    
    echo -e "${WHITE}Informations actuelles :${NC}"
    chage -l "$user"
    
    echo -e "\n${WHITE}Options :${NC}"
    echo "[1] Définir une date d'expiration"
    echo "[2] Forcer le changement au prochain login"
    echo "[3] Supprimer l'expiration"
    echo "[0] Retour"
    
    echo -ne "${WHITE}Votre choix [0-3] : ${NC}"
    read -r EXPIRY_CHOICE
    
    case $EXPIRY_CHOICE in
        1)
            echo -ne "${WHITE}Date d'expiration (YYYY-MM-DD) : ${NC}"
            read -r EXPIRY_DATE
            if [[ "$EXPIRY_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                chage -E "$EXPIRY_DATE" "$user"
                echo -e "${GREEN}✓ Date d'expiration définie${NC}"
                log_action "INFO" "Date d'expiration définie pour $user : $EXPIRY_DATE"
            else
                echo -e "${RED}Format de date invalide${NC}"
            fi
            ;;
        2)
            chage -d 0 "$user"
            echo -e "${GREEN}✓ Changement de mot de passe force au prochain login${NC}"
            log_action "INFO" "Changement de mot de passe force pour $user"
            ;;
        3)
            chage -E -1 "$user"
            echo -e "${GREEN}✓ Expiration supprimee${NC}"
            log_action "INFO" "Expiration supprimee pour $user"
            ;;
    esac
}

# Show detailed user information
show_user_info() {
    local user="$1"
    
    # Vérifier que c'est un utilisateur humain
    if ! is_human_user "$user"; then
        echo -e "${RED}Erreur : '$user' n'est pas un utilisateur humain valide.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    
    clear
    echo -e "${YELLOW}═══ INFORMATIONS DETAILLEES : $user ═══${NC}"
    
    echo -e "${WHITE}Informations de base :${NC}"
    id "$user"
    
    echo -e "\n${WHITE}Informations du compte :${NC}"
    getent passwd "$user"
    
    echo -e "\n${WHITE}Statut du mot de passe :${NC}"
    passwd -S "$user"
    
    echo -e "\n${WHITE}Informations d'expiration :${NC}"
    chage -l "$user"
    
    echo -e "\n${WHITE}Dernières connexions :${NC}"
    last "$user" | head -5
    
    echo -e "\n${WHITE}Processus actifs :${NC}"
    ps -u "$user" --no-headers | wc -l | xargs echo "Nombre de processus :"
    
    if [[ -d "/home/$user" ]]; then
        echo -e "\n${WHITE}Utilisation disque du répertoire home :${NC}"
        du -sh "/home/$user" 2>/dev/null || echo "Impossible de calculer"
    fi
}
# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_action "INFO" "Technical administration session started"
    technical_admin_menu
else
    echo -e "${RED}ERREUR : Ce script doit être exécuté en tant que root.${NC}"
    echo "Veuillez exécuter : sudo $0"
    exit 1
fi
