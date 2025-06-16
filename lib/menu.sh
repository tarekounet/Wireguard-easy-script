# Protection : ce module ne doit être chargé que par config_wg.sh
if [[ "$(basename -- "$0")" == "menu.sh" ]]; then
    echo -e "\e[1;31mCe module ne doit pas être lancé directement, mais via config_wg.sh !\e[0m"
    exit 1
fi

##############################
#        VERSION MODULE      #
##############################

MENU_VERSION="1.4.0"

##############################
#         sources            #
##############################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/conf.sh"
source "$SCRIPT_DIR/lib/utils.sh"


##############################
#      MENU PRINCIPAL        #
##############################

main_menu() {
    while true; do
        detect_new_wg_easy_version
        clear
        show_logo_ascii
        CURRENT_CHANNEL=$(get_conf_value "SCRIPT_CHANNEL")

        echo -e "\e[1;36mCanal actuel du script:\e[0m"
        if [[ "$CURRENT_CHANNEL" == "stable" ]]; then
            echo -e "\e[32m[STABLE 🟢]\e[0m"
        elif [[ "$CURRENT_CHANNEL" == "beta" ]]; then
            echo -e "\e[33m[BETA 🟡]\e[0m"
        else
            echo -e "\e[31m[INCONNU ❓]\e[0m"
        fi

        if [[ "$DEBUG" == "1" ]]; then
            echo -e "\e[6;35m[DEBUG] ⚠️ Le mode débogage est ACTIVÉ ⚠️\e[0m"
        fi
        # === INFOS MISES À JOUR ===
        if [[ -n "$VERSION_STABLE_CONF" ]]; then
            if version_gt "$VERSION_STABLE_CONF" "$VERSION_LOCAL"; then
                echo -e "\e[33mUne nouvelle version STABLE est disponible : $VERSION_STABLE_CONF (actuelle : $VERSION_LOCAL)\e[0m"
            fi
        fi
        if [[ "$CURRENT_CHANNEL" == "beta" && -n "$VERSION_BETA_CONF" ]]; then
            if version_gt "$VERSION_BETA_CONF" "$VERSION_LOCAL"; then
                echo -e "\e[35mUne nouvelle version BETA est disponible : $VERSION_BETA_CONF (actuelle : $VERSION_LOCAL)\e[0m"
            fi
        fi
            if [[ -n "$NEW_WG_EASY_VERSION" ]]; then
                echo -e "\e[35m🐳 Nouvelle version du container disponible : $NEW_WG_EASY_VERSION (actuelle : $CURRENT_WG_EASY_VERSION)\e[0m"
        fi
        # === INFOS CONTAINER & CONFIG ===
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            echo -e "\e[2;35m--------------------------------------------------\e[0m"
            echo -e "\e[1;36m📄 Informations actuelles de Wireguard :\e[0m"
            echo -e "\e[2;35m--------------------------------------------------\e[0m\n"
            CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' wg-easy 2>/dev/null)
            case "$CONTAINER_STATUS" in
            running)
                STARTED_AT=$(docker inspect -f '{{.State.StartedAt}}' wg-easy)
                SECONDS_UP=$(($(date +%s) - $(date -d "$STARTED_AT" +%s)))
                DAYS=$((SECONDS_UP/86400))
                HOURS=$(( (SECONDS_UP%86400)/3600 ))
                MINUTES=$(( (SECONDS_UP%3600)/60 ))
                SECONDS=$((SECONDS_UP%60))
                UPTIME_STR=$(printf "%d jours, %02dh:%02dm:%02ds" "$DAYS" "$HOURS" "$MINUTES" "$SECONDS")
                echo -e "\e[32m✅ Wireguard est actif\e[0m"
                echo -e "\e[1;37m⏱️  Uptime : \e[0;33m$UPTIME_STR\e[0m\n"
                ;;
            exited)
                echo -e "\e[33m⏸️  Wireguard est arrêté\e[0m\n"
                ;;
            created)
                echo -e "\e[33m🟡 Wireguard est créé mais pas démarré\e[0m\n"
                ;;
            *)
                if docker ps -a --format '{{.Names}}' | grep -qw wg-easy; then
                echo -e "\e[31m❌ Wireguard n'est pas actif\e[0m"
                LAST_EXIT_CODE=$(docker inspect -f '{{.State.ExitCode}}' wg-easy 2>/dev/null)
                if [[ "$LAST_EXIT_CODE" != "0" ]]; then
                    echo -e "\e[31m⚠️  Échec du dernier lancement (Code : $LAST_EXIT_CODE)\e[0m\n"
                fi
                else
                echo -e "\e[31m❌ Wireguard n'est pas configuré ou actif\e[0m\n"
                fi
                ;;
            esac
        fi

        # === INFOS RÉSEAU & CONFIG ===
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            # Récupération des informations réseau
            local ip_address=$(hostname -I | awk '{print $1}')
            local interface=$(ip route | awk '/default/ {print $5; exit}')
            local dhcp_state="Inconnu"

            # Détermination du type d'adresse IP (DHCP ou statique)
            if [[ -n "$interface" ]]; then
            if grep -q "dhcp" "/etc/network/interfaces" 2>/dev/null || grep -q "dhcp" "/etc/netplan/"*.yaml 2>/dev/null; then
                dhcp_state="DHCP"
            elif nmcli device show "$interface" 2>/dev/null | grep -q "IP4.DHCP4.OPTION"; then
                dhcp_state="DHCP"
            else
                dhcp_state="Statique"
            fi
            fi

            # Récupération du port de l'interface web
            local web_port=$(grep -oP 'PORT=\K[0-9]+' "$DOCKER_COMPOSE_FILE" | head -n1)

            # Affichage des informations
            echo -e "\e[0;36mAdresse IP du poste      : \e[0;33m$ip_address\e[0m"
            echo -e "\e[0;36mAdresse IP config.       : \e[0;32m$dhcp_state\e[0m"
            echo -e "\e[0;36mPort interface web       : \e[0;32m${web_port:-Non défini}\e[0m"
        else
            echo -e "\e[2;35m--------------------------------------------------\e[0m"
            echo -e "📄\e[2;36m Informations actuelles de Wireguard :\e[0m"
            echo -e "\e[2;35m--------------------------------------------------\e[0m\n"
            echo -e "\e[1;31m⚠️  Le serveur Wireguard n'est pas encore configuré.\e[0m\n"
            echo -e "\e[5;33m         Veuillez configurer pour continuer.\e[0m"
        fi


        echo -e "\n\e[2;35m--------------------------------------------------\e[0m"
        echo -e "\e[1;36mMenu principal de Wireguard Easy Script\e[0m"
        echo -e "\e[2;35m--------------------------------------------------\e[0m\n"

        # Construction dynamique du menu
        local labels=()
        local actions=()
        local group_separators=()
        local group_titles=()

        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            # Groupe 1 : Gestion du service
            group_separators+=(0)
            group_titles+=("🟢 Gestion du service Wireguard")
            if [[ "$CONTAINER_STATUS" == "running" ]]; then
                labels+=("🚀 Lancer le service (déjà lancé)")
                actions+=("")
                labels+=("🛑 Arrêter le service")
                actions+=("shutdown_wireguard")
                labels+=("🔄 Redémarrer le service")
                actions+=("restart_wireguard")
            else
                labels+=("🚀 Lancer le service")
                actions+=("start_wireguard")
                labels+=("🛑 Arrêter le service (déjà arrêté)")
                actions+=("")
                labels+=("🔄 Redémarrer le service (service arrêté)")
                actions+=("")
            fi

            # Groupe 2 : Maintenance & configuration
            group_separators+=(${#labels[@]})
            group_titles+=("🛠️ Maintenance & configuration")
            labels+=("🌐 Changer le port WEBUI")
            actions+=("change_wg_easy_web_port")
            if [[ -n "$NEW_WG_EASY_VERSION" ]]; then
                labels+=("🐳 Mettre à jour le container ✨")
            else
                labels+=("🐳 Mettre à jour le container")
            fi
            actions+=("update_wireguard")
            labels+=("♻️ Réinitialiser la configuration")
            actions+=("RAZ_docker_compose")

            # Groupe 3 : Outils & informations
            group_separators+=(${#labels[@]})
            group_titles+=("📦 Outils & informations")
            labels+=("🐧 Outils système Linux")
            actions+=("debian_tools_menu")
            labels+=("🏴‍☠️ Menu du script")
            actions+=("menu_script_update")
            labels+=("🔑 Mot de passe technique")
            actions+=("change_tech_password")
        else
            # Groupe unique si pas de docker-compose
            group_separators+=(0)
            group_titles+=("🛠️ Configuration initiale")
            labels+=("🛠️ Créer la configuration")
            actions+=("configure_values")
            labels+=("🐧 Outils système Linux")
            actions+=("debian_tools_menu")
            labels+=("🏴‍☠️ Menu du script")
            actions+=("menu_script_update")
            labels+=("🔑 Mot de passe technique")
            actions+=("change_tech_password")
        fi

        # Affichage du menu dynamique avec séparateurs de groupes
        local group_idx=0
        for i in "${!labels[@]}"; do
            if [[ " ${group_separators[@]} " =~ " $i " ]]; then
                echo -e "\n\e[0;36m--- ${group_titles[$group_idx]} ---\e[0m"
                ((group_idx++))
            fi
            # Affichage spécial pour les labels inactifs
            if [[ "${labels[$i]}" == "🛑 Arrêter le service (déjà arrêté)" ]] \
            || [[ "${labels[$i]}" == "🚀 Lancer le service (déjà lancé)" ]] \
            || [[ "${labels[$i]}" == "🔄 Redémarrer le service (service arrêté)" ]]; then
                printf "\e[1;30m%d) %s\e[0m\n" $((i+1)) "${labels[$i]}"
            else
                printf "\e[1;32m%d) \e[0m\e[0;37m%s\e[0m\n" $((i+1)) "${labels[$i]}"
            fi
        done
        echo -e "\n\e[1;32m0) \e[0m\e[0;31m🚪 Quitter le script\e[0m"
        
        echo
        read -p $'\e[1;33mEntrez votre choix : \e[0m' CHOICE
        if [[ -z "$CHOICE" ]]; then
            echo -e "\e[1;31mAucune saisie détectée. Merci de saisir un numéro.\e[0m"
            sleep 1
            continue
        fi
        clear
        SKIP_PAUSE=0
        if [[ "$CHOICE" == "99" ]]; then
            if [[ "$DEBUG" == "1" ]]; then
                disable_debug
                echo -e "\e[1;35mMode debug désactivé.\e[0m"
            else
                enable_debug
                echo -e "\e[1;35mMode debug activé.\e[0m"
            fi
            sleep 1
            continue
        fi
        if [[ "$CHOICE" == "0" ]]; then
            clear
            echo -e "\e[1;32mAu revoir ! 👋\e[0m"
            SKIP_PAUSE=1
            exit 0
        elif [[ "$CHOICE" =~ ^[1-9][0-9]*$ && "$CHOICE" -le "${#actions[@]}" ]]; then
            action="${actions[$((CHOICE-1))]}"
            case "$action" in
                start_wireguard) start_wireguard; SKIP_PAUSE=1 ;;
                shutdown_wireguard) shutdown_wireguard; SKIP_PAUSE=1 ;;
                restart_wireguard) restart_wireguard; SKIP_PAUSE=1 ;;
                change_wg_easy_web_port) change_wg_easy_web_port ;;
                update_wireguard)
                    if [[ -n "$NEW_WG_EASY_VERSION" ]]; then
                        echo -e "\e[35mUne nouvelle version du container est disponible : $NEW_WG_EASY_VERSION (actuelle : $CURRENT_WG_EASY_VERSION)\e[0m"
                        read -p $'Voulez-vous mettre à jour le container sans tout réinitialiser ? (o/N) : ' CONFIRM
                        if [[ "$CONFIRM" =~ ^[oO]$ ]]; then
                            update_wg_easy_version_only
                        else
                            echo "Mise à jour rapide annulée. Lancement de la mise à jour complète..."
                            update_wireguard
                        fi
                    else
                        update_wireguard
                    fi
                    SKIP_PAUSE=1
                    ;;
                RAZ_docker_compose) RAZ_docker_compose ;;
                debian_tools_menu) debian_tools_menu; SKIP_PAUSE=1 ;;
                menu_script_update) menu_script_update; SKIP_PAUSE=1 ;;
                configure_values) configure_values ;;
                change_tech_password) change_tech_password ;;
                "") ;; # Option inactive
                *) echo -e "\e[1;31mChoix invalide.\e[0m" ;;
            esac
        else
            echo -e "\e[1;31mChoix invalide.\e[0m"
        fi

        if [[ "$SKIP_PAUSE" != "1" ]]; then
            echo -e "\nAppuyez sur une touche pour revenir au menu..."
            read -n 1 -s
        fi
    done
}

##############################
#    MENU SCRIPT FUNCTIONS   #
##############################

menu_script_update() {
    while true; do
        clear
        show_logo_ascii
        echo -e "\n\e[2;35m--------------------------------------------------\e[0m"
        echo -e "\e[1;36m            📜 MENU OUTILS SCRIPT 📜\e[0m"
        echo -e "\e[2;35m--------------------------------------------------\e[0m"

        # Groupes de labels et d'actions
        local labels=()
        local actions=()
        local group_separators=()
        local group_titles=()

        # Groupe 1 : Mises à jour
        group_separators+=(0)
        group_titles+=("🚧 Configuration & 🔄 Mises à jour")
        if [[ "$SCRIPT_UPDATE_AVAILABLE" -eq 1 ]]; then
            labels+=("🔼 Mettre à jour le script (nouvelle version dispo)")
            actions+=("update_script")
        fi
        labels+=("🔀 Changer de canal (stable/beta)")
        actions+=("switch_channel")
        # Groupe 2 : Informations
        group_separators+=(${#labels[@]})
        group_titles+=("⁉️ Informations et version")
        labels+=("📝 Voir le changelog")
        actions+=("show_changelog")

        # Affichage du menu dynamique avec séparateurs de groupes
        local group_idx=0
        for i in "${!labels[@]}"; do
            if [[ " ${group_separators[@]} " =~ " $i " ]]; then
                echo -e "\n\e[1;36m--- ${group_titles[$group_idx]} ---\e[0m"
                ((group_idx++))
            fi
            printf "\e[1;32m%d) \e[0m\e[0;37m%s\e[0m\n" $((i+1)) "${labels[$i]}"
        done
        echo -e "\n\e[1;32m0) \e[0m\e[0;31m🔙 Retour au menu principal\e[0m"

        # Lecture du choix utilisateur
        echo
        read -p $'\e[1;33mEntrez votre choix : \e[0m' CHOICE
        if [[ -z "$CHOICE" ]]; then
            echo -e "\e[1;31mAucune saisie détectée. Merci de saisir un numéro.\e[0m"
            sleep 1
            continue
        fi

        if [[ "$CHOICE" == "0" ]]; then
            break
        elif [[ "$CHOICE" =~ ^[1-9][0-9]*$ && "$CHOICE" -le "${#actions[@]}" ]]; then
            action="${actions[$((CHOICE-1))]}"
            case "$action" in
                update_script) check_and_update_from_version_txt ;;
                switch_channel) switch_channel ;;
                change_tech_password) change_tech_password ;;
                show_changelog) show_changelog ;;
                *) echo -e "\e[1;31mAction inconnue.\e[0m" ;;
            esac
        else
            echo -e "\e[1;31mChoix invalide.\e[0m"; sleep 1
        fi
    done
}

##############################
#     MENU DEBIAN TOOLS      #
##############################

debian_tools_menu() {
    while true; do
        clear
        show_logo_ascii
        echo -e "\n\e[2;35m--------------------------------------------------\e[0m"
        echo -e "\e[1;36m            🐧 MENU OUTILS SYSTÈME 🐧\e[0m"
        echo -e "\e[2;35m--------------------------------------------------\e[0m"

        # Groupes de labels et d'actions
        local labels=()
        local actions=()
        local group_separators=()
        local group_titles=()

        # Groupe : Informations système
        group_separators+=(0)
        group_titles+=("🖥️ Informations système")
        labels+=("📦 Afficher la version de Debian")
        actions+=("show_debian_version")
        labels+=("💾 Afficher l'espace disque")
        actions+=("show_disk_space")
        labels+=("📊 Moniteur système : Afficher les performances (btop)")
        actions+=("show_system_monitor")

        # Groupe : Réseau & Docker
        group_separators+=(${#labels[@]})
        group_titles+=("🌐 Réseau & Docker")
        labels+=("🐳 Afficher l'état du service Docker")
        actions+=("show_docker_status")
        labels+=("🌐 Modifier l'adresse IP du serveur")
        actions+=("configure_ip_vm")

        # Groupe : Administration système
        group_separators+=(${#labels[@]})
        group_titles+=("🔧 Administration système")
        labels+=("🔄 Mettre à jour le système")
        actions+=("update_system")
        labels+=("🖥️ Modifier le nom de la VM")
        actions+=("modify_vm_name")
        labels+=("🔐 Modifier le port SSH")
        actions+=("modify_ssh_port")

        # Groupe : Actions sur la VM
        group_separators+=(${#labels[@]})
        group_titles+=("🚦 Actions sur la VM")
        labels+=(" 🔁 Redémarrer la VM")
        actions+=("reboot_vm")
        labels+=("💤 Éteindre la VM")
        actions+=("shutdown_vm")
        

        local group_idx=0
        for i in "${!labels[@]}"; do
            if [[ " ${group_separators[@]} " =~ " $i " ]]; then
                echo -e "\n\e[0;36m--- ${group_titles[$group_idx]} ---\e[0m"
                ((group_idx++))
            fi
            printf "\e[1;32m%d) \e[0m\e[0;37m%s\e[0m\n" $((i+1)) "${labels[$i]}"
        done
        echo -e "\n\e[1;32m0) \e[0m\e[0;31m🔙 Retour au menu principal\e[0m"

        echo
        read -p $'\e[1;33mEntrez votre choix : \e[0m' CHOICE
        if [[ -z "$CHOICE" ]]; then
            echo -e "\e[1;31mAucune saisie détectée. Merci de saisir un numéro.\e[0m"
            sleep 1
            continue
        fi

        if [[ "$CHOICE" == "0" ]]; then
            break
        elif [[ "$CHOICE" =~ ^[1-9][0-9]*$ && "$CHOICE" -le "${#actions[@]}" ]]; then
            action="${actions[$((CHOICE-1))]}"
            case "$action" in
                show_debian_version)
                    if [[ -f /etc/debian_version ]]; then
                        echo -e "\e[1;32mVersion Debian :\e[0m $(cat /etc/debian_version)"
                    else
                        echo -e "\e[1;31mCe système n'est pas Debian.\e[0m"
                    fi
                    ;;
                show_disk_space)
                    df -h
                    ;;
                show_docker_status)
                    systemctl status docker --no-pager
                    ;;
                show_system_monitor)
                    if command -v btop >/dev/null 2>&1; then
                        btop
                    else
                        echo -e "\e[1;31mbtop n'est pas installé. Installation...\e[0m"
                        run_as_root apt update && run_as_root apt install -y btop
                        btop
                    fi
                    ;;
                configure_ip_vm) configure_ip_vm ;;
                update_system)
                    echo -e "\e[1;33mMise à jour du système...\e[0m"
                    run_as_root apt update && run_as_root apt upgrade -y
                    ;;
                modify_vm_name) modify_vm_name ;;
                modify_ssh_port) modify_ssh_port ;;
                reboot_vm) reboot_vm ;;
                shutdown_vm) shutdown_vm ;;
                *) echo -e "\e[1;31mAction inconnue.\e[0m" ;;
            esac
        else
            echo -e "\e[1;31mChoix invalide.\e[0m"
            sleep 1
        fi
    done
}