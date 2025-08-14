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
# Version: 0.20.2
# Author: Tarek.E
# Project: Wireguard Easy Script
# Repository: https://github.com/tarekounet/Wireguard-easy-script

set -euo pipefail


# Appel de la mise à jour automatique au lancement
auto_update_admin_menu "$@"

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
