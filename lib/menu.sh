# Protection : ce module ne doit être chargé que par config_wg.sh
if [[ "$(basename -- "$0")" == "menu.sh" ]]; then
    echo -e "\e[1;31mCe module ne doit pas être lancé directement, mais via config_wg.sh !\e[0m"
    exit 1
fi

##############################
#        VERSION MODULE      #
##############################

MENU_VERSION="1.3.2"

##############################
#         sources            #
##############################
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
source "$(dirname "${BASH_SOURCE[0]}")/menu_script.sh"

##############################
#      MENU PRINCIPAL        #
##############################

main_menu() {
    while true; do
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

        # === INFOS CONTAINER & CONFIG ===
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            echo -e "\e[2;35m--------------------------------------------------\e[0m"
            echo -e "\e[1;36m📄 Informations actuelles de Wireguard :\e[0m"
            echo -e "\e[2;35m--------------------------------------------------\e[0m\n"
            update_wg_easy_version_only
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
                echo -e "\e[1;33m📋 Derniers logs Wireguard :\e[0m"
                docker logs --tail 10 wg-easy 2>&1 | while read -r line; do
                    echo -e "\e[0;37m> $line\e[0m"
                done
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
            local web_port=$(grep -oP '^\s*PORT=\K\d+' "$DOCKER_COMPOSE_FILE")

            # Affichage des informations
            echo -e "\e[1;36mAdresse IP du poste      : \e[0;33m$ip_address\e[0m"
            echo -e "\e[0;31mAdresse IP config.       : \e[0;32m$dhcp_state\e[0m"
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
            labels+=("🐳 Mettre à jour le container")
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
        fi

        # Affichage du menu dynamique avec séparateurs de groupes
        local group_idx=0
        for i in "${!labels[@]}"; do
            if [[ " ${group_separators[@]} " =~ " $i " ]]; then
                echo -e "\n\e[0;36m--- ${group_titles[$group_idx]} ---\e[0m"
                ((group_idx++))
            fi
            printf "\e[1;32m%d) \e[0m\e[0;37m%s\e[0m\n" $((i+1)) "${labels[$i]}"
        done
        echo -e "\n\e[1;32m0) \e[0m\e[0;37m🚪 Quitter le script\e[0m"

        echo
        read -p $'\e[1;33mEntrez votre choix : \e[0m' CHOICE
        if [[ -z "$CHOICE" ]]; then
            echo -e "\e[1;31mAucune saisie détectée. Merci de saisir un numéro.\e[0m"
            sleep 1
            continue
        fi
        clear
        SKIP_PAUSE=0

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
                update_wireguard) update_wireguard; SKIP_PAUSE=1 ;;
                RAZ_docker_compose) RAZ_docker_compose ;;
                debian_tools_menu) debian_tools_menu; SKIP_PAUSE=1 ;;
                menu_script_update) menu_script_update; SKIP_PAUSE=1 ;;
                configure_values) configure_values ;;
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