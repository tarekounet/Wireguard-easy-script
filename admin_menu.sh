#!/bin/bash
# Advanced Technical Administration Menu for Wireguard Environment
# Version: Dynamique (lue depuis version.txt)
# Author: Tarek.E
# Project: Wireguard Easy Script
# Repository: https://github.com/tarekounet/Wireguard-easy-script

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
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="$(cat "${SCRIPT_DIR}/version.txt" 2>/dev/null || echo "0.10.0")"
readonly SCRIPT_AUTHOR="Tarek.E"
readonly MIN_PASSWORD_LENGTH=8
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
        
        # En-tête moderne
        echo -e "\e[48;5;236m\e[97m                                                    \e[0m"
        echo -e "\e[48;5;236m\e[97m           🔧 ADMINISTRATION TECHNIQUE            \e[0m"
        echo -e "\e[48;5;236m\e[97m                                                    \e[0m"
        
        # Informations auteur et version
        echo -e "\n\e[48;5;235m\e[97m            ℹ️  INFORMATIONS SCRIPT               \e[0m"
        echo -e "\n    \e[90m👨‍💻 Auteur :\e[0m \e[1;36m${SCRIPT_AUTHOR}\e[0m"
        echo -e "    \e[90m📦 Version :\e[0m \e[1;32m${SCRIPT_VERSION}\e[0m"
        echo -e "    \e[90m🔗 Projet :\e[0m \e[1;33mWireguard Easy Script\e[0m"
        echo -e "    \e[90m📅 Build :\e[0m \e[1;36m$(date '+%d/%m/%Y')\e[0m"
        
        # Informations système
        echo -e "\n\e[48;5;237m\e[97m            📊 INFORMATIONS SYSTÈME              \e[0m"
        echo -e "\n    \e[90m🖥️  Système :\e[0m \e[1;36m$(uname -sr)\e[0m"
        echo -e "    \e[90m⏱️  Uptime :\e[0m \e[1;32m$(uptime -p 2>/dev/null || echo "Non disponible")\e[0m"
        echo -e "    \e[90m👤 Utilisateur :\e[0m \e[1;33m$(whoami)\e[0m"
        echo -e "    \e[90m� Session :\e[0m \e[1;36m$(date '+%d/%m/%Y %H:%M:%S')\e[0m"
        
        # Menu principal
        echo -e "\n\e[48;5;24m\e[97m  👥 GESTION DES UTILISATEURS  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 1\e[0m \e[97mCréer un utilisateur\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 2\e[0m \e[97mModifier un utilisateur\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 3\e[0m \e[97mSupprimer un utilisateur\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 4\e[0m \e[97mRAZ Docker-WireGuard utilisateur\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[48;5;22m\e[97m  🔄 MAINTENANCE SYSTÈME  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 5\e[0m \e[97mVérifier les mises à jour\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 6\e[0m \e[97mMettre à jour le système\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 7\e[0m \e[97mNettoyage du système\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 8\e[0m \e[97mConfiguration réseau et SSH\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[48;5;52m\e[97m  ⚡ GESTION ALIMENTATION  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 9\e[0m \e[97mRedémarrer le système\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m10\e[0m \e[97mArrêter le système\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m11\e[0m \e[97mProgrammer un redémarrage/arrêt\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;31m 0\e[0m \e[97mOptions de sortie\e[0m \e[1;31m🚪\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        # Footer avec informations de version
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    │ \e[0m\e[1;36m${SCRIPT_AUTHOR}\e[0m \e[90m• Version \e[0m\e[1;32m${SCRIPT_VERSION}\e[0m \e[90m• Wireguard Easy Script     │\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -ne "\n\e[1;33mEntrez votre choix : \e[0m"
        read -r CHOICE
        
        case $CHOICE in
            1) create_technical_user ;;
            2) modify_user_menu ;;
            3) remove_user_secure ;;
            4) reset_user_docker_wireguard ;;
            5) check_available_updates ;;
            6) full_system_update ;;
            7) system_cleanup_menu ;;
            8) network_ssh_config_menu ;;
            9) immediate_reboot ;;
            10) immediate_shutdown ;;
            11) power_scheduling_menu ;;
            0) exit_menu ;;
            *)
                echo -e "\e[1;31mChoix invalide. Veuillez saisir un numéro entre 0 et 11.\e[0m"
                sleep 2
                ;;
        esac
    done
}

# Exit menu with options
exit_menu() {
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           🚪 OPTIONS DE SORTIE                  \e[0m"
        
        echo -e "\n\e[48;5;24m\e[97m  🔚 CHOISISSEZ VOTRE ACTION  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 1\e[0m \e[97mQuitter le script uniquement\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 2\e[0m \e[97mFermer la session utilisateur\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;33m 0\e[0m \e[97mRetour au menu principal\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    │ \e[0m\e[1;36m${SCRIPT_AUTHOR}\e[0m \e[90m• Version \e[0m\e[1;32m${SCRIPT_VERSION}\e[0m \e[90m• Wireguard Easy Script     │\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -ne "\n\e[1;33mEntrez votre choix : \e[0m"
        read -r EXIT_CHOICE
        
        case $EXIT_CHOICE in
            1)
                clear
                log_action "INFO" "Sortie du script admin par l'utilisateur"
                echo -e "\e[1;32m✅ Script d'administration fermé. À bientôt ! 👋\e[0m"
                exit 0
                ;;
            2)
                clear
                echo -e "\e[1;31m⚠️  ATTENTION :\e[0m Ceci fermera complètement votre session."
                echo -e "Vous devrez vous reconnecter pour utiliser le système."
                echo -ne "\n\e[1;33mConfirmer la fermeture de session ? [o/N] : \e[0m"
                read -r CONFIRM_LOGOUT
                
                if [[ "$CONFIRM_LOGOUT" =~ ^[oOyY]$ ]]; then
                    log_action "INFO" "Fermeture de session demandée par l'utilisateur"
                    echo -e "\e[1;31m🔒 Fermeture de la session en cours...\e[0m"
                    sleep 2
                    
                    # Déconnexion selon le type de session
                    if [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" ]]; then
                        # Session SSH
                        pkill -TERM -u "$(whoami)" 2>/dev/null || true
                    else
                        # Session locale
                        if command -v loginctl &>/dev/null; then
                            loginctl terminate-user "$(whoami)" 2>/dev/null || logout
                        else
                            logout 2>/dev/null || exit 0
                        fi
                    fi
                else
                    echo -e "\e[1;33mFermeture de session annulée.\e[0m"
                    sleep 1
                fi
                ;;
            0)
                return
                ;;
            *)
                echo -e "\e[1;31mChoix invalide. Veuillez saisir 0, 1 ou 2.\e[0m"
                sleep 2
                ;;
        esac
    done
}

# Network and SSH configuration menu
network_ssh_config_menu() {
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           🌐 CONFIGURATION RÉSEAU & SSH          \e[0m"
        
        # Affichage des informations réseau actuelles
        echo -e "\n\e[48;5;237m\e[97m            📊 ÉTAT ACTUEL DU RÉSEAU             \e[0m"
        display_current_network_info
        
        echo -e "\n\e[48;5;24m\e[97m  🔧 OPTIONS DE CONFIGURATION  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 1\e[0m \e[97mConfigurer l'adresse IP\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 2\e[0m \e[97mChanger le mode réseau (DHCP/Statique)\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 3\e[0m \e[97mConfigurer le serveur SSH\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 4\e[0m \e[97mModifier le port SSH\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 5\e[0m \e[97mActiver/Désactiver SSH\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 6\e[0m \e[97mRedémarrer les services réseau\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;31m 0\e[0m \e[97mRetour au menu principal\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -ne "\n\e[1;33mEntrez votre choix : \e[0m"
        read -r NET_CHOICE
        
        case $NET_CHOICE in
            1) configure_ip_address ;;
            2) configure_network_mode ;;
            3) configure_ssh_server ;;
            4) configure_ssh_port ;;
            5) toggle_ssh_service ;;
            6) restart_network_services ;;
            0) break ;;
            *)
                echo -e "\e[1;31mChoix invalide.\e[0m"
                sleep 2
                ;;
        esac
        
        if [[ "$NET_CHOICE" != "0" ]]; then
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
        fi
    done
}

# Display current network information
display_current_network_info() {
    local physical_interface=$(get_physical_interface)
    
    if [[ -n "$physical_interface" ]]; then
        local ip_address=$(ip addr show "$physical_interface" | grep -oP 'inet \K[^/]+' | head -1)
        local netmask=$(ip addr show "$physical_interface" | grep -oP 'inet [^/]+/\K[0-9]+' | head -1)
        local gateway=$(ip route | grep default | grep "$physical_interface" | awk '{print $3}' | head -1)
        local mac_address=$(ip link show "$physical_interface" | grep -oP 'link/ether \K[^ ]+')
        local link_status=$(ip link show "$physical_interface" | grep -oP 'state \K[A-Z]+')
        
        echo -e "\n    \e[90m🔌 Interface :\e[0m \e[1;36m$physical_interface\e[0m \e[90m($link_status)\e[0m"
        echo -e "    \e[90m🌐 Adresse IP :\e[0m \e[1;36m${ip_address:-Non configurée}\e[0m"
        echo -e "    \e[90m📊 Masque :\e[0m \e[1;36m/${netmask:-Non défini}\e[0m"
        echo -e "    \e[90m🚪 Passerelle :\e[0m \e[1;36m${gateway:-Non définie}\e[0m"
        echo -e "    \e[90m🏷️  MAC :\e[0m \e[1;36m$mac_address\e[0m"
        
        # Détecter le mode (DHCP ou statique)
        local network_mode="Statique"
        if is_dhcp_enabled "$physical_interface"; then
            network_mode="DHCP"
        fi
        echo -e "    \e[90m⚙️  Mode :\e[0m \e[1;36m$network_mode\e[0m"
    else
        echo -e "\n    \e[1;31m❌ Aucune interface réseau physique détectée\e[0m"
    fi
    
    # Informations SSH
    local ssh_status="Inactif"
    local ssh_port="22"
    local ssh_color="\e[1;31m"
    
    if systemctl is-active ssh >/dev/null 2>&1 || systemctl is-active sshd >/dev/null 2>&1; then
        ssh_status="Actif"
        ssh_color="\e[1;32m"
    fi
    
    if [[ -f /etc/ssh/sshd_config ]]; then
        ssh_port=$(grep -oP '^Port \K[0-9]+' /etc/ssh/sshd_config 2>/dev/null || echo "22")
    fi
    
    echo -e "    \e[90m🔐 SSH :\e[0m $ssh_color$ssh_status\e[0m \e[90m(Port: $ssh_port)\e[0m"
}

# System cleanup menu
system_cleanup_menu() {
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           🧹 NETTOYAGE SYSTÈME                  \e[0m"
        
        echo -e "\n\e[48;5;24m\e[97m  📦 OPTIONS DE NETTOYAGE  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 1\e[0m \e[97mNettoyage des paquets\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 2\e[0m \e[97mNettoyage des logs système\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 3\e[0m \e[97mNettoyage des fichiers temporaires\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 4\e[0m \e[97mNettoyage complet\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;31m 0\e[0m \e[97mRetour au menu principal\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -ne "\n\e[1;33mEntrez votre choix : \e[0m"
        read -r CLEANUP_CHOICE
        
        case $CLEANUP_CHOICE in
            1) clean_package_cache ;;
            2) clean_system_logs ;;
            3) clean_temp_files ;;
            4) full_system_cleanup ;;
            0) break ;;
            *)
                echo -e "\e[1;31mChoix invalide.\e[0m"
                sleep 2
                ;;
        esac
        
        if [[ "$CLEANUP_CHOICE" != "0" ]]; then
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
        fi
    done
}

# Power scheduling menu
power_scheduling_menu() {
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           ⏰ PLANIFICATION ALIMENTATION         \e[0m"
        
        echo -e "\n\e[48;5;24m\e[97m  📅 OPTIONS DE PLANIFICATION  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 1\e[0m \e[97mProgrammer un redémarrage\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 2\e[0m \e[97mProgrammer un arrêt\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 3\e[0m \e[97mAnnuler une programmation\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 4\e[0m \e[97mVoir les tâches programmées\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;31m 0\e[0m \e[97mRetour au menu principal\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        
        echo -ne "\n\e[1;33mEntrez votre choix : \e[0m"
        read -r POWER_CHOICE
        
        case $POWER_CHOICE in
            1) schedule_reboot ;;
            2) schedule_shutdown ;;
            3) cancel_scheduled_task ;;
            4) show_scheduled_tasks ;;
            0) break ;;
            *)
                echo -e "\e[1;31mChoix invalide.\e[0m"
                sleep 2
                ;;
        esac
        
        if [[ "$POWER_CHOICE" != "0" ]]; then
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
        fi
    done
}

# Enhanced user creation with technical validation
create_technical_user() {
    clear
    echo -e "\e[48;5;236m\e[97m           👤 CRÉATION D'UTILISATEUR              \e[0m"
    
    echo -e "\n\e[48;5;24m\e[97m  📝 INFORMATIONS UTILISATEUR  \e[0m"
    
    # Étape 1: Nom d'utilisateur
    local NEWUSER=""
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           👤 CRÉATION D'UTILISATEUR              \e[0m"
        echo -e "\n\e[48;5;24m\e[97m  📝 ÉTAPE 1/3 - NOM D'UTILISATEUR  \e[0m"
        
        echo -e "\n\e[1;33mNom d'utilisateur :\e[0m"
        echo -e "\e[90m  • Format : lettres minuscules, chiffres, tiret, underscore\e[0m"
        echo -e "\e[90m  • Longueur : 2-32 caractères\e[0m"
        echo -e "\e[90m  • Tapez 'annuler' pour revenir au menu principal\e[0m"
        echo -ne "\e[1;36m→ \e[0m"
        read -r NEWUSER
        
        # Option d'annulation
        if [[ "$NEWUSER" == "annuler" || "$NEWUSER" == "cancel" || "$NEWUSER" == "exit" ]]; then
            echo -e "\e[1;33m❌ Création d'utilisateur annulée\e[0m"
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
            return
        fi
        
        if [[ -z "$NEWUSER" ]]; then
            echo -e "\e[1;31m✗ Le nom d'utilisateur ne peut pas être vide\e[0m"
            sleep 2
            continue
        elif ! validate_username "$NEWUSER"; then
            echo -e "\e[1;31m✗ Format invalide\e[0m"
            sleep 2
            continue
        elif id "$NEWUSER" &>/dev/null; then
            echo -e "\e[1;31m✗ L'utilisateur '$NEWUSER' existe déjà\e[0m"
            sleep 2
            continue
        elif [[ "$NEWUSER" =~ ^(root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|ftp|nobody|systemd.*|_.*|sshd|messagebus|uuidd)$ ]]; then
            echo -e "\e[1;31m✗ Nom réservé au système\e[0m"
            sleep 2
            continue
        fi
        
        echo -e "\e[1;32m✓ Nom d'utilisateur valide : $NEWUSER\e[0m"
        echo -e "\n\e[1;33mConfirmer ce nom d'utilisateur ? [o/N/retour] : \e[0m"
        read -r CONFIRM_USER
        
        case "$CONFIRM_USER" in
            [oOyY])
                break
                ;;
            [rR]|retour)
                continue
                ;;
            *)
                echo -e "\e[1;33m❌ Création d'utilisateur annulée\e[0m"
                echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                read -n1 -s
                return
                ;;
        esac
    done
    
    # Étape 2: Mot de passe
    local NEWPASS=""
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           👤 CRÉATION D'UTILISATEUR              \e[0m"
        echo -e "\n\e[48;5;24m\e[97m  📝 ÉTAPE 2/3 - MOT DE PASSE  \e[0m"
        
        echo -e "\n\e[90m📊 Informations saisies :\e[0m"
        echo -e "    \e[90m👤 Utilisateur :\e[0m \e[1;36m$NEWUSER\e[0m"
        
        echo -e "\n\e[1;33mMot de passe :\e[0m"
        echo -e "\e[90m  • Minimum ${MIN_PASSWORD_LENGTH} caractères\e[0m"
        echo -e "\e[90m  • Utilisez des majuscules, minuscules, chiffres et symboles\e[0m"
        echo -e "\e[90m  • Laissez vide pour revenir à l'étape précédente\e[0m"
        echo -ne "\e[1;36m→ \e[0m"
        read -rs NEWPASS
        echo
        
        # Option de retour en arrière
        if [[ -z "$NEWPASS" ]]; then
            echo -e "\e[1;33m⬅️  Retour à l'étape précédente\e[0m"
            sleep 1
            break  # Retourne à la boucle du nom d'utilisateur
        fi
        
        if [[ ${#NEWPASS} -lt $MIN_PASSWORD_LENGTH ]]; then
            echo -e "\e[1;31m✗ Mot de passe trop court (minimum ${MIN_PASSWORD_LENGTH} caractères)\e[0m"
            sleep 2
            continue
        fi
        
        echo -ne "\e[1;33mConfirmation du mot de passe : \e[0m\e[1;36m→ \e[0m"
        read -rs NEWPASS2
        echo
        
        if [[ "$NEWPASS" != "$NEWPASS2" ]]; then
            echo -e "\e[1;31m✗ Les mots de passe ne correspondent pas\e[0m"
            sleep 2
            continue
        fi
        
        echo -e "\e[1;32m✓ Mot de passe valide\e[0m"
        echo -e "\n\e[1;33mConfirmer ce mot de passe ? [o/N/retour] : \e[0m"
        read -r CONFIRM_PASS
        
        case "$CONFIRM_PASS" in
            [oOyY])
                # Étape 3: Récapitulatif et confirmation finale
                while true; do
                    clear
                    echo -e "\e[48;5;236m\e[97m           👤 CRÉATION D'UTILISATEUR              \e[0m"
                    echo -e "\n\e[48;5;24m\e[97m  📝 ÉTAPE 3/3 - CONFIRMATION FINALE  \e[0m"
                    
                    echo -e "\n\e[48;5;22m\e[97m  📋 RÉCAPITULATIF  \e[0m"
                    echo -e "\e[90m┌─────────────────────────────────────────────────┐\e[0m"
                    echo -e "\e[90m│\e[0m \e[1;36mUtilisateur :\e[0m $NEWUSER"
                    echo -e "\e[90m│\e[0m \e[1;36mGroupes :\e[0m docker, sudo"
                    echo -e "\e[90m│\e[0m \e[1;36mShell :\e[0m /bin/bash"
                    echo -e "\e[90m│\e[0m \e[1;36mDossier home :\e[0m /home/$NEWUSER"
                    echo -e "\e[90m│\e[0m \e[1;36mDossier script :\e[0m /home/$NEWUSER/wireguard-script-manager"
                    echo -e "\e[90m└─────────────────────────────────────────────────┘\e[0m"
                    
                    echo -e "\n\e[1;33mOptions disponibles :\e[0m"
                    echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
                    echo -e "\e[90m    ├─ \e[0m\e[1;32m C\e[0m \e[97mCréer l'utilisateur\e[0m"
                    echo -e "\e[90m    ├─ \e[0m\e[1;33m R\e[0m \e[97mRevenir au mot de passe\e[0m"
                    echo -e "\e[90m    ├─ \e[0m\e[1;31m A\e[0m \e[97mAnnuler complètement\e[0m"
                    echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
                    
                    echo -ne "\n\e[1;33mVotre choix [C/R/A] : \e[0m"
                    read -r FINAL_CHOICE
                    
                    case "$FINAL_CHOICE" in
                        [cC])
                            # Création de l'utilisateur
                            echo -e "\n\e[1;33m🔄 Création de l'utilisateur en cours...\e[0m"
                            
                            log_action "INFO" "Création de l'utilisateur : $NEWUSER"
                            if useradd -m -s /bin/bash -G docker,sudo "$NEWUSER" 2>/dev/null; then
                                if echo "$NEWUSER:$NEWPASS" | chpasswd 2>/dev/null; then
                                    USER_HOME="/home/$NEWUSER"
                                    SCRIPT_DIR="$USER_HOME/wireguard-script-manager"
                                    mkdir -p "$SCRIPT_DIR"
                                    chown -R "$NEWUSER:$NEWUSER" "$SCRIPT_DIR"
                                    chmod 750 "$SCRIPT_DIR"
                                    
                                    echo -e "\n\e[1;32m✅ UTILISATEUR CRÉÉ AVEC SUCCÈS\e[0m"
                                    echo -e "\e[90m┌─────────────────────────────────────────────────┐\e[0m"
                                    echo -e "\e[90m│\e[0m \e[1;36mUtilisateur :\e[0m $NEWUSER"
                                    echo -e "\e[90m│\e[0m \e[1;36mGroupes :\e[0m docker, sudo"
                                    echo -e "\e[90m│\e[0m \e[1;36mDossier :\e[0m $SCRIPT_DIR"
                                    echo -e "\e[90m└─────────────────────────────────────────────────┘\e[0m"
                                    
                                    echo -ne "\n\e[1;33mConfigurer le lancement automatique du script ? [o/N] : \e[0m"
                                    read -r AUTOSTART
                                    if [[ "$AUTOSTART" =~ ^[oOyY]$ ]]; then
                                        configure_user_autostart "$NEWUSER" "$SCRIPT_DIR"
                                    fi
                                    
                                    log_action "INFO" "Utilisateur $NEWUSER créé avec succès"
                                    echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                                    read -n1 -s
                                    return
                                else
                                    echo -e "\e[1;31m❌ Erreur lors de la définition du mot de passe\e[0m"
                                    userdel -r "$NEWUSER" 2>/dev/null || true
                                fi
                            else
                                echo -e "\e[1;31m❌ Erreur lors de la création de l'utilisateur\e[0m"
                            fi
                            
                            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                            read -n1 -s
                            return
                            ;;
                        [rR])
                            break 2  # Retourne à la saisie du mot de passe
                            ;;
                        [aA])
                            echo -e "\e[1;33m❌ Création d'utilisateur annulée\e[0m"
                            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                            read -n1 -s
                            return
                            ;;
                        *)
                            echo -e "\e[1;31m✗ Choix invalide. Utilisez C, R ou A\e[0m"
                            sleep 2
                            ;;
                    esac
                done
                ;;
            [rR]|retour)
                continue  # Recommence la saisie du mot de passe
                ;;
            *)
                echo -e "\e[1;33m❌ Création d'utilisateur annulée\e[0m"
                echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                read -n1 -s
                return
                ;;
        esac
    done
}
# User modification menu
modify_user_menu() {
    clear
    echo -e "\e[48;5;236m\e[97m           ✏️  MODIFICATION D'UTILISATEUR          \e[0m"
    
    # Filter only real human users: UID >= 1000, valid shell, exclude system accounts
    mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody")&&($7!="/usr/sbin/nologin")&&($7!="/bin/false")&&($7!="/sbin/nologin")&&($7!="")&&($1!~"^_")&&($1!~"^systemd")&&($1!~"^daemon")&&($1!~"^mail")&&($1!~"^ftp")&&($1!~"^www-data")&&($1!~"^backup")&&($1!~"^list")&&($1!~"^proxy")&&($1!~"^uucp")&&($1!~"^news")&&($1!~"^gnats"){print $1}' /etc/passwd)
    
    if [[ ${#USERS[@]} -eq 0 ]]; then
        echo -e "\n\e[1;31m❌ Aucun utilisateur humain trouvé.\e[0m"
        echo -e "\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
        return
    fi
    
    echo -e "\n\e[48;5;24m\e[97m  👥 UTILISATEURS DISPONIBLES  \e[0m"
    echo -e "\e[90m┌─────┬─────────────────┬─────────────────┬─────────────────────────────┐\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36mNum\e[0m \e[90m│\e[0m \e[1;36mUtilisateur\e[0m     \e[90m│\e[0m \e[1;36mShell\e[0m           \e[90m│\e[0m \e[1;36mRépertoire\e[0m              \e[90m│\e[0m"
    echo -e "\e[90m├─────┼─────────────────┼─────────────────┼─────────────────────────────┤\e[0m"
    
    for i in "${!USERS[@]}"; do
        local user="${USERS[$i]}"
        local shell=$(getent passwd "$user" | cut -d: -f7)
        local home=$(getent passwd "$user" | cut -d: -f6)
        printf "\e[90m│\e[0m \e[1;33m%3d\e[0m \e[90m│\e[0m %-15s \e[90m│\e[0m %-15s \e[90m│\e[0m %-27s \e[90m│\e[0m\n" $((i+1)) "$user" "$(basename "$shell")" "$home"
    done
    
    echo -e "\e[90m└─────┴─────────────────┴─────────────────┴─────────────────────────────┘\e[0m"
    
    echo -ne "\n\e[1;33mSélectionnez un utilisateur [1-${#USERS[@]}] ou 0 pour annuler : \e[0m"
    read -r IDX
    
    if [[ "$IDX" == "0" ]]; then
        return
    fi
    
    IDX=$((IDX-1))
    if [[ $IDX -ge 0 && $IDX -lt ${#USERS[@]} ]]; then
        local SELECTED_USER="${USERS[$IDX]}"
        user_modification_options "$SELECTED_USER"
    else
        echo -e "\e[1;31m✗ Sélection invalide.\e[0m"
        sleep 2
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

# Reset user Docker-WireGuard
reset_user_docker_wireguard() {
    clear
    echo -e "\e[48;5;236m\e[97m           🔄 RAZ DOCKER-WIREGUARD UTILISATEUR     \e[0m"
    
    # Filter only real human users with home directories
    mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody")&&($7!="/usr/sbin/nologin")&&($7!="/bin/false")&&($7!="/sbin/nologin")&&($7!="")&&($1!~"^_")&&($1!~"^systemd")&&($1!~"^daemon")&&($1!~"^mail")&&($1!~"^ftp")&&($1!~"^www-data")&&($1!~"^backup")&&($1!~"^list")&&($1!~"^proxy")&&($1!~"^uucp")&&($1!~"^news")&&($1!~"^gnats"){print $1}' /etc/passwd)
    
    if [[ ${#USERS[@]} -eq 0 ]]; then
        echo -e "\n\e[1;31m❌ Aucun utilisateur trouvé\e[0m"
        echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
        return
    fi
    
    echo -e "\n\e[48;5;24m\e[97m  👥 SÉLECTION UTILISATEUR  \e[0m"
    echo -e "\n\e[1;33mUtilisateurs disponibles :\e[0m"
    
    # Afficher les utilisateurs avec vérification du dossier docker-wireguard
    for i in "${!USERS[@]}"; do
        local user="${USERS[$i]}"
        local home=$(getent passwd "$user" | cut -d: -f6)
        local docker_wg_path="$home/docker-wireguard"
        local status_color="\e[1;31m"
        local status_text="❌ Inexistant"
        
        if [[ -d "$docker_wg_path" ]]; then
            local file_count=$(find "$docker_wg_path" -type f 2>/dev/null | wc -l)
            if [[ $file_count -gt 0 ]]; then
                status_color="\e[1;32m"
                status_text="✓ Présent ($file_count fichiers)"
            else
                status_color="\e[1;33m"
                status_text="⚠️  Vide"
            fi
        fi
        
        printf "\e[90m    ├─ \e[0m\e[1;36m%2d\e[0m \e[97m%-15s\e[0m $status_color$status_text\e[0m\n" $((i+1)) "$user"
    done
    
    echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m    ├─ \e[0m\e[1;31m 0\e[0m \e[97mRetour au menu principal\e[0m"
    echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
    
    echo -ne "\n\e[1;33mNuméro de l'utilisateur [1-${#USERS[@]}] ou 0 pour annuler : \e[0m"
    read -r IDX
    
    if [[ "$IDX" == "0" ]]; then
        return
    fi
    
    IDX=$((IDX-1))
    if [[ $IDX -ge 0 && $IDX -lt ${#USERS[@]} ]]; then
        local TARGET_USER="${USERS[$IDX]}"
        local user_home=$(getent passwd "$TARGET_USER" | cut -d: -f6)
        local docker_wg_path="$user_home/docker-wireguard"
        
        clear
        echo -e "\e[48;5;236m\e[97m           🔄 CONFIRMATION RAZ DOCKER-WIREGUARD   \e[0m"
        
        echo -e "\n\e[48;5;24m\e[97m  📊 INFORMATIONS  \e[0m"
        echo -e "\n    \e[90m👤 Utilisateur :\e[0m \e[1;36m$TARGET_USER\e[0m"
        echo -e "    \e[90m📁 Répertoire :\e[0m \e[1;33m$docker_wg_path\e[0m"
        
        if [[ ! -d "$docker_wg_path" ]]; then
            echo -e "\n\e[1;31m❌ Le dossier docker-wireguard n'existe pas pour cet utilisateur\e[0m"
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
            return
        fi
        
        # Compter les fichiers
        local file_count=$(find "$docker_wg_path" -type f 2>/dev/null | wc -l)
        local dir_count=$(find "$docker_wg_path" -mindepth 1 -type d 2>/dev/null | wc -l)
        
        echo -e "    \e[90m📄 Fichiers :\e[0m \e[1;32m$file_count\e[0m"
        echo -e "    \e[90m📂 Dossiers :\e[0m \e[1;32m$dir_count\e[0m"
        
        if [[ $file_count -eq 0 && $dir_count -eq 0 ]]; then
            echo -e "\n\e[1;33m⚠️  Le dossier est déjà vide\e[0m"
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
            return
        fi
        
        echo -e "\n\e[1;31m⚠️  ATTENTION :\e[0m"
        echo -e "    \e[97m• Tout le contenu du dossier docker-wireguard sera supprimé\e[0m"
        echo -e "    \e[97m• Cette action est irréversible\e[0m"
        echo -e "    \e[97m• Les configurations WireGuard seront perdues\e[0m"
        
        echo -e "\n\e[1;33mTapez exactement 'RAZ $TARGET_USER' pour confirmer :\e[0m"
        echo -ne "\e[1;36m→ \e[0m"
        read -r CONFIRMATION
        
        if [[ "$CONFIRMATION" == "RAZ $TARGET_USER" ]]; then
            echo -e "\n\e[1;33m🔄 Suppression du contenu en cours...\e[0m"
            
            # Arrêter tous les conteneurs Docker de l'utilisateur si ils existent
            if command -v docker &>/dev/null; then
                echo -e "    \e[90m• Arrêt des conteneurs Docker...\e[0m"
                docker stop $(docker ps -q --filter "label=user=$TARGET_USER" 2>/dev/null) 2>/dev/null || true
                docker rm $(docker ps -aq --filter "label=user=$TARGET_USER" 2>/dev/null) 2>/dev/null || true
            fi
            
            # Supprimer le contenu du dossier
            echo -e "    \e[90m• Suppression des fichiers et dossiers...\e[0m"
            if rm -rf "$docker_wg_path"/* "$docker_wg_path"/.[!.]* "$docker_wg_path"/..?* 2>/dev/null; then
                echo -e "\e[1;32m✓ Contenu du dossier docker-wireguard supprimé avec succès\e[0m"
                log_action "WARNING" "RAZ docker-wireguard pour l'utilisateur $TARGET_USER"
                
                # Vérification finale
                local remaining_files=$(find "$docker_wg_path" -type f 2>/dev/null | wc -l)
                if [[ $remaining_files -eq 0 ]]; then
                    echo -e "\e[1;32m✅ Vérification : Le dossier est maintenant vide\e[0m"
                else
                    echo -e "\e[1;33m⚠️  Attention : $remaining_files fichiers restants (possiblement cachés)\e[0m"
                fi
            else
                echo -e "\e[1;31m❌ Erreur lors de la suppression\e[0m"
                echo -e "    \e[97mVérifiez les permissions ou contactez l'administrateur\e[0m"
            fi
        else
            echo -e "\n\e[1;33m❌ Confirmation incorrecte. Opération annulée.\e[0m"
        fi
    else
        echo -e "\n\e[1;31m❌ Sélection invalide\e[0m"
    fi
    
    echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
    read -n1 -s
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
    echo -e "\e[1;36m═══ NETTOYAGE DU CACHE DES PAQUETS ═══\e[0m\n"
    
    if command -v apt &>/dev/null; then
        echo -e "\e[1;33mNettoyage du cache APT...\e[0m"
        apt autoclean
        apt autoremove -y
        echo -e "\e[1;32m✓ Cache APT nettoyé\e[0m"
    elif command -v yum &>/dev/null; then
        echo -e "\e[1;33mNettoyage du cache YUM...\e[0m"
        yum clean all
        echo -e "\e[1;32m✓ Cache YUM nettoyé\e[0m"
    elif command -v dnf &>/dev/null; then
        echo -e "\e[1;33mNettoyage du cache DNF...\e[0m"
        dnf clean all
        echo -e "\e[1;32m✓ Cache DNF nettoyé\e[0m"
    else
        echo -e "\e[1;31m✗ Aucun gestionnaire de paquets reconnu\e[0m"
    fi
    
    log_action "INFO" "Cache des paquets nettoyé"
}

# Clean temporary files
clean_temp_files() {
    clear
    echo -e "\e[1;36m═══ NETTOYAGE DES FICHIERS TEMPORAIRES ═══\e[0m\n"
    
    echo -e "\e[1;33mNettoyage des fichiers temporaires...\e[0m"
    
    # Nettoyer /tmp
    echo -e "\e[0;36m• Nettoyage de /tmp...\e[0m"
    find /tmp -type f -mtime +3 -delete 2>/dev/null || true
    find /tmp -type d -empty -delete 2>/dev/null || true
    
    # Nettoyer /var/tmp
    echo -e "\e[0;36m• Nettoyage de /var/tmp...\e[0m"
    find /var/tmp -type f -mtime +7 -delete 2>/dev/null || true
    
    # Nettoyer les fichiers core
    echo -e "\e[0;36m• Suppression des fichiers core...\e[0m"
    find / -name "core.*" -type f -delete 2>/dev/null || true
    
    # Nettoyer les caches utilisateur
    echo -e "\e[0;36m• Nettoyage des caches utilisateur...\e[0m"
    find /home -name ".cache" -type d -exec rm -rf {}/* \; 2>/dev/null || true
    
    echo -e "\e[1;32m✓ Nettoyage des fichiers temporaires terminé\e[0m"
    log_action "INFO" "Nettoyage des fichiers temporaires effectué"
}

# Full system cleanup
full_system_cleanup() {
    clear
    echo -e "\e[1;36m═══ NETTOYAGE COMPLET DU SYSTÈME ═══\e[0m\n"
    echo -e "\e[1;31mATTENTION : Cette opération effectue un nettoyage complet du système.\e[0m"
    echo -ne "\e[1;33mContinuer ? [o/N] : \e[0m"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
        echo -e "\e[1;33mNettoyage complet en cours...\e[0m\n"
        
        # Nettoyage des paquets
        echo -e "\e[0;36m• Nettoyage des paquets...\e[0m"
        clean_package_cache
        
        # Nettoyage des logs
        echo -e "\e[0;36m• Nettoyage des logs...\e[0m"
        clean_system_logs
        
        # Nettoyage des fichiers temporaires
        echo -e "\e[0;36m• Nettoyage des fichiers temporaires...\e[0m"
        clean_temp_files
        
        # Nettoyages supplémentaires
        echo -e "\e[0;36m• Nettoyages supplémentaires...\e[0m"
        
        # Nettoyer les thumbnails
        find /home -name ".thumbnails" -type d -exec rm -rf {} \; 2>/dev/null || true
        
        # Nettoyer les corbeilles
        find /home -name ".local/share/Trash" -type d -exec rm -rf {}/files/* \; 2>/dev/null || true
        find /home -name ".local/share/Trash" -type d -exec rm -rf {}/info/* \; 2>/dev/null || true
        
        # Affichage de l'espace libéré
        echo -e "\n\e[1;32m✓ Nettoyage complet terminé\e[0m"
        echo -e "\e[0;36mEspace disque après nettoyage :\e[0m"
        df -h / | tail -1
        
        log_action "INFO" "Nettoyage complet du système effectué"
    else
        echo -e "\e[1;33mNettoyage annulé.\e[0m"
    fi
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
# NETWORK AND SSH CONFIGURATION FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Get the main physical network interface
get_physical_interface() {
    # Exclure les interfaces virtuelles communes
    local excluded_patterns="lo|docker|br-|veth|wg|tun|tap|virbr"
    
    # Chercher l'interface avec une route par défaut
    local default_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    
    if [[ -n "$default_interface" ]] && ! echo "$default_interface" | grep -qE "$excluded_patterns"; then
        echo "$default_interface"
        return 0
    fi
    
    # Si pas d'interface par défaut, chercher la première interface physique active
    local interface=$(ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | grep -vE "$excluded_patterns" | head -1)
    echo "$interface"
}

# Check if interface is using DHCP
is_dhcp_enabled() {
    local interface="$1"
    
    # Vérifier dans les fichiers de configuration Netplan (Ubuntu 18+)
    if [[ -d /etc/netplan ]]; then
        if grep -r "dhcp4.*true" /etc/netplan/ 2>/dev/null | grep -q "$interface"; then
            return 0
        fi
    fi
    
    # Vérifier dans /etc/network/interfaces (Debian/Ubuntu classique)
    if [[ -f /etc/network/interfaces ]]; then
        if grep -A5 "iface $interface" /etc/network/interfaces | grep -q "dhcp"; then
            return 0
        fi
    fi
    
    # Vérifier avec NetworkManager
    if command -v nmcli >/dev/null 2>&1; then
        if nmcli device show "$interface" 2>/dev/null | grep -q "IP4.DHCP4.OPTION"; then
            return 0
        fi
    fi
    
    return 1
}

# Validate IP address
validate_ip() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ $ip =~ $regex ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        for i in "${ADDR[@]}"; do
            if [[ $i -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Configure IP address
configure_ip_address() {
    clear
    echo -e "\e[48;5;236m\e[97m           🌐 CONFIGURATION ADRESSE IP            \e[0m"
    
    local physical_interface=$(get_physical_interface)
    
    if [[ -z "$physical_interface" ]]; then
        echo -e "\n\e[1;31m❌ Aucune interface réseau physique détectée.\e[0m"
        return 1
    fi
    
    echo -e "\n\e[48;5;24m\e[97m  📝 INTERFACE SÉLECTIONNÉE  \e[0m"
    echo -e "\n    \e[90m🔌 Interface :\e[0m \e[1;36m$physical_interface\e[0m"
    
    local current_ip=$(ip addr show "$physical_interface" | grep -oP 'inet \K[^/]+' | head -1)
    echo -e "    \e[90m🌐 IP actuelle :\e[0m \e[1;36m${current_ip:-Non configurée}\e[0m"
    
    echo -e "\n\e[1;33mNOTE :\e[0m Cette configuration définira une IP statique."
    echo -e "Si vous souhaitez utiliser DHCP, utilisez l'option 'Changer le mode réseau'."
    
    echo -e "\n\e[1;33mNouvelle adresse IP :\e[0m"
    echo -ne "\e[1;36m→ \e[0m"
    read -r NEW_IP
    
    if ! validate_ip "$NEW_IP"; then
        echo -e "\e[1;31m✗ Adresse IP invalide\e[0m"
        return 1
    fi
    
    echo -e "\n\e[1;33mMasque de sous-réseau (ex: 24 pour /24) :\e[0m"
    echo -ne "\e[1;36m→ \e[0m"
    read -r NETMASK
    
    if ! [[ "$NETMASK" =~ ^[0-9]+$ ]] || [[ "$NETMASK" -lt 1 ]] || [[ "$NETMASK" -gt 32 ]]; then
        echo -e "\e[1;31m✗ Masque invalide (doit être entre 1 et 32)\e[0m"
        return 1
    fi
    
    echo -e "\n\e[1;33mPasserelle par défaut :\e[0m"
    echo -ne "\e[1;36m→ \e[0m"
    read -r GATEWAY
    
    if ! validate_ip "$GATEWAY"; then
        echo -e "\e[1;31m✗ Adresse de passerelle invalide\e[0m"
        return 1
    fi
    
    echo -e "\n\e[1;33mServeur DNS primaire (optionnel, Entrée pour ignorer) :\e[0m"
    echo -ne "\e[1;36m→ \e[0m"
    read -r DNS1
    
    if [[ -n "$DNS1" ]] && ! validate_ip "$DNS1"; then
        echo -e "\e[1;31m✗ Adresse DNS invalide\e[0m"
        return 1
    fi
    
    # Confirmation
    echo -e "\n\e[1;33m📋 RÉCAPITULATIF DE LA CONFIGURATION :\e[0m"
    echo -e "\e[90m┌─────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36mInterface :\e[0m $physical_interface"
    echo -e "\e[90m│\e[0m \e[1;36mAdresse IP :\e[0m $NEW_IP/$NETMASK"
    echo -e "\e[90m│\e[0m \e[1;36mPasserelle :\e[0m $GATEWAY"
    echo -e "\e[90m│\e[0m \e[1;36mDNS :\e[0m ${DNS1:-Système par défaut}"
    echo -e "\e[90m└─────────────────────────────────────────────────┘\e[0m"
    
    echo -ne "\n\e[1;31mATTENTION :\e[0m Cette modification peut couper la connexion réseau.\n"
    echo -ne "\e[1;33mConfirmer la configuration ? [o/N] : \e[0m"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
        apply_static_ip_config "$physical_interface" "$NEW_IP" "$NETMASK" "$GATEWAY" "$DNS1"
    else
        echo -e "\e[1;33mConfiguration annulée.\e[0m"
    fi
}

# Apply static IP configuration
apply_static_ip_config() {
    local interface="$1"
    local ip="$2"
    local netmask="$3"
    local gateway="$4"
    local dns="$5"
    
    echo -e "\n\e[1;33m🔄 Application de la configuration...\e[0m"
    
    # Backup current configuration
    local backup_dir="/etc/network-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Sauvegarder selon le système
    if [[ -d /etc/netplan ]]; then
        cp -r /etc/netplan/* "$backup_dir/" 2>/dev/null || true
        configure_netplan "$interface" "$ip" "$netmask" "$gateway" "$dns"
    elif [[ -f /etc/network/interfaces ]]; then
        cp /etc/network/interfaces "$backup_dir/"
        configure_interfaces "$interface" "$ip" "$netmask" "$gateway" "$dns"
    else
        echo -e "\e[1;31m✗ Système de configuration réseau non reconnu\e[0m"
        return 1
    fi
    
    echo -e "\e[1;32m✓ Configuration appliquée\e[0m"
    echo -e "\e[1;33mSauvegarde créée dans : $backup_dir\e[0m"
    
    log_action "INFO" "Configuration IP statique appliquée pour $interface: $ip/$netmask"
    
    echo -ne "\n\e[1;33mRedémarrer les services réseau maintenant ? [o/N] : \e[0m"
    read -r RESTART
    if [[ "$RESTART" =~ ^[oOyY]$ ]]; then
        restart_network_services
    fi
}

# Configure Netplan (Ubuntu 18+)
configure_netplan() {
    local interface="$1"
    local ip="$2"
    local netmask="$3"
    local gateway="$4"
    local dns="$5"
    
    local netplan_file="/etc/netplan/01-static-config.yaml"
    
    cat > "$netplan_file" << EOF
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: false
      addresses:
        - $ip/$netmask
      gateway4: $gateway
EOF

    if [[ -n "$dns" ]]; then
        cat >> "$netplan_file" << EOF
      nameservers:
        addresses:
          - $dns
          - 8.8.8.8
EOF
    fi
    
    # Appliquer la configuration
    netplan apply 2>/dev/null || echo -e "\e[1;33mRedémarrez les services réseau pour appliquer les changements\e[0m"
}

# Configure /etc/network/interfaces (Debian classique)
configure_interfaces() {
    local interface="$1"
    local ip="$2"
    local netmask="$3"
    local gateway="$4"
    local dns="$5"
    
    # Supprimer l'ancienne configuration pour cette interface
    sed -i "/^auto $interface/,/^$/d" /etc/network/interfaces
    sed -i "/^iface $interface/,/^$/d" /etc/network/interfaces
    
    # Ajouter la nouvelle configuration
    cat >> /etc/network/interfaces << EOF

auto $interface
iface $interface inet static
    address $ip
    netmask $(cidr_to_netmask "$netmask")
    gateway $gateway
EOF

    if [[ -n "$dns" ]]; then
        echo "    dns-nameservers $dns 8.8.8.8" >> /etc/network/interfaces
    fi
}

# Convert CIDR to netmask
cidr_to_netmask() {
    local cidr="$1"
    local mask=""
    local full_octets=$((cidr / 8))
    local partial_octet=$((cidr % 8))
    
    for ((i=0; i<4; i++)); do
        if [[ $i -lt $full_octets ]]; then
            mask="${mask}255"
        elif [[ $i -eq $full_octets ]]; then
            mask="${mask}$((256 - 2**(8-partial_octet)))"
        else
            mask="${mask}0"
        fi
        
        if [[ $i -lt 3 ]]; then
            mask="${mask}."
        fi
    done
    
    echo "$mask"
}

# Configure network mode (DHCP/Static)
configure_network_mode() {
    clear
    echo -e "\e[48;5;236m\e[97m           ⚙️  CONFIGURATION MODE RÉSEAU           \e[0m"
    
    local physical_interface=$(get_physical_interface)
    
    if [[ -z "$physical_interface" ]]; then
        echo -e "\n\e[1;31m❌ Aucune interface réseau physique détectée.\e[0m"
        return 1
    fi
    
    echo -e "\n\e[48;5;24m\e[97m  📝 INTERFACE SÉLECTIONNÉE  \e[0m"
    echo -e "\n    \e[90m🔌 Interface :\e[0m \e[1;36m$physical_interface\e[0m"
    
    local current_mode="Statique"
    if is_dhcp_enabled "$physical_interface"; then
        current_mode="DHCP"
    fi
    echo -e "    \e[90m⚙️  Mode actuel :\e[0m \e[1;36m$current_mode\e[0m"
    
    echo -e "\n\e[48;5;24m\e[97m  🔧 SÉLECTION DU MODE  \e[0m"
    echo -e "\e[90m┌─────┬─────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36m 1\e[0m  \e[90m│\e[0m \e[97mDHCP (automatique)\e[0m                      \e[90m│\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36m 2\e[0m  \e[90m│\e[0m \e[97mStatique (IP fixe)\e[0m                      \e[90m│\e[0m"
    echo -e "\e[90m└─────┴─────────────────────────────────────────────────┘\e[0m"
    
    echo -ne "\n\e[1;33mChoisissez le mode [1-2] : \e[0m"
    read -r MODE_CHOICE
    
    case $MODE_CHOICE in
        1)
            echo -e "\n\e[1;33m🔄 Configuration en mode DHCP...\e[0m"
            configure_dhcp_mode "$physical_interface"
            ;;
        2)
            echo -e "\n\e[1;33m📝 Mode statique sélectionné.\e[0m"
            echo -e "Redirection vers la configuration d'adresse IP..."
            sleep 2
            configure_ip_address
            ;;
        *)
            echo -e "\e[1;31m✗ Choix invalide\e[0m"
            ;;
    esac
}

# Configure DHCP mode
configure_dhcp_mode() {
    local interface="$1"
    
    echo -e "\n\e[1;31mATTENTION :\e[0m Cette modification peut couper la connexion réseau."
    echo -ne "\e[1;33mConfirmer le passage en mode DHCP ? [o/N] : \e[0m"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
        # Backup current configuration
        local backup_dir="/etc/network-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        
        if [[ -d /etc/netplan ]]; then
            cp -r /etc/netplan/* "$backup_dir/" 2>/dev/null || true
            configure_netplan_dhcp "$interface"
        elif [[ -f /etc/network/interfaces ]]; then
            cp /etc/network/interfaces "$backup_dir/"
            configure_interfaces_dhcp "$interface"
        fi
        
        echo -e "\e[1;32m✓ Configuration DHCP appliquée\e[0m"
        echo -e "\e[1;33mSauvegarde créée dans : $backup_dir\e[0m"
        
        log_action "INFO" "Configuration DHCP appliquée pour $interface"
        
        echo -ne "\n\e[1;33mRedémarrer les services réseau maintenant ? [o/N] : \e[0m"
        read -r RESTART
        if [[ "$RESTART" =~ ^[oOyY]$ ]]; then
            restart_network_services
        fi
    else
        echo -e "\e[1;33mConfiguration annulée.\e[0m"
    fi
}

# Configure Netplan for DHCP
configure_netplan_dhcp() {
    local interface="$1"
    local netplan_file="/etc/netplan/01-dhcp-config.yaml"
    
    cat > "$netplan_file" << EOF
network:
  version: 2
  ethernets:
    $interface:
      dhcp4: true
EOF
    
    netplan apply 2>/dev/null || echo -e "\e[1;33mRedémarrez les services réseau pour appliquer les changements\e[0m"
}

# Configure /etc/network/interfaces for DHCP
configure_interfaces_dhcp() {
    local interface="$1"
    
    # Supprimer l'ancienne configuration pour cette interface
    sed -i "/^auto $interface/,/^$/d" /etc/network/interfaces
    sed -i "/^iface $interface/,/^$/d" /etc/network/interfaces
    
    # Ajouter la configuration DHCP
    cat >> /etc/network/interfaces << EOF

auto $interface
iface $interface inet dhcp
EOF
}

# Configure SSH server
configure_ssh_server() {
    clear
    echo -e "\e[48;5;236m\e[97m           🔐 CONFIGURATION SERVEUR SSH           \e[0m"
    
    # Vérifier si SSH est installé
    if ! command -v sshd >/dev/null 2>&1; then
        echo -e "\n\e[1;31m❌ Le serveur SSH n'est pas installé.\e[0m"
        echo -ne "\e[1;33mInstaller le serveur SSH ? [o/N] : \e[0m"
        read -r INSTALL_SSH
        
        if [[ "$INSTALL_SSH" =~ ^[oOyY]$ ]]; then
            echo -e "\e[1;33m📦 Installation du serveur SSH...\e[0m"
            apt update && apt install -y openssh-server
        else
            return 0
        fi
    fi
    
    # Afficher l'état actuel
    echo -e "\n\e[48;5;24m\e[97m  📊 ÉTAT ACTUEL SSH  \e[0m"
    local ssh_status="Inactif"
    local ssh_color="\e[1;31m"
    
    if systemctl is-active ssh >/dev/null 2>&1 || systemctl is-active sshd >/dev/null 2>&1; then
        ssh_status="Actif"
        ssh_color="\e[1;32m"
    fi
    
    local ssh_port=$(grep -oP '^Port \K[0-9]+' /etc/ssh/sshd_config 2>/dev/null || echo "22")
    local root_login=$(grep -oP '^PermitRootLogin \K\w+' /etc/ssh/sshd_config 2>/dev/null || echo "yes")
    local password_auth=$(grep -oP '^PasswordAuthentication \K\w+' /etc/ssh/sshd_config 2>/dev/null || echo "yes")
    
    echo -e "\n    \e[90m🔐 Statut :\e[0m $ssh_color$ssh_status\e[0m"
    echo -e "    \e[90m🔗 Port :\e[0m \e[1;36m$ssh_port\e[0m"
    echo -e "    \e[90m👤 Connexion root :\e[0m \e[1;36m$root_login\e[0m"
    echo -e "    \e[90m🔑 Auth par mot de passe :\e[0m \e[1;36m$password_auth\e[0m"
    
    echo -e "\n\e[48;5;24m\e[97m  ⚙️  OPTIONS DE CONFIGURATION  \e[0m"
    echo -e "\e[90m┌─────┬─────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36m 1\e[0m  \e[90m│\e[0m \e[97mActiver/Désactiver connexion root\e[0m           \e[90m│\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36m 2\e[0m  \e[90m│\e[0m \e[97mActiver/Désactiver auth par mot de passe\e[0m    \e[90m│\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36m 3\e[0m  \e[90m│\e[0m \e[97mConfigurer les clés SSH\e[0m                    \e[90m│\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36m 4\e[0m  \e[90m│\e[0m \e[97mRedémarrer le service SSH\e[0m                  \e[90m│\e[0m"
    echo -e "\e[90m└─────┴─────────────────────────────────────────────────┘\e[0m"
    
    echo -ne "\n\e[1;33mChoisissez une option [1-4] ou 0 pour annuler : \e[0m"
    read -r SSH_CHOICE
    
    case $SSH_CHOICE in
        1) toggle_root_login ;;
        2) toggle_password_auth ;;
        3) configure_ssh_keys ;;
        4) restart_ssh_service ;;
        0) return 0 ;;
        *) echo -e "\e[1;31m✗ Choix invalide\e[0m" ;;
    esac
}

# Restart network services
restart_network_services() {
    echo -e "\n\e[1;33m🔄 Redémarrage des services réseau...\e[0m"
    
    # Essayer différents services selon le système
    if systemctl is-active systemd-networkd >/dev/null 2>&1; then
        systemctl restart systemd-networkd
        echo -e "\e[1;32m✓ systemd-networkd redémarré\e[0m"
    fi
    
    if systemctl is-active networking >/dev/null 2>&1; then
        systemctl restart networking
        echo -e "\e[1;32m✓ networking redémarré\e[0m"
    fi
    
    if systemctl is-active NetworkManager >/dev/null 2>&1; then
        systemctl restart NetworkManager
        echo -e "\e[1;32m✓ NetworkManager redémarré\e[0m"
    fi
    
    # Appliquer netplan si disponible
    if command -v netplan >/dev/null 2>&1; then
        netplan apply 2>/dev/null
        echo -e "\e[1;32m✓ Netplan appliqué\e[0m"
    fi
    
    log_action "INFO" "Services réseau redémarrés"
    echo -e "\e[1;32m✅ Services réseau redémarrés avec succès\e[0m"
}

# Configure SSH port
configure_ssh_port() {
    clear
    echo -e "\e[48;5;236m\e[97m           🔗 CONFIGURATION PORT SSH              \e[0m"
    
    local current_port=$(grep -oP '^Port \K[0-9]+' /etc/ssh/sshd_config 2>/dev/null || echo "22")
    
    echo -e "\n\e[48;5;24m\e[97m  📊 ÉTAT ACTUEL  \e[0m"
    echo -e "\n    \e[90m🔗 Port SSH actuel :\e[0m \e[1;36m$current_port\e[0m"
    
    echo -e "\n\e[1;33mNouveau port SSH (1-65535) :\e[0m"
    echo -ne "\e[1;36m→ \e[0m"
    read -r NEW_PORT
    
    if ! validate_port "$NEW_PORT"; then
        echo -e "\e[1;31m✗ Port invalide\e[0m"
        return 1
    fi
    
    if [[ "$NEW_PORT" == "$current_port" ]]; then
        echo -e "\e[1;33m⚠️  Le port est déjà configuré sur $NEW_PORT\e[0m"
        return 0
    fi
    
    echo -e "\n\e[1;31mATTENTION :\e[0m Changer le port SSH peut couper votre connexion actuelle."
    echo -e "Assurez-vous de pouvoir accéder au serveur par un autre moyen."
    echo -ne "\e[1;33mConfirmer le changement de port vers $NEW_PORT ? [o/N] : \e[0m"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
        # Backup de la configuration
        cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.backup-$(date +%Y%m%d-%H%M%S)"
        
        # Modifier le port
        if grep -q "^Port " /etc/ssh/sshd_config; then
            sed -i "s/^Port .*/Port $NEW_PORT/" /etc/ssh/sshd_config
        else
            echo "Port $NEW_PORT" >> /etc/ssh/sshd_config
        fi
        
        # Tester la configuration
        if sshd -t; then
            echo -e "\e[1;32m✓ Configuration SSH valide\e[0m"
            
            # Redémarrer SSH
            if systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; then
                echo -e "\e[1;32m✓ Service SSH redémarré sur le port $NEW_PORT\e[0m"
                log_action "INFO" "Port SSH changé de $current_port vers $NEW_PORT"
            else
                echo -e "\e[1;31m✗ Erreur lors du redémarrage SSH\e[0m"
            fi
        else
            echo -e "\e[1;31m✗ Configuration SSH invalide, restauration...\e[0m"
            cp "/etc/ssh/sshd_config.backup-$(date +%Y%m%d-%H%M%S)" /etc/ssh/sshd_config
        fi
    else
        echo -e "\e[1;33mChangement annulé.\e[0m"
    fi
}

# Toggle SSH service
toggle_ssh_service() {
    clear
    echo -e "\e[48;5;236m\e[97m           🔐 GESTION SERVICE SSH                 \e[0m"
    
    local ssh_status="Inactif"
    local ssh_color="\e[1;31m"
    local ssh_service="ssh"
    
    # Détecter le nom du service SSH
    if systemctl is-active sshd >/dev/null 2>&1; then
        ssh_service="sshd"
        ssh_status="Actif"
        ssh_color="\e[1;32m"
    elif systemctl is-active ssh >/dev/null 2>&1; then
        ssh_service="ssh"
        ssh_status="Actif"
        ssh_color="\e[1;32m"
    fi
    
    echo -e "\n\e[48;5;24m\e[97m  📊 ÉTAT ACTUEL  \e[0m"
    echo -e "\n    \e[90m🔐 Service SSH :\e[0m $ssh_color$ssh_status\e[0m"
    echo -e "    \e[90m⚙️  Service :\e[0m \e[1;36m$ssh_service\e[0m"
    
    if [[ "$ssh_status" == "Actif" ]]; then
        echo -e "\n\e[1;31mATTENTION :\e[0m Désactiver SSH coupera toutes les connexions SSH actuelles."
        echo -ne "\e[1;33mDésactiver le service SSH ? [o/N] : \e[0m"
        read -r CONFIRM
        
        if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
            systemctl stop "$ssh_service"
            systemctl disable "$ssh_service"
            echo -e "\e[1;32m✓ Service SSH désactivé\e[0m"
            log_action "WARNING" "Service SSH désactivé"
        fi
    else
        echo -ne "\n\e[1;33mActiver le service SSH ? [o/N] : \e[0m"
        read -r CONFIRM
        
        if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
            systemctl enable "$ssh_service"
            systemctl start "$ssh_service"
            echo -e "\e[1;32m✓ Service SSH activé\e[0m"
            log_action "INFO" "Service SSH activé"
        fi
    fi
}

# Toggle root login
toggle_root_login() {
    local current_setting=$(grep -oP '^PermitRootLogin \K\w+' /etc/ssh/sshd_config 2>/dev/null || echo "yes")
    
    echo -e "\n\e[1;33m📊 Configuration actuelle :\e[0m PermitRootLogin $current_setting"
    
    if [[ "$current_setting" == "yes" ]]; then
        echo -ne "\e[1;33mDésactiver la connexion root via SSH ? [o/N] : \e[0m"
        read -r CONFIRM
        if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
            sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
            echo -e "\e[1;32m✓ Connexion root désactivée\e[0m"
        fi
    else
        echo -ne "\e[1;33mActiver la connexion root via SSH ? [o/N] : \e[0m"
        read -r CONFIRM
        if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
            sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
            echo -e "\e[1;32m✓ Connexion root activée\e[0m"
        fi
    fi
    
    restart_ssh_service
}

# Toggle password authentication
toggle_password_auth() {
    local current_setting=$(grep -oP '^PasswordAuthentication \K\w+' /etc/ssh/sshd_config 2>/dev/null || echo "yes")
    
    echo -e "\n\e[1;33m📊 Configuration actuelle :\e[0m PasswordAuthentication $current_setting"
    
    if [[ "$current_setting" == "yes" ]]; then
        echo -e "\e[1;31mATTENTION :\e[0m Désactiver l'authentification par mot de passe nécessite des clés SSH configurées."
        echo -ne "\e[1;33mDésactiver l'authentification par mot de passe ? [o/N] : \e[0m"
        read -r CONFIRM
        if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
            sed -i 's/^PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
            echo -e "\e[1;32m✓ Authentification par mot de passe désactivée\e[0m"
        fi
    else
        echo -ne "\e[1;33mActiver l'authentification par mot de passe ? [o/N] : \e[0m"
        read -r CONFIRM
        if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
            sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
            echo -e "\e[1;32m✓ Authentification par mot de passe activée\e[0m"
        fi
    fi
    
    restart_ssh_service
}

# Configure SSH keys
configure_ssh_keys() {
    echo -e "\n\e[1;33m🔑 Configuration des clés SSH\e[0m"
    echo -e "Cette fonctionnalité permettra de gérer les clés SSH autorisées."
    echo -e "\e[1;33mFonctionnalité en cours de développement...\e[0m"
    
    # TODO: Implémenter la gestion des clés SSH
    # - Afficher les clés autorisées
    # - Ajouter une nouvelle clé
    # - Supprimer une clé
    # - Générer une nouvelle paire de clés
}

# Restart SSH service
restart_ssh_service() {
    echo -e "\n\e[1;33m🔄 Redémarrage du service SSH...\e[0m"
    
    if systemctl restart ssh 2>/dev/null; then
        echo -e "\e[1;32m✓ Service SSH redémarré (ssh)\e[0m"
    elif systemctl restart sshd 2>/dev/null; then
        echo -e "\e[1;32m✓ Service SSH redémarré (sshd)\e[0m"
    else
        echo -e "\e[1;31m✗ Erreur lors du redémarrage SSH\e[0m"
    fi
}

# ═══════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Validate port number
validate_port() {
    local port="$1"
    
    # Vérifier que c'est un nombre
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    # Vérifier la plage
    if [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
        return 1
    fi
    
    return 0
}

# Validate IP address
validate_ip() {
    local ip="$1"
    local valid_ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if ! [[ "$ip" =~ $valid_ip_regex ]]; then
        return 1
    fi
    
    IFS='.' read -ra OCTETS <<< "$ip"
    for octet in "${OCTETS[@]}"; do
        if [[ "$octet" -gt 255 ]]; then
            return 1
        fi
    done
    
    return 0
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
