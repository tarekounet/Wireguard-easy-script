#!/bin/bash
# Fonctions réseau avancées pour Wireguard-easy-script

get_physical_interface() {
    # Exclure les interfaces virtuelles communes
    local excluded_patterns="lo|docker|br-|veth|wg|tun|tap|virbr"
    local default_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -n "$default_interface" ]] && ! echo "$default_interface" | grep -qE "$excluded_patterns"; then
        echo "$default_interface"
        return 0
    fi
    local interface=$(ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print $2}' | grep -vE "$excluded_patterns" | head -1)
    echo "$interface"
}

is_dhcp_enabled() {
    local interface="$1"
    if [[ -f /etc/network/interfaces ]]; then
        if grep -A5 "iface $interface" /etc/network/interfaces | grep -q "dhcp"; then
            return 0
        fi
    fi
    if command -v nmcli >/dev/null 2>&1; then
        if nmcli device show "$interface" 2>/dev/null | grep -q "IP4.DHCP4.OPTION"; then
            return 0
        fi
    fi
    return 1
}

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
    echo -e "Tapez 'annuler' pour revenir au menu."
    echo -ne "\e[1;36m→ \e[0m"
    read -r NEW_IP
    if [[ "$NEW_IP" == "annuler" || "$NEW_IP" == "a" ]]; then
        echo -e "\e[1;33mAnnulation. Retour au menu...\e[0m"
        return 0
    fi
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

apply_static_ip_config() {
    local interface="$1"
    local ip="$2"
    local netmask="$3"
    local gateway="$4"
    local dns="$5"
    echo -e "\n\e[1;33m🔄 Application de la configuration...\e[0m"
    local backup_dir="/etc/network-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
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

configure_interfaces() {
    local interface="$1"
    local ip="$2"
    local netmask="$3"
    local gateway="$4"
    local dns="$5"
    sed -i "/^auto $interface/,/^$/d" /etc/network/interfaces
    sed -i "/^iface $interface/,/^$/d" /etc/network/interfaces
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

configure_dhcp_mode() {
    local interface="$1"
    echo -e "\n\e[1;31mATTENTION :\e[0m Cette modification peut couper la connexion réseau."
    echo -ne "\e[1;33mConfirmer le passage en mode DHCP ? [o/N] : \e[0m"
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
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

configure_interfaces_dhcp() {
    local interface="$1"
    sed -i "/^auto $interface/,/^$/d" /etc/network/interfaces
    sed -i "/^iface $interface/,/^$/d" /etc/network/interfaces
    cat >> /etc/network/interfaces << EOF

auto $interface
iface $interface inet dhcp
EOF
}

restart_network_services() {
    echo -e "\n\e[1;33m🔄 Redémarrage des services réseau...\e[0m"
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

change_hostname() {
    local current_hostname
    current_hostname=$(hostname)
    echo -e "\e[48;5;236m\e[97m           🏷️  CHANGER LE NOM DE LA MACHINE         \e[0m"
    echo -e "\n\e[1;36mNom actuel : $current_hostname\e[0m"
    while true; do
        echo -ne "\n\e[1;33mNouveau nom de machine (ou 0 pour retour) : \e[0m\e[1;36m→ \e[0m"
        read -r new_hostname
        if [[ "$new_hostname" == "0" ]]; then
            echo -e "\e[1;33mRetour au menu précédent.\e[0m"
            break
        fi
        if [[ -z "$new_hostname" ]]; then
            echo -e "\e[1;31m✗ Le nom ne peut pas être vide\e[0m"
            continue
        fi
        if [[ ${#new_hostname} -gt 63 ]]; then
            echo -e "\e[1;31m✗ Le nom est trop long (maximum 63 caractères)\e[0m"
            continue
        fi
        if ! [[ "$new_hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
            echo -e "\e[1;31m✗ Format invalide\e[0m"
            echo -e "\e[90m  Utilisez uniquement : lettres, chiffres, tirets\e[0m"
            echo -e "\e[90m  Commence et finit par une lettre ou un chiffre\e[0m"
            continue
        fi
        if [[ "$new_hostname" == "$current_hostname" ]]; then
            echo -e "\e[1;33m⚠️  Le nom est identique au nom actuel\e[0m"
            continue
        fi
        echo -ne "\n\e[1;33mConfirmer le changement ? [o/N] : \e[0m"
        read -r CONFIRM
        if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
            hostnamectl set-hostname "$new_hostname"
            echo -e "\e[1;32mNom d'hôte changé en : $new_hostname\e[0m"
            break
        else
            echo -e "\e[1;33mChangement annulé.\e[0m"
            break
        fi
    done
}

display_current_network_info() {
    local physical_interface=$(get_physical_interface)
    if [[ -n "$physical_interface" ]]; then
        local ip_address=$(ip addr show "$physical_interface" | grep -oP 'inet \K[^/]+' | head -1)
        local netmask_cidr=$(ip addr show "$physical_interface" | grep -oP 'inet [^/]+/\K[0-9]+' | head -1)
        local netmask_decimal=""
        if [[ -n "$netmask_cidr" ]]; then
            netmask_decimal=$(cidr_to_netmask "$netmask_cidr" 2>/dev/null)
            if [[ -z "$netmask_decimal" || "$netmask_decimal" == "0.0.0.0" ]]; then
                netmask_decimal="Non défini"
            fi
        else
            netmask_decimal="Non défini"
        fi
        local gateway=$(ip route | grep default | grep "$physical_interface" | awk '{print $3}' | head -1)
        local mac_address=$(ip link show "$physical_interface" | grep -oP 'link/ether \K[^ ]+')
        local link_status=$(ip link show "$physical_interface" | grep -oP 'state \K[A-Z]+')
        echo -e "\n    \e[90m🔌 Interface :\e[0m \e[1;36m$physical_interface\e[0m \e[90m($link_status)\e[0m"
        echo -e "    \e[90m🌐 Adresse IP :\e[0m \e[1;36m${ip_address:-Non configurée}\e[0m"
        echo -e "    \e[90m📊 Masque :\e[0m \e[1;36m${netmask_decimal:-Non défini}\e[0m"
        echo -e "    \e[90m🚪 Passerelle :\e[0m \e[1;36m${gateway:-Non définie}\e[0m"
        echo -e "    \e[90m🏷️  MAC :\e[0m \e[1;36m$mac_address\e[0m"
        local network_mode="Statique"
        if is_dhcp_enabled "$physical_interface"; then
            network_mode="DHCP"
        fi
        echo -e "    \e[90m⚙️  Mode :\e[0m \e[1;36m$network_mode\e[0m"
    else
        echo -e "\n    \e[1;31m❌ Aucune interface réseau physique détectée\e[0m"
    fi
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

