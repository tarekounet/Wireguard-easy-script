#!/bin/bash
# Sourcing de tous les modules
source "$(dirname "$0")/lib_admin/ssh.sh"
source "$(dirname "$0")/lib_admin/user_management.sh"
source "$(dirname "$0")/lib_admin/power.sh"
source "$(dirname "$0")/lib_admin/user.sh"
source "$(dirname "$0")/lib_admin/network.sh"
source "$(dirname "$0")/lib_admin/maintenance.sh"
source "$(dirname "$0")/lib_admin/docker.sh"
source "$(dirname "$0")/lib_admin/utils.sh"
VERSION_LOCAL="$(head -n1 version.txt | tr -d '\n\r ')"
# Fonction de mise à jour automatique du script principal
auto_update_admin_menu() {
        # Synchronisation directe de version.txt et admin_menu.sh
        for f in version.txt admin_menu.sh; do
            url="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/$f"
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL "$url" -o "$(dirname "$0")/$f"
            elif command -v wget >/dev/null 2>&1; then
                wget -q "$url" -O "$(dirname "$0")/$f"
            fi
        done
    local github_script_url="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/admin_menu.sh"
    local github_libadmin_url="https://github.com/tarekounet/Wireguard-easy-script/archive/refs/heads/main.zip"
    local local_version_file="version.txt"
    local latest_version=""
    # Récupérer la dernière version sur GitHub
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -fsSL --connect-timeout 5 "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/version.txt" | head -n1 | tr -d '\n\r ')
    elif command -v wget >/dev/null 2>&1; then
        latest_version=$(wget -qO- "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/version.txt" | head -n1 | tr -d '\n\r ')
    fi
    local current_version="$VERSION_LOCAL"
    if [ -n "$latest_version" ] && [ "$latest_version" != "$current_version" ]; then
        echo -e "\033[1;33m[INFO] Une nouvelle version du script est disponible : $current_version → $latest_version\033[0m"
        # Mise à jour du script principal
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$github_script_url" -o "$0.tmp" && mv "$0.tmp" "$0" && chmod +x "$0"
        elif command -v wget >/dev/null 2>&1; then
            wget -q "$github_script_url" -O "$0.tmp" && mv "$0.tmp" "$0" && chmod +x "$0"
        fi
        # Synchronisation directe des fichiers du dossier lib_admin
        echo -e "\033[1;33mSynchronisation du dossier lib_admin...\033[0m"
        local lib_admin_files=(ssh.sh user_management.sh power.sh user.sh network.sh maintenance.sh docker.sh utils.sh)
        local lib_admin_dir="$(dirname "$0")/lib_admin"
        mkdir -p "$lib_admin_dir"
        for f in "${lib_admin_files[@]}"; do
            url="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/lib_admin/$f"
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL "$url" -o "$lib_admin_dir/$f"
            elif command -v wget >/dev/null 2>&1; then
                wget -q "$url" -O "$lib_admin_dir/$f"
            fi
        done
        echo "$latest_version" > "$local_version_file"
    echo -e "\033[1;32mScript et modules mis à jour. Redémarrage...\033[0m"
        exec bash "$0" "$@"
    else
    echo -e "\033[1;36m[INFO] Vous utilisez déjà la dernière version du script ($current_version).\033[0m"
    fi
}
# Gestion unifiée des paquets (APT)
execute_package_cmd() {
    local action="$1"
    shift
    case "$action" in
        "update") apt update ;;
        "upgrade") apt upgrade -y "$@" ;;
        "clean") apt autoclean && apt autoremove -y ;;
        "security") apt upgrade -y --security ;;
        "check") apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0" ;;
        *) echo -e "${COLORS[RED]}✗ Ce script nécessite APT (Debian uniquement)${COLORS[NC]}"; return 1 ;;
    esac
}
# Advanced Technical Administration Menu for Wireguard Environment
# Version: 0.19.0
# Author: Tarek.E
# Project: Wireguard Easy Script
# Repository: https://github.com/tarekounet/Wireguard-easy-script

set -euo pipefail


# Appel de la mise à jour automatique au lancement
auto_update_admin_menu "$@"

# Centralisation des couleurs
declare -A COLORS=(
    [RED]='\033[0;31m'
    [GREEN]='\033[0;32m'
    [YELLOW]='\033[1;33m'
    [BLUE]='\033[0;34m'
    [PURPLE]='\033[0;35m'
    [CYAN]='\033[0;36m'
    [WHITE]='\033[1;37m'
    [NC]='\033[0m'
)

color() {
    local c="$1"; shift
    echo -e "${COLORS[$c]}$*${COLORS[NC]}"
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
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 6\e[0m \e[97mFermer cette session SSH\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 7\e[0m \e[97mRedémarrer les services réseau\e[0m"
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
            6) close_current_ssh_session ;;
            7) restart_network_services ;;
            0) break ;;
            *)
                echo -e "\e[1;31mChoix invalide.\e[0m"                ;;
        esac
        
    # ...rien à afficher ici...
    done
}

# Display current network information
display_current_network_info() {
    local physical_interface=$(get_physical_interface)
    
    if [[ -n "$physical_interface" ]]; then
        local ip_address=$(ip addr show "$physical_interface" | grep -oP 'inet \K[^/]+' | head -1)
    local netmask_cidr=$(ip addr show "$physical_interface" | grep -oP 'inet [^/]+/\K[0-9]+' | head -1)
    local netmask="$(cidr_to_netmask "$netmask_cidr")"
        local gateway=$(ip route | grep default | grep "$physical_interface" | awk '{print $3}' | head -1)
        local mac_address=$(ip link show "$physical_interface" | grep -oP 'link/ether \K[^ ]+')
        local link_status=$(ip link show "$physical_interface" | grep -oP 'state \K[A-Z]+')
        
        echo -e "\n    \e[90m🔌 Interface :\e[0m \e[1;36m$physical_interface\e[0m \e[90m($link_status)\e[0m"
        echo -e "    \e[90m🌐 Adresse IP :\e[0m \e[1;36m${ip_address:-Non configurée}\e[0m"
    echo -e "    \e[90m📊 Masque :\e[0m \e[1;36m${netmask:-Non défini}\e[0m"
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
    
    # ...rien à afficher ici...
    echo -e "    \e[90m🔐 SSH :\e[0m $ssh_color$ssh_status\e[0m \e[90m(Port: $ssh_port)\e[0m"
}

# Immediate reboot
immediate_reboot() {
    clear
    echo -e "${COLORS[RED]}═══ REDÉMARRAGE IMMÉDIAT ═══${COLORS[NC]}"
    echo -e "${COLORS[RED]}ATTENTION : Le système va redémarrer immédiatement !${COLORS[NC]}"
    echo -ne "${COLORS[WHITE]}Confirmer le redémarrage ? [o/N] : ${COLORS[NC]}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
    echo -e "${COLORS[RED]}Redémarrage en cours...${COLORS[NC]}"
        shutdown -r now
    else
    echo -e "${COLORS[YELLOW]}Redémarrage annulé.${COLORS[NC]}"
    fi
}

# Immediate shutdown
immediate_shutdown() {
    clear
    echo -e "${COLORS[RED]}═══ ARRÊT IMMÉDIAT ═══${COLORS[NC]}"
    echo -e "${COLORS[RED]}ATTENTION : Le système va s'arrêter immédiatement !${COLORS[NC]}"
    echo -ne "${COLORS[WHITE]}Confirmer l'arrêt ? [o/N] : ${COLORS[NC]}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
    echo -e "${COLORS[RED]}Arrêt en cours...${COLORS[NC]}"
        shutdown -h now
    else
    echo -e "${COLORS[YELLOW]}Arrêt annulé.${COLORS[NC]}"
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
    
    # Vérifier dans /etc/network/interfaces (Debian)
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
    
    if ! validate_input "ip" "$NEW_IP"; then
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
    
    if ! validate_input "ip" "$GATEWAY"; then
        echo -e "\e[1;31m✗ Adresse de passerelle invalide\e[0m"
        return 1
    fi
    
    echo -e "\n\e[1;33mServeur DNS primaire (optionnel, Entrée pour ignorer) :\e[0m"
    echo -ne "\e[1;36m→ \e[0m"
    read -r DNS1
    
    if [[ -n "$DNS1" ]] && ! validate_input "ip" "$DNS1"; then
        echo -e "\e[1;31m✗ Adresse DNS invalide\e[0m"
        return 1
    fi
    
    # Confirmation
    echo -e "\n\e[1;33m📋 RÉCAPITULATIF DE LA CONFIGURATION :\e[0m"
    echo -e "\e[90m┌─────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36mInterface :\e[0m $physical_interface"
    echo -e "\e[90m│\e[0m \e[1;36mAdresse IP :\e[0m $NEW_IP ($(cidr_to_netmask "$NETMASK"))"
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
    if [[ -f /etc/network/interfaces ]]; then
        cp /etc/network/interfaces "$backup_dir/"
        configure_interfaces "$interface" "$ip" "$netmask" "$gateway" "$dns"
    else
        echo -e "\e[1;31m✗ Système de configuration réseau non reconnu (Debian uniquement)\e[0m"
        return 1
    fi
    
    echo -e "\e[1;32m✓ Configuration appliquée\e[0m"
    echo -e "\e[1;33mSauvegarde créée dans : $backup_dir\e[0m"
    
    
    echo -ne "\n\e[1;33mRedémarrer les services réseau maintenant ? [o/N] : \e[0m"
    read -r RESTART
    if [[ "$RESTART" =~ ^[oOyY]$ ]]; then
        restart_network_services
    fi
}

# Configure /etc/network/interfaces (Debian)
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
            echo -e "Redirection vers la configuration d'adresse IP..."            configure_ip_address
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
        
        if [[ -f /etc/network/interfaces ]]; then
            cp /etc/network/interfaces "$backup_dir/"
            configure_interfaces_dhcp "$interface"
        else
            echo -e "\e[1;31m✗ Système de configuration réseau non reconnu (Debian uniquement)\e[0m"
            return 1
        fi
        
        echo -e "\e[1;32m✓ Configuration DHCP appliquée\e[0m"
        echo -e "\e[1;33mSauvegarde créée dans : $backup_dir\e[0m"
        
        
        echo -ne "\n\e[1;33mRedémarrer les services réseau maintenant ? [o/N] : \e[0m"
        read -r RESTART
        if [[ "$RESTART" =~ ^[oOyY]$ ]]; then
            restart_network_services
        fi
    else
        echo -e "\e[1;33mConfiguration annulée.\e[0m"
    fi
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
    
    echo -e "\e[1;32m✅ Services réseau redémarrés avec succès\e[0m"
}

# Change hostname
change_hostname() {
    clear
    echo -e "\e[48;5;236m\e[97m           🏷️  CHANGER LE NOM DE LA MACHINE         \e[0m"
    
    # Afficher le nom actuel
    local current_hostname=$(hostname)
    echo -e "\n\e[48;5;24m\e[97m  📊 INFORMATIONS ACTUELLES  \e[0m"
    echo -e "\n    \e[90m🏷️  Nom actuel :\e[0m \e[1;36m$current_hostname\e[0m"
    echo -e "    \e[90m🌐 FQDN :\e[0m \e[1;36m$(hostname -f 2>/dev/null || echo "Non configuré")\e[0m"
    
    echo -e "\n\e[48;5;22m\e[97m  ⚙️  NOUVEAU NOM DE MACHINE  \e[0m"
    echo -e "\n\e[1;33mRègles pour le nom de machine :\e[0m"
    echo -e "\e[90m  • Longueur : 1-63 caractères\e[0m"
    echo -e "\e[90m  • Caractères autorisés : lettres, chiffres, tirets\e[0m"
    echo -e "\e[90m  • Commence et finit par une lettre ou un chiffre\e[0m"
    echo -e "\e[90m  • Tapez 'annuler' pour revenir au menu\e[0m"
    
    while true; do
        echo -ne "\n\e[1;33mNouveau nom de machine : \e[0m\e[1;36m→ \e[0m"
        read -r NEW_HOSTNAME
        
        # Option d'annulation
        if [[ "$NEW_HOSTNAME" == "annuler" || "$NEW_HOSTNAME" == "cancel" || "$NEW_HOSTNAME" == "exit" ]]; then
            echo -e "\e[1;33m❌ Changement de nom annulé\e[0m"
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
            return
        fi
        
        # Validation du nom
        if [[ -z "$NEW_HOSTNAME" ]]; then
            echo -e "\e[1;31m✗ Le nom ne peut pas être vide\e[0m"
            continue
        fi
        
        if [[ ${#NEW_HOSTNAME} -gt 63 ]]; then
            echo -e "\e[1;31m✗ Le nom est trop long (maximum 63 caractères)\e[0m"
            continue
        fi
        
        if ! [[ "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
            echo -e "\e[1;31m✗ Format invalide\e[0m"
            echo -e "\e[90m  Utilisez uniquement : lettres, chiffres, tirets\e[0m"
            echo -e "\e[90m  Commence et finit par une lettre ou un chiffre\e[0m"
            continue
        fi
        
        if [[ "$NEW_HOSTNAME" == "$current_hostname" ]]; then
            echo -e "\e[1;33m⚠️  Le nom est identique au nom actuel\e[0m"
            continue
        fi
        
        # Confirmation
        echo -e "\n\e[1;32m✓ Nom valide : $NEW_HOSTNAME\e[0m"
        echo -e "\n\e[48;5;52m\e[97m  ⚠️  CONFIRMATION  \e[0m"
        echo -e "\n\e[1;31m⚠️  ATTENTION :\e[0m"
        echo -e "    \e[97m• Le changement de nom nécessite un redémarrage\e[0m"
        echo -e "    \e[97m• Certains services peuvent être affectés\e[0m"
        echo -e "    \e[97m• Les connexions réseau actuelles seront interrompues\e[0m"
        
        echo -e "\n\e[1;33mConfirmer le changement ? [o/N/retour] : \e[0m"
        read -r CONFIRM
        
        case "$CONFIRM" in
            [oOyY])
                echo -e "\n\e[1;33m🔄 Application du nouveau nom...\e[0m"
                
                # Changer le hostname
                if hostnamectl set-hostname "$NEW_HOSTNAME" 2>/dev/null; then
                    echo -e "\e[1;32m✓ hostnamectl configuré\e[0m"
                else
                    echo "$NEW_HOSTNAME" > /etc/hostname
                    hostname "$NEW_HOSTNAME"
                    echo -e "\e[1;32m✓ /etc/hostname mis à jour\e[0m"
                fi
                
                # Mettre à jour /etc/hosts
                echo -e "\e[1;33m🔄 Mise à jour de /etc/hosts...\e[0m"
                cp /etc/hosts "/etc/hosts.backup-$(date +%Y%m%d-%H%M%S)"
                
                # Supprimer les anciennes entrées
                sed -i "/127.0.0.1.*$current_hostname/d" /etc/hosts
                sed -i "/127.0.1.1.*$current_hostname/d" /etc/hosts
                
                # Ajouter les nouvelles entrées
                if ! grep -q "127.0.0.1.*$NEW_HOSTNAME" /etc/hosts; then
                    echo "127.0.0.1 $NEW_HOSTNAME" >> /etc/hosts
                fi
                if ! grep -q "127.0.1.1.*$NEW_HOSTNAME" /etc/hosts; then
                    echo "127.0.1.1 $NEW_HOSTNAME" >> /etc/hosts
                fi
                
                echo -e "\e[1;32m✓ /etc/hosts mis à jour\e[0m"
                
                # Vérification
                local new_name=$(hostname)
                if [[ "$new_name" == "$NEW_HOSTNAME" ]]; then
                    echo -e "\n\e[1;32m✅ NOM DE MACHINE CHANGÉ AVEC SUCCÈS\e[0m"
                    echo -e "\e[90m┌─────────────────────────────────────────────────┐\e[0m"
                    echo -e "\e[90m│\e[0m \e[1;36mAncien nom :\e[0m $current_hostname"
                    echo -e "\e[90m│\e[0m \e[1;36mNouveau nom :\e[0m $NEW_HOSTNAME"
                    echo -e "\e[90m│\e[0m \e[1;36mStatut :\e[0m \e[1;32mAppliqué\e[0m"
                    echo -e "\e[90m└─────────────────────────────────────────────────┘\e[0m"
                    
                    
                    echo -e "\n\e[1;33m⚠️  REDÉMARRAGE RECOMMANDÉ\e[0m"
                    echo -e "Pour que tous les services prennent en compte le nouveau nom,"
                    echo -e "un redémarrage du système est recommandé."
                    
                    echo -ne "\n\e[1;33mRedémarrer maintenant ? [o/N] : \e[0m"
                    read -r REBOOT_NOW
                    if [[ "$REBOOT_NOW" =~ ^[oOyY]$ ]]; then
                        echo -e "\e[1;31m🔄 Redémarrage en cours...\e[0m"                        shutdown -r now
                    fi
                else
                    echo -e "\e[1;31m❌ Erreur lors du changement de nom\e[0m"
                fi
                
                echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                read -n1 -s
                return
                ;;
            [rR]|retour)
                continue
                ;;
            *)
                echo -e "\e[1;33m❌ Changement de nom annulé\e[0m"
                echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                read -n1 -s
                return
                ;;
        esac
    done
}

# ═══════════════════════════════════════════════════════════════
# DOCKER INSTALLATION AND VERIFICATION
# ═══════════════════════════════════════════════════════════════

# Check and install Docker if needed
check_and_install_docker() {
    clear
    echo -e "\e[48;5;236m\e[97m           🐳 VÉRIFICATION DES PRÉREQUIS SYSTÈME           \e[0m"

    echo -e "\n\e[1;33m🔍 Vérification de l'installation Docker, zip et unzip...\e[0m"

    # Vérifier zip
    if ! command -v zip &>/dev/null; then
        echo -e "\e[1;31m❌ zip n'est pas installé\e[0m"
        echo -e "\e[1;33mInstallation de zip...\e[0m"
        apt-get update && apt-get install -y zip
    else
        echo -e "\e[1;32m✓ zip est déjà installé\e[0m"
    fi

    # Vérifier unzip
    if ! command -v unzip &>/dev/null; then
        echo -e "\e[1;31m❌ unzip n'est pas installé\e[0m"
        echo -e "\e[1;33mInstallation de unzip...\e[0m"
        apt-get update && apt-get install -y unzip
    else
        echo -e "\e[1;32m✓ unzip est déjà installé\e[0m"
    fi

    # Vérifier si Docker est installé
    if command -v docker &>/dev/null; then
        echo -e "\e[1;32m✓ Docker est déjà installé\e[0m"

        # Vérifier si Docker Compose est installé
        if command -v docker-compose &>/dev/null || docker compose version &>/dev/null; then
            echo -e "\e[1;32m✓ Docker Compose est déjà installé\e[0m"

            # Vérifier si le service Docker est actif
            if systemctl is-active docker &>/dev/null; then
                echo -e "\e[1;32m✓ Service Docker est actif\e[0m"
                echo -e "\n\e[1;32m🎉 Docker est prêt à être utilisé !\e[0m"
                return 0
            else
                echo -e "\e[1;33m⚠️  Service Docker inactif, démarrage...\e[0m"
                systemctl start docker
                systemctl enable docker
                echo -e "\e[1;32m✓ Service Docker démarré\e[0m"
                return 0
            fi
        else
            echo -e "\e[1;33m⚠️  Docker Compose manquant, installation...\e[0m"
            # Docker Compose legacy supprimé
        fi
    else
        echo -e "\e[1;31m❌ Docker n'est pas installé\e[0m"
        echo -e "\n\e[1;33m🚀 Lancement de l'installation Docker...\e[0m"
        check_and_install_docker
    fi
}

# Install Docker
install_docker() {
    echo -e "\n\e[48;5;24m\e[97m  📦 INSTALLATION DOCKER (DEBIAN)  \e[0m"
    
    echo -e "\n\e[1;33m📝 Étape 1/8 - Mise à jour des paquets...\e[0m"
    apt-get update || { echo -e "\e[1;31m❌ Échec de la mise à jour\e[0m"; return 1; }
    
    echo -e "\n\e[1;33m📝 Étape 2/8 - Vérification des mises à jour système...\e[0m"
    echo -e "\e[1;36m🔍 Recherche des mises à jour disponibles...\e[0m"
    UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
    if [[ "$UPGRADABLE" -gt 0 ]]; then
        echo -e "\e[1;33m⚠️  $UPGRADABLE paquets peuvent être mis à jour\e[0m"
        echo -ne "\e[1;33mEffectuer les mises à jour système maintenant ? [o/N] : \e[0m"
        read -r UPDATE_SYSTEM
        if [[ "$UPDATE_SYSTEM" =~ ^[oOyY]$ ]]; then
            echo -e "\e[1;33m🔄 Mise à jour du système en cours...\e[0m"
            apt-get upgrade -y || echo -e "\e[1;33m⚠️  Certaines mises à jour ont échoué, continuons...\e[0m"
            echo -e "\e[1;32m✓ Mises à jour système terminées\e[0m"
        else
            echo -e "\e[1;33m⏭️  Mises à jour système ignorées\e[0m"
        fi
    else
        echo -e "\e[1;32m✓ Système déjà à jour\e[0m"
    fi
    
    echo -e "\n\e[1;33m📝 Étape 3/8 - Installation des outils essentiels...\e[0m"
    echo -e "\e[1;36m🔧 Installation de vim et sudo...\e[0m"
    apt-get install -y vim sudo || { echo -e "\e[1;31m❌ Échec installation outils essentiels\e[0m"; return 1; }
    echo -e "\e[1;32m✓ vim et sudo installés\e[0m"
    
    echo -e "\n\e[1;33m📝 Étape 4/8 - Installation des prérequis Docker...\e[0m"
    apt-get install -y ca-certificates curl || { echo -e "\e[1;31m❌ Échec installation prérequis\e[0m"; return 1; }
    
    echo -e "\n\e[1;33m📝 Étape 5/8 - Configuration des clés GPG...\e[0m"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc || { echo -e "\e[1;31m❌ Échec téléchargement clé GPG\e[0m"; return 1; }
    chmod a+r /etc/apt/keyrings/docker.asc
    
    echo -e "\n\e[1;33m📝 Étape 6/8 - Ajout du dépôt Docker...\e[0m"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo -e "\e[1;31m❌ Échec ajout dépôt\e[0m"; return 1; }
    
    echo -e "\n\e[1;33m📝 Étape 7/8 - Mise à jour avec le nouveau dépôt...\e[0m"
    apt-get update || { echo -e "\e[1;31m❌ Échec mise à jour dépôt\e[0m"; return 1; }
    
    echo -e "\n\e[1;33m📝 Étape 8/8 - Installation Docker...\e[0m"
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || {
        echo -e "\e[1;31m❌ Échec installation Docker\e[0m"
        return 1
    }
    
    echo -e "\n\e[1;33m🔧 Configuration du service Docker...\e[0m"
    systemctl start docker
    systemctl enable docker
    
    echo -e "\n\e[1;33m🧪 Test de l'installation...\e[0m"
    if docker --version && docker compose version; then
        echo -e "\n\e[1;32m✅ DOCKER INSTALLÉ AVEC SUCCÈS !\e[0m"
        echo -e "\e[90m┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m│\e[0m \e[1;36mDocker :\e[0m $(docker --version | cut -d' ' -f3 | tr -d ',')"
        echo -e "\e[90m│\e[0m \e[1;36mDocker Compose :\e[0m $(docker compose version --short 2>/dev/null || echo "Plugin intégré")"
        echo -e "\e[90m│\e[0m \e[1;36mStatut :\e[0m \e[1;32mActif et prêt\e[0m"
        echo -e "\e[90m└─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
        return 0
    else
        echo -e "\e[1;31m❌ L'installation semble avoir échoué\e[0m"
        return 1
    fi
}
# ═══════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════

# Check if running as root   
# Mise à jour automatique du script
## Appel à auto_update_admin_menu supprimé (fonction absente)

source "$(dirname "$0")/lib_admin/power.sh"
echo -e "\e[1;33mVérification de la version du script...\e[0m"
local_version="$(head -n1 version.txt 2>/dev/null | tr -d '\n\r ')"
# Vérification de la connexion Internet avant la mise à jour
if ping -c 1 -W 1 github.com >/dev/null 2>&1; then
    github_version="$(curl -fsSL --connect-timeout 5 https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/version.txt | head -n1 | tr -d '\n\r ')"
    echo -e "\e[1;36mVersion locale : $local_version\e[0m"
    echo -e "\e[1;36mVersion disponible sur GitHub : $github_version\e[0m"
    sleep 1
    auto_update_admin_menu "$@"
else
    echo -e "\e[1;33mConnexion Internet indisponible : étape de mise à jour ignorée.\e[0m"
    sleep 1
fi
echo -e "\e[1;33mVérification des prérequis système...\e[0m"
check_and_install_docker
sleep 2
technical_admin_menu() {
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m                                                    \e[0m"
        echo -e "\e[48;5;236m\e[97m           🔧 ADMINISTRATION TECHNIQUE              \e[0m"
        echo -e "\e[48;5;236m\e[97m                                                    \e[0m"
        echo -e "\n\e[48;5;237m\e[97m            📊 INFORMATIONS SYSTÈME              \e[0m"
    echo -e "\n    \e[90m🖥️  Système :\e[0m \e[1;36mDebian $(cat /etc/debian_version 2>/dev/null || echo 'GNU/Linux')\e[0m"
    echo -e "    \e[90m⏱️  Uptime :\e[0m \e[1;32m$(uptime -p 2>/dev/null || echo 'Non disponible')\e[0m"
    echo -e "    \e[90m🌐 IP actuelle :\e[0m \e[1;36m$(hostname -I | awk '{print $1}')\e[0m"
        echo -e "\n\e[48;5;24m\e[97m  👥 GESTION DES UTILISATEURS  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 1\e[0m \e[97mGestion des utilisateurs\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        echo -e "\n\e[48;5;94m\e[97m  🐳 GESTION DOCKER  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 2\e[0m \e[97mRAZ Docker-WireGuard utilisateur\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        echo -e "\n\e[48;5;22m\e[97m  🔄 MAINTENANCE SYSTÈME  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m    ├─ \e[0m\e[1;36m 3\e[0m \e[97mMettre à jour le système\e[0m"
    echo -e "\e[90m    ├─ \e[0m\e[1;36m 4\e[0m \e[97mConfiguration réseau et SSH\e[0m"
    echo -e "\e[90m    ├─ \e[0m\e[1;36m 5\e[0m \e[97mChanger le nom de la machine\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        echo -e "\n\e[48;5;52m\e[97m  ⚡ GESTION ALIMENTATION  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m    ├─ \e[0m\e[1;36m 6\e[0m \e[97mRedémarrer le système\e[0m"
    echo -e "\e[90m    ├─ \e[0m\e[1;36m 7\e[0m \e[97mArrêter le système\e[0m"
    echo -e "\e[90m    ├─ \e[0m\e[1;36m 8\e[0m \e[97mProgrammer un redémarrage/arrêt\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;31m 0\e[0m \e[97mOptions de sortie\e[0m \e[1;31m🚪\e[0m"
    echo -e "\e[90m    └─────────────────────────────────────────────────\e[0m"
    VERSION_DISPLAY=$(head -n1 version.txt 2>/dev/null | tr -d '\n\r ')
    echo -e "\n\e[90m    Tarek.E • v$VERSION_DISPLAY\e[0m"
        echo -ne "\n\e[1;33mEntrez votre choix : \e[0m"
        read -r CHOICE
            case $CHOICE in
                1) user_management_menu ;;
                2) reset_user_docker_wireguard ;;
                3) full_system_update ;;
                4) network_ssh_config_menu ;;
                5) change_hostname ;;
                6) immediate_reboot ;;
                7) immediate_shutdown ;;
                8) power_scheduling_menu ;;
                0)
                clear
                echo -e "${COLORS[YELLOW]}═══════════════════════════════════════════════════════════${COLORS[NC]}"
                echo -e "${COLORS[CYAN]}                🚪 OPTIONS DE SORTIE${COLORS[NC]}"
                echo -e "${COLORS[YELLOW]}═══════════════════════════════════════════════════════════${COLORS[NC]}"
                echo -e "${COLORS[WHITE]}  [1]${COLORS[NC]} Quitter le script"
                if [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" ]]; then
                    echo -e "${COLORS[WHITE]}  [2]${COLORS[NC]} Fermer la session SSH en cours"
                else
                    echo -e "${COLORS[WHITE]}  [2]${COLORS[NC]} Fermer la session locale"
                fi
                echo -e "${COLORS[WHITE]}  [0]${COLORS[NC]} Retour au menu principal"
                echo -ne "\n${COLORS[YELLOW]}Votre choix : ${COLORS[NC]}"
                read -r EXIT_CHOICE
                case $EXIT_CHOICE in
                    1)
                        echo -e "\e[1;32mAu revoir !\e[0m"
                        exit 0
                        ;;
                    2)
                        if [[ -n "${SSH_CLIENT:-}" || -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" ]]; then
                            echo -e "\e[1;32mFermeture de la session SSH...\e[0m"
                            sleep 1
                            kill -HUP $$
                        else
                            echo -e "\e[1;31mVous n'êtes pas en session SSH.\e[0m"
                        fi
                        ;;
                    0)
                        echo -e "\e[1;32mRetour au menu principal...\e[0m"
                        break
                        ;;
                    *)
                        echo -e "\e[1;31mChoix invalide. Retour au menu principal.\e[0m"
                        ;;
                esac
                ;;
            *) echo -e "\e[1;31mChoix invalide. Veuillez saisir un numéro entre 0 et 10.\e[0m" ;;
        esac

    done
}

while true; do
    technical_admin_menu
done
