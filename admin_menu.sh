# Fonction de comparaison et mise à jour automatique au lancement

auto_update_if_needed() {
    local local_version="$(head -n1 version.txt 2>/dev/null | tr -d '\n\r ')"
    local github_version=""
    if ping -c 1 -W 1 github.com >/dev/null 2>&1; then
        github_version="$(curl -fsSL --connect-timeout 5 https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/version.txt | head -n1 | tr -d '\n\r ')"
        if [ -n "$github_version" ] && [ "$github_version" != "$local_version" ]; then
            echo -e "\033[1;33mMise à jour disponible : $local_version → $github_version\033[0m"
            # Téléchargement du script principal
            curl -fsSL "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/admin_menu.sh" -o "$(dirname "$0")/admin_menu.sh"
            # Synchronisation complète du dossier lib_admin
            local lib_admin_files=(ssh.sh user_management.sh power.sh user.sh network.sh maintenance.sh docker.sh utils.sh)
            local lib_admin_dir="$(dirname "$0")/lib_admin"
            mkdir -p "$lib_admin_dir"
            for f in "${lib_admin_files[@]}"; do
                curl -fsSL "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/lib_admin/$f" -o "$lib_admin_dir/$f"
            done
            # Mise à jour du fichier version.txt à la fin
            echo "$github_version" > "version.txt"
            echo -e "\033[1;32mMise à jour effectuée. Redémarrage du script...\033[0m"
            exec bash "$0" "$@"
        fi
    else
        echo -e "\033[1;33mConnexion Internet indisponible : étape de mise à jour ignorée.\033[0m"
    fi
}

# Appel de la fonction de mise à jour automatique au lancement
auto_update_if_needed "$@"
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
# Fonction de mise à jour automatique du script principal

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

# Author: Tarek.E
# Project: Wireguard Easy Script
# Repository: https://github.com/tarekounet/Wireguard-easy-script

set -euo pipefail






# ═══════════════════════════════════════════════════════════════
echo -e "\e[1;33mVérification des prérequis système...\e[0m"
if ! check_and_install_docker; then
    echo -e "\n\e[1;31mErreur : Docker requis mais non disponible. Arrêt du script.\e[0m"
    exit 1
fi
sleep 2
technical_admin_menu() {
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m                                                    \e[0m"
        echo -e "\e[48;5;236m\e[97m           🔧 ADMINISTRATION TECHNIQUE              \e[0m"
        echo -e "\e[48;5;236m\e[97m                                                    \e[0m"
        echo -e "\n\e[48;5;237m\e[97m            📊 INFORMATIONS SYSTÈME              \e[0m"
    echo -e "\n    \e[90m🖥️  Système :\e[0m \e[1;36mDebian $(cat /etc/debian_version 2>/dev/null || echo 'GNU/Linux')\e[0m"
    # Traduction uptime en français
    RAW_UPTIME=$(uptime -p 2>/dev/null || echo 'Non disponible')
    FR_UPTIME="$RAW_UPTIME"
    FR_UPTIME=${FR_UPTIME//hours/heure}
    FR_UPTIME=${FR_UPTIME//hour/heure}
    FR_UPTIME=${FR_UPTIME//minutes/minute}
    FR_UPTIME=${FR_UPTIME//minute/minute}
    FR_UPTIME=${FR_UPTIME//,/, }
    echo -e "    \e[90m⏱️ Actif depuis :\e[0m \e[1;32m$FR_UPTIME\e[0m"
    echo -e "    \e[90m🌐 IP actuelle :\e[0m \e[1;36m$(hostname -I | awk '{print $1}')\e[0m"
        echo -e "\n\e[48;5;24m\e[97m  👥 GESTION DES UTILISATEURS  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 1\e[0m \e[97mGestion des utilisateurs\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        echo -e "\n\e[48;5;94m\e[97m  🐳 GESTION DOCKER  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 2\e[0m \e[97mRAZ Docker-WireGuard\e[0m"
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
                            kill -9 $PPID
                        else
                            echo -e "\e[1;32mFermeture de la session locale...\e[0m"
                            kill -9 $PPID
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
