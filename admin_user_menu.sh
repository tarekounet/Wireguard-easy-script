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

# Technical administration menu
technical_admin_menu() {
    while true; do
        clear
        echo -e "${CYAN}==== MENU ADMINISTRATION v${SCRIPT_VERSION} ====${NC}"
        echo -e "${WHITE}1) Utilisateurs"
        echo -e "2) Wireguard"
        echo -e "3) Docker"
        echo -e "4) Diagnostic"
        echo -e "0) Quitter${NC}"
        echo -ne "${WHITE}Choix : ${NC}"
        read -r CHOICE
        case $CHOICE in
            1) user_management_menu ;;
            2) wireguard_infrastructure_menu ;;
            3) docker_management_menu ;;
            4) system_diagnostics_menu ;;
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
    mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd)
    if [[ ${#USERS[@]} -eq 0 ]]; then
        echo -e "${RED}Aucun utilisateur standard trouvé.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    echo -e "${WHITE}Utilisateurs disponibles :${NC}"
    for i in "${!USERS[@]}"; do
        local user="${USERS[$i]}"
        local groups=$(groups "$user" 2>/dev/null | cut -d: -f2)
        printf "${WHITE}%2d)${NC} %-15s ${CYAN}Groupes:${NC} %s\n" $((i+1)) "$user" "$groups"
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
    mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd)
    if [[ ${#USERS[@]} -eq 0 ]]; then
        echo -e "${RED}Aucun utilisateur standard trouvé.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    echo -e "${WHITE}Utilisateurs pouvant être supprimés :${NC}"
    for i in "${!USERS[@]}"; do
        printf "${WHITE}%2d)${NC} %s\n" $((i+1)) "${USERS[$i]}"
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
# Wireguard Infrastructure Management
wireguard_infrastructure_menu() {
    while true; do
        clear
        echo -e "${BLUE}╔═════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${WHITE}         GESTION DE L'INFRASTRUCTURE WIREGUARD                ${BLUE}║${NC}"
        echo -e "${BLUE}╠═════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║ ${WHITE}[1]${NC} Scanner & gérer les instances Wireguard                ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${WHITE}[2]${NC} Réinitialiser la configuration Wireguard               ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${WHITE}[3]${NC} Sauvegarder/Restaurer les configurations               ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${WHITE}[4]${NC} Superviser les connexions actives                      ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${WHITE}[5]${NC} Mettre à jour les images Wireguard                     ${BLUE}║${NC}"
        echo -e "${BLUE}║ ${WHITE}[0]${NC} Retour au menu principal                               ${BLUE}║${NC}"
        echo -e "${BLUE}╚═════════════════════════════════════════════════════════════╝${NC}"
        echo -ne "${WHITE}Sélectionnez une opération [0-5] : ${NC}"
        read -r WG_CHOICE

        case $WG_CHOICE in
            1)
                scan_wireguard_instances
                ;;
            2)
                reset_wireguard_config
                ;;
            3)
                backup_restore_menu
                ;;
            4)
                monitor_wg_connections
                ;;
            5)
                update_wireguard_images
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection.${NC}"
                read -n1 -r -p "Press any key to continue..." _
                ;;
        esac
    done
}

# Enhanced Wireguard instance scanning
scan_wireguard_instances() {
    clear
    echo -e "${YELLOW}═══ WIREGUARD INSTANCE SCANNER ═══${NC}"
    
    echo -e "${CYAN}Scanning for Wireguard installations...${NC}"
    mapfile -t WG_DIRS < <(find /home -maxdepth 3 -type d -name "docker-wireguard" 2>/dev/null)
    mapfile -t WG_COMPOSE < <(find /home -maxdepth 3 -name "$DOCKER_COMPOSE_FILE" -path "*/docker-wireguard/*" 2>/dev/null)
    
    if [[ ${#WG_DIRS[@]} -eq 0 ]]; then
        echo -e "${RED}No Wireguard instances found.${NC}"
        read -n1 -r -p "Press any key to continue..." _
        return
    fi

    echo -e "${WHITE}Found ${#WG_DIRS[@]} Wireguard instance(s):${NC}"
    for i in "${!WG_DIRS[@]}"; do
        local dir="${WG_DIRS[$i]}"
        local status="STOPPED"
        local compose_file="$dir/$DOCKER_COMPOSE_FILE"
        
        if [[ -f "$compose_file" ]] && docker compose -f "$compose_file" ps | grep -q 'Up'; then
            status="${GREEN}RUNNING${NC}"
        else
            status="${RED}STOPPED${NC}"
        fi
        
        local config_files=$(find "$dir/$WG_CONFIG_DIR" -name "*.conf" 2>/dev/null | wc -l)
        printf "${WHITE}%2d)${NC} %-40s Status: %s Configs: %d\n" $((i+1)) "$dir" "$status" "$config_files"
    done
    
    echo -ne "${WHITE}Select instance to manage [1-${#WG_DIRS[@]}, 0 to cancel]: ${NC}"
    read -r IDX
    IDX=$((IDX-1))
    
    if [[ $IDX -ge 0 && $IDX -lt ${#WG_DIRS[@]} ]]; then
        manage_wireguard_instance "${WG_DIRS[$IDX]}"
    fi
}

# Manage individual Wireguard instance
manage_wireguard_instance() {
    local instance_dir="$1"
    local compose_file="$instance_dir/$DOCKER_COMPOSE_FILE"
    
    while true; do
        clear
        echo -e "${YELLOW}═══ MANAGING: $instance_dir ═══${NC}"
        
        # Check status
        local status="STOPPED"
        if [[ -f "$compose_file" ]] && docker compose -f "$compose_file" ps | grep -q 'Up'; then
            status="${GREEN}RUNNING${NC}"
        fi
        
        echo -e "${WHITE}Current Status:${NC} $status"
        echo -e "${WHITE}[1]${NC} Start/Stop Service"
        echo -e "${WHITE}[2]${NC} View Configuration Details"
        echo -e "${WHITE}[3]${NC} Reset Configuration Data"
        echo -e "${WHITE}[4]${NC} View Logs"
        echo -e "${WHITE}[5]${NC} Export Configuration Backup"
        echo -e "${WHITE}[0]${NC} Return"
        echo -ne "${WHITE}Select operation [0-5]: ${NC}"
        read -r INST_CHOICE
        
        case $INST_CHOICE in
            1)
                toggle_wireguard_service "$instance_dir"
                ;;
            2)
                view_wg_config_details "$instance_dir"
                ;;
            3)
                reset_instance_config "$instance_dir"
                ;;
            4)
                view_wg_logs "$instance_dir"
                ;;
            5)
                export_wg_backup "$instance_dir"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection.${NC}"
                ;;
        esac
        read -n1 -r -p "Press any key to continue..." _
    done
}
# System Diagnostics & Monitoring
system_diagnostics_menu() {
    while true; do
        clear
        echo -e "${GREEN}╔═════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║${WHITE}         DIAGNOSTICS & SUPERVISION SYSTÈME                     ${GREEN}║${NC}"
        echo -e "${GREEN}╠═════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║ ${WHITE}[1]${NC} Vue d'ensemble de la santé système                     ${GREEN}║${NC}"
        echo -e "${GREEN}║ ${WHITE}[2]${NC} Informations matérielles détaillées                    ${GREEN}║${NC}"
        echo -e "${GREEN}║ ${WHITE}[3]${NC} Statut des interfaces réseau                           ${GREEN}║${NC}"
        echo -e "${GREEN}║ ${WHITE}[4]${NC} Supervision des processus & services                   ${GREEN}║${NC}"
        echo -e "${GREEN}║ ${WHITE}[5]${NC} Analyse de l'utilisation disque & I/O                  ${GREEN}║${NC}"
        echo -e "${GREEN}║ ${WHITE}[6]${NC} Analyse sécurité & logs                               ${GREEN}║${NC}"
        echo -e "${GREEN}║ ${WHITE}[7]${NC} Benchmarks de performance                             ${GREEN}║${NC}"
        echo -e "${GREEN}║ ${WHITE}[0]${NC} Retour au menu principal                              ${GREEN}║${NC}"
        echo -e "${GREEN}╚═════════════════════════════════════════════════════════════╝${NC}"
        echo -ne "${WHITE}Sélectionnez une opération [0-7] : ${NC}"
        read -r DIAG_CHOICE

        case $DIAG_CHOICE in
            1)
                system_health_overview
                ;;
            2)
                detailed_hardware_info
                ;;
            3)
                network_interface_status
                ;;
            4)
                process_service_monitor
                ;;
            5)
                disk_usage_analysis
                ;;
            6)
                security_log_analysis
                ;;
            7)
                performance_benchmarks
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection.${NC}"
                read -n1 -r -p "Press any key to continue..." _
                ;;
        esac
    done
}

# Docker Environment Management
docker_management_menu() {
    while true; do
        clear
        echo -e "${PURPLE}╔═════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║${WHITE}         GESTION DE L'ENVIRONNEMENT DOCKER                     ${PURPLE}║${NC}"
        echo -e "${PURPLE}╠═════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${PURPLE}║ ${WHITE}[1]${NC} Statut & informations Docker                           ${PURPLE}║${NC}"
        echo -e "${PURPLE}║ ${WHITE}[2]${NC} Gestion des conteneurs                                 ${PURPLE}║${NC}"
        echo -e "${PURPLE}║ ${WHITE}[3]${NC} Gestion & mise à jour des images                       ${PURPLE}║${NC}"
        echo -e "${PURPLE}║ ${WHITE}[4]${NC} Gestion des volumes & réseaux                          ${PURPLE}║${NC}"
        echo -e "${PURPLE}║ ${WHITE}[5]${NC} Nettoyage système Docker                               ${PURPLE}║${NC}"
        echo -e "${PURPLE}║ ${WHITE}[6]${NC} Analyse de l'utilisation des ressources                ${PURPLE}║${NC}"
        echo -e "${PURPLE}║ ${WHITE}[0]${NC} Retour au menu principal                               ${PURPLE}║${NC}"
        echo -e "${PURPLE}╚═════════════════════════════════════════════════════════════╝${NC}"
        echo -ne "${WHITE}Sélectionnez une opération [0-6] : ${NC}"
        read -r DOCKER_CHOICE

        case $DOCKER_CHOICE in
            1)
                docker_status_info
                ;;
            2)
                container_management
                ;;
            3)
                image_management
                ;;
            4)
                volume_network_management
                ;;
            5)
                docker_system_cleanup
                ;;
            6)
                docker_resource_analysis
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection.${NC}"
                read -n1 -r -p "Press any key to continue..." _
                ;;
        esac
    done
}

# Security Audit & Hardening
security_audit_menu() {
    while true; do
        clear
        echo -e "${RED}╔═════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║${WHITE}           AUDIT & RENFORCEMENT DE LA SÉCURITÉ                ${RED}║${NC}"
        echo -e "${RED}╠═════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${RED}║ ${WHITE}[1]${NC} Audit de la sécurité système                           ${RED}║${NC}"
        echo -e "${RED}║ ${WHITE}[2]${NC} Analyse de la configuration SSH                        ${RED}║${NC}"
        echo -e "${RED}║ ${WHITE}[3]${NC} Statut & règles du pare-feu                            ${RED}║${NC}"
        echo -e "${RED}║ ${WHITE}[4]${NC} Tentatives de connexion échouées                       ${RED}║${NC}"
        echo -e "${RED}║ ${WHITE}[5]${NC} Audit des permissions de fichiers                      ${RED}║${NC}"
        echo -e "${RED}║ ${WHITE}[6]${NC} Appliquer un renforcement de la sécurité               ${RED}║${NC}"
        echo -e "${RED}║ ${WHITE}[0]${NC} Retour au menu principal                               ${RED}║${NC}"
        echo -e "${RED}╚═════════════════════════════════════════════════════════════╝${NC}"
        echo -ne "${WHITE}Sélectionnez une opération [0-6] : ${NC}"
        read -r SEC_CHOICE

        case $SEC_CHOICE in
            1)
                system_security_audit
                ;;
            2)
                ssh_config_analysis
                ;;
            3)
                firewall_status_rules
                ;;
            4)
                failed_login_analysis
                ;;
            5)
                file_permissions_audit
                ;;
            6)
                apply_security_hardening
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection.${NC}"
                read -n1 -r -p "Press any key to continue..." _
                ;;
        esac
    done
}

# Network Configuration & Services
network_configuration_menu() {
    while true; do
        clear
        echo -e "${CYAN}╔═════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${WHITE}         CONFIGURATION RÉSEAU & SERVICES                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠═════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║ ${WHITE}[1]${NC} Configuration des interfaces réseau                    ${CYAN}║${NC}"
        echo -e "${CYAN}║ ${WHITE}[2]${NC} Gestion du service SSH                                 ${CYAN}║${NC}"
        echo -e "${CYAN}║ ${WHITE}[3]${NC} Configuration du pare-feu                              ${CYAN}║${NC}"
        echo -e "${CYAN}║ ${WHITE}[4]${NC} Configuration DNS & routage                            ${CYAN}║${NC}"
        echo -e "${CYAN}║ ${WHITE}[5]${NC} Scanner de ports & outils réseau                       ${CYAN}║${NC}"
        echo -e "${CYAN}║ ${WHITE}[6]${NC} Nom d'hôte & heure système                             ${CYAN}║${NC}"
        echo -e "${CYAN}║ ${WHITE}[0]${NC} Retour au menu principal                               ${CYAN}║${NC}"
        echo -e "${CYAN}╚═════════════════════════════════════════════════════════════╝${NC}"
        echo -ne "${WHITE}Sélectionnez une opération [0-6] : ${NC}"
        read -r NET_CHOICE

        case $NET_CHOICE in
            1)
                network_interface_config
                ;;
            2)
                ssh_service_management
                ;;
            3)
                firewall_configuration
                ;;
            4)
                dns_routing_config
                ;;
            5)
                network_tools
                ;;
            6)
                hostname_time_config
                ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection.${NC}"
                read -n1 -r -p "Press any key to continue..." _
                ;;
        esac
    done
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
    
    if ! grep -q "$script_path" "$profile" 2>/dev/null; then
        echo '[[ $- == *i* ]] && cd ~/wireguard-script-manager && bash ./config_wg.sh' >> "$profile"
        chown "$user:$user" "$profile"
        chmod 644 "$profile"
        echo -e "${GREEN}✓ Auto-start configured for user $user${NC}"
        log_action "INFO" "Auto-start configured for user: $user"
    else
        echo -e "${YELLOW}Auto-start already configured for user $user${NC}"
    fi
}

# System Health Overview
system_health_overview() {
    clear
    echo -e "${YELLOW}═══ SYSTEM HEALTH OVERVIEW ═══${NC}"
    
    # System info
    echo -e "${WHITE}System Information:${NC}"
    echo "Hostname    : $(hostname)"
    echo "Uptime      : $(uptime -p)"
    echo "OS          : $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"')"
    echo "Kernel      : $(uname -r)"
    echo "Architecture: $(uname -m)"
    
    # CPU and Memory
    echo -e "\n${WHITE}Hardware Resources:${NC}"
    echo "CPU Model   : $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
    echo "CPU Cores   : $(nproc)"
    echo "CPU Usage   : $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo "Memory      : $(free -h | awk '/Mem:/ {printf "%s used / %s total (%.1f%%)", $3, $2, ($3/$2)*100}')"
    echo "Swap        : $(free -h | awk '/Swap:/ {printf "%s used / %s total", $3, $2}')"
    
    # Load averages
    echo -e "\n${WHITE}System Load:${NC}"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}' | xargs)"
    
    # Disk usage
    echo -e "\n${WHITE}Disk Usage (Critical filesystems):${NC}"
    df -h | awk 'NR==1 || $5+0 > 80 {print}'
    
    # Network
    echo -e "\n${WHITE}Network Status:${NC}"
    echo "Primary IP  : $(hostname -I | awk '{print $1}')"
    echo "DNS Servers : $(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')"
    
    # Services
    echo -e "\n${WHITE}Critical Services:${NC}"
    local services=("ssh" "docker" "systemd-resolved")
    for service in "${services[@]}"; do
        local status=$(systemctl is-active "$service" 2>/dev/null || echo "not-found")
        if [[ "$status" == "active" ]]; then
            echo "✓ $service: ${GREEN}$status${NC}"
        else
            echo "✗ $service: ${RED}$status${NC}"
        fi
    done
    
    read -n1 -r -p "Press any key to continue..." _
}

# Docker Status & Information
docker_status_info() {
    clear
    echo -e "${YELLOW}═══ DOCKER STATUS & INFORMATION ═══${NC}"
    
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Docker is not installed.${NC}"
        read -n1 -r -p "Press any key to continue..." _
        return
    fi
    
    echo -e "${WHITE}Docker Service Status:${NC}"
    systemctl status docker --no-pager --lines=5
    
    echo -e "\n${WHITE}Docker Version:${NC}"
    docker version --format "table {{.Server.Version}}\t{{.Server.APIVersion}}\t{{.Server.Os}}/{{.Server.Arch}}"
    
    echo -e "\n${WHITE}Docker System Information:${NC}"
    docker system df
    
    echo -e "\n${WHITE}Running Containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "\n${WHITE}All Containers:${NC}"
    docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}"
    
    echo -e "\n${WHITE}Docker Networks:${NC}"
    docker network ls
    
    echo -e "\n${WHITE}Docker Volumes:${NC}"
    docker volume ls
    
    read -n1 -r -p "Press any key to continue..." _
}

# SSH Service Management
ssh_service_management() {
    clear
    echo -e "${YELLOW}═══ SSH SERVICE MANAGEMENT ═══${NC}"
    
    local sshd_config="/etc/ssh/sshd_config"
    local current_port=$(grep '^Port ' "$sshd_config" | awk '{print $2}' | head -n1)
    current_port=${current_port:-22}
    
    echo -e "${WHITE}Current SSH Configuration:${NC}"
    echo "Port        : $current_port"
    echo "Status      : $(systemctl is-active ssh)"
    echo "Enabled     : $(systemctl is-enabled ssh)"
    
    echo -e "\n${WHITE}Active SSH Connections:${NC}"
    who | grep pts
    
    echo -e "\n${WHITE}Recent SSH Logins:${NC}"
    last | head -10
    
    echo -e "\n${WHITE}Options:${NC}"
    echo "[1] Change SSH Port"
    echo "[2] Restart SSH Service"
    echo "[3] View SSH Configuration"
    echo "[4] View SSH Logs"
    echo "[0] Return"
    
    echo -ne "${WHITE}Select option [0-4]: ${NC}"
    read -r SSH_CHOICE
    
    case $SSH_CHOICE in
        1)
            change_ssh_port
            ;;
        2)
            systemctl restart ssh
            echo -e "${GREEN}✓ SSH service restarted${NC}"
            ;;
        3)
            less "$sshd_config"
            ;;
        4)
            journalctl -u ssh --lines=50 --no-pager
            ;;
    esac
    
    read -n1 -r -p "Press any key to continue..." _
}

# Change SSH Port
change_ssh_port() {
    local sshd_config="/etc/ssh/sshd_config"
    local current_port=$(grep '^Port ' "$sshd_config" | awk '{print $2}' | head -n1)
    current_port=${current_port:-22}
    
    echo -e "${YELLOW}Current SSH port: $current_port${NC}"
    echo -ne "${WHITE}Enter new SSH port [1-65535]: ${NC}"
    read -r NEW_PORT
    
    if validate_port "$NEW_PORT"; then
        # Backup original config
        cp "$sshd_config" "$sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Update port
        if grep -q '^Port ' "$sshd_config"; then
            sed -i "s/^Port .*/Port $NEW_PORT/" "$sshd_config"
        else
            echo "Port $NEW_PORT" >> "$sshd_config"
        fi
        
        echo -e "${GREEN}✓ SSH port changed to $NEW_PORT${NC}"
        echo -e "${YELLOW}Restarting SSH service...${NC}"
        systemctl restart ssh
        
        if systemctl is-active ssh &>/dev/null; then
            echo -e "${GREEN}✓ SSH service restarted successfully${NC}"
            log_action "INFO" "SSH port changed to $NEW_PORT"
        else
            echo -e "${RED}✗ SSH service failed to restart${NC}"
            echo -e "${YELLOW}Restoring backup...${NC}"
            cp "$sshd_config.backup."* "$sshd_config"
            systemctl restart ssh
        fi
    else
        echo -e "${RED}Invalid port number.${NC}"
    fi
}

# System Security Audit
system_security_audit() {
    clear
    echo -e "${YELLOW}═══ SYSTEM SECURITY AUDIT ═══${NC}"
    
    echo -e "${WHITE}1. User Account Security:${NC}"
    echo "Users with UID 0 (root privileges):"
    awk -F: '$3 == 0 {print "  " $1}' /etc/passwd
    
    echo -e "\nUsers with empty passwords:"
    awk -F: '$2 == "" {print "  " $1}' /etc/shadow 2>/dev/null || echo "  (Permission denied - run as root)"
    
    echo -e "\n${WHITE}2. SSH Security:${NC}"
    local sshd_config="/etc/ssh/sshd_config"
    echo "PermitRootLogin: $(grep '^PermitRootLogin' $sshd_config | awk '{print $2}' || echo 'default')"
    echo "PasswordAuthentication: $(grep '^PasswordAuthentication' $sshd_config | awk '{print $2}' || echo 'default')"
    echo "Port: $(grep '^Port' $sshd_config | awk '{print $2}' || echo '22')"
    
    echo -e "\n${WHITE}3. File Permissions:${NC}"
    echo "World-writable files in /etc:"
    find /etc -type f -perm -002 2>/dev/null | head -5
    
    echo -e "\n${WHITE}4. Network Security:${NC}"
    echo "Open ports:"
    ss -tuln | grep LISTEN | head -10
    
    echo -e "\n${WHITE}5. System Updates:${NC}"
    if command -v apt &>/dev/null; then
        local updates=$(apt list --upgradable 2>/dev/null | wc -l)
        echo "Available updates: $((updates - 1))"
    fi
    
    read -n1 -r -p "Press any key to continue..." _
}

# Network Interface Status
network_interface_status() {
    clear
    echo -e "${YELLOW}═══ NETWORK INTERFACE STATUS ═══${NC}"
    
    echo -e "${WHITE}Network Interfaces:${NC}"
    ip addr show
    
    echo -e "\n${WHITE}Routing Table:${NC}"
    ip route show
    
    echo -e "\n${WHITE}Network Statistics:${NC}"
    cat /proc/net/dev | column -t
    
    echo -e "\n${WHITE}Active Network Connections:${NC}"
    ss -tuln | head -20
    
    echo -e "\n${WHITE}DNS Configuration:${NC}"
    cat /etc/resolv.conf
    
    read -n1 -r -p "Press any key to continue..." _
}

# Toggle Wireguard Service
toggle_wireguard_service() {
    local instance_dir="$1"
    local compose_file="$instance_dir/$DOCKER_COMPOSE_FILE"
    
    if [[ ! -f "$compose_file" ]]; then
        echo -e "${RED}Docker compose file not found: $compose_file${NC}"
        return
    fi
    
    if docker compose -f "$compose_file" ps | grep -q 'Up'; then
        echo -e "${YELLOW}Stopping Wireguard service...${NC}"
        docker compose -f "$compose_file" down
        echo -e "${GREEN}✓ Service stopped${NC}"
    else
        echo -e "${YELLOW}Starting Wireguard service...${NC}"
        docker compose -f "$compose_file" up -d
        echo -e "${GREEN}✓ Service started${NC}"
    fi
    
    log_action "INFO" "Wireguard service toggled for: $instance_dir"
}

# Reset Instance Configuration
reset_instance_config() {
    local instance_dir="$1"
    local config_dir="$instance_dir/$WG_CONFIG_DIR"
    local compose_file="$instance_dir/$DOCKER_COMPOSE_FILE"
    
    echo -e "${RED}WARNING: This will delete all Wireguard configurations!${NC}"
    echo -ne "${RED}Type 'RESET' to confirm: ${NC}"
    read -r CONFIRMATION
    
    if [[ "$CONFIRMATION" == "RESET" ]]; then
        # Stop service if running
        if [[ -f "$compose_file" ]] && docker compose -f "$compose_file" ps | grep -q 'Up'; then
            echo -e "${YELLOW}Stopping service...${NC}"
            docker compose -f "$compose_file" down
        fi
        
        # Remove configuration
        if [[ -d "$config_dir" ]]; then
            rm -rf "$config_dir"/*
            echo -e "${GREEN}✓ Configuration reset completed${NC}"
            log_action "WARNING" "Wireguard configuration reset: $instance_dir"
        else
            echo -e "${RED}Configuration directory not found: $config_dir${NC}"
        fi
    else
        echo -e "${YELLOW}Operation cancelled.${NC}"
    fi
}

# Placeholder functions for remaining features
configure_auto_scripts() {
    echo -e "${YELLOW}Configure Auto-login Scripts - Under Development${NC}"
    read -n1 -r -p "Press any key to continue..." _
}

audit_user_permissions() {
    echo -e "${YELLOW}User Permissions Audit - Under Development${NC}"
    read -n1 -r -p "Press any key to continue..." _
}

modify_user_groups() {
    echo -e "${YELLOW}Modify User Groups - Under Development${NC}"
    read -n1 -r -p "Press any key to continue..." _
}

toggle_user_lock() {
    echo -e "${YELLOW}Toggle User Lock - Under Development${NC}"
    read -n1 -r -p "Press any key to continue..." _
}

set_password_expiry() {
    echo -e "${YELLOW}Set Password Expiry - Under Development${NC}"
    read -n1 -r -p "Press any key to continue..." _
}

show_user_info() {
    local user="$1"
    echo -e "${YELLOW}User Information for: $user${NC}"
    id "$user"
    finger "$user" 2>/dev/null || echo "Finger not available"
    read -n1 -r -p "Press any key to continue..." _
}

# Additional placeholder functions
reset_wireguard_config() { echo "Reset Wireguard Config - Under Development"; read -n1 -r -p "Press any key..." _; }
backup_restore_menu() { echo "Backup/Restore Menu - Under Development"; read -n1 -r -p "Press any key..." _; }
monitor_wg_connections() { echo "Monitor WG Connections - Under Development"; read -n1 -r -p "Press any key..." _; }
update_wireguard_images() { echo "Update Wireguard Images - Under Development"; read -n1 -r -p "Press any key..." _; }
view_wg_config_details() { echo "View WG Config Details - Under Development"; read -n1 -r -p "Press any key..." _; }
view_wg_logs() { echo "View WG Logs - Under Development"; read -n1 -r -p "Press any key..." _; }
export_wg_backup() { echo "Export WG Backup - Under Development"; read -n1 -r -p "Press any key..." _; }
security_log_analysis() {
    clear
    echo -e "${YELLOW}═══ ANALYSE DES LOGS DE SÉCURITÉ ═══${NC}"
    echo -e "\n${WHITE}Derniers événements de sécurité (auth.log / secure) :${NC}"
    if [ -f /var/log/auth.log ]; then
        sudo tail -n 30 /var/log/auth.log | grep -E "(fail|invalid|error|refused|denied|root|sudo)" --color=always || tail -n 30 /var/log/auth.log
    elif [ -f /var/log/secure ]; then
        sudo tail -n 30 /var/log/secure | grep -E "(fail|invalid|error|refused|denied|root|sudo)" --color=always || tail -n 30 /var/log/secure
    else
        echo -e "${RED}Aucun fichier de log de sécurité trouvé (/var/log/auth.log ou /var/log/secure).${NC}"
    fi
    echo -e "\n${WHITE}Dernières connexions SSH :${NC}"
    last -a | head -10
    echo -e "\n${WHITE}Dernières tentatives sudo échouées :${NC}"
    sudo grep 'sudo' /var/log/auth.log 2>/dev/null | grep -i 'incorrect password\|authentication failure' | tail -10 || echo "Pas d'échec sudo récent."
    read -n1 -r -p "Appuyez sur une touche pour continuer..." _
}
detailed_hardware_info() { echo "Informations matérielles détaillées - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
process_service_monitor() { echo "Supervision des processus - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
disk_usage_analysis() { echo "Analyse de l'utilisation disque - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
performance_benchmarks() { echo "Benchmarks de performance - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
container_management() { echo "Gestion des conteneurs - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
image_management() { echo "Gestion des images - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
volume_network_management() { echo "Gestion des volumes et réseaux - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
docker_system_cleanup() { echo "Nettoyage système Docker - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
docker_resource_analysis() { echo "Analyse des ressources Docker - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
ssh_config_analysis() { echo "Analyse de la configuration SSH - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
firewall_status_rules() { echo "Statut et règles du pare-feu - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
failed_login_analysis() { echo "Analyse des connexions échouées - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
file_permissions_audit() { echo "Audit des permissions de fichiers - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
apply_security_hardening() { echo "Renforcement de la sécurité - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
network_interface_config() { echo "Configuration des interfaces réseau - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
firewall_configuration() { echo "Configuration du pare-feu - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
dns_routing_config() { echo "Configuration DNS et routage - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
network_tools() { echo "Outils réseau - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }
hostname_time_config() { echo "Configuration du nom d'hôte et de l'heure - En développement"; read -n1 -r -p "Appuyez sur une touche..." _; }

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
