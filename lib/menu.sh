# Protection : ce module ne doit être chargé que par config_wg.sh
if [[ "$(basename -- "$0")" == "menu.sh" ]]; then
    echo -e "\e[1;31mCe module ne doit pas être lancé directement, mais via config_wg.sh !\e[0m"
    exit 1
fi

##############################
#        VERSION MODULE      #
##############################

MENU_VERSION="1.2.0"

##############################
#         sources            #
##############################

source "$(dirname "${BASH_SOURCE[0]}")/menu_script.sh"

##############################
#      MENU PRINCIPAL        #
##############################

main_menu() {
    while true; do
        clear
        show_logo_ascii
        BLINK_ARROW_LEFT="\e[5;33m<==\e[0m"
        BLINK_ARROW_RIGHT="\e[5;33m==>\e[0m"
        CURRENT_CHANNEL=$(get_conf_value "SCRIPT_CHANNEL")

        if [[ "$CURRENT_CHANNEL" == "stable" ]]; then
            echo -e "Canal : \e[32mSTABLE 🟢\e[0m $BLINK_ARROW_LEFT \e[90mBETA ⚪\e[0m "
        elif [[ "$CURRENT_CHANNEL" == "beta" ]]; then
            echo -e "Canal : \e[90mSTABLE ⚪\e[0m $BLINK_ARROW_RIGHT \e[32mBETA 🟢\e[0m "
            echo -e "\e[2;33mAppuyez sur 's' pour passer au canal STABLE.\e[0m"
        fi

        # === INFOS MISES À JOUR ===
        if [[ -n "$VERSION_STABLE_CONF" ]]; then
            if version_gt "$VERSION_STABLE_CONF" "$VERSION_LOCAL"; then
                echo -e "\e[33mUne nouvelle version STABLE est disponible : $VERSION_STABLE_CONF (actuelle : $VERSION_LOCAL)\e[0m"
                echo -e "\e[33mUtilisez l'option 'u' dans le menu pour mettre à jour.\e[0m"
            fi
        fi
        if [[ "$CURRENT_CHANNEL" == "beta" && -n "$VERSION_BETA_CONF" ]]; then
            if version_gt "$VERSION_BETA_CONF" "$VERSION_LOCAL"; then
                echo -e "\e[35mUne nouvelle version BETA est disponible : $VERSION_BETA_CONF (actuelle : $VERSION_LOCAL)\e[0m"
                echo -e "\e[33mUtilisez l'option 'u' dans le menu pour mettre à jour.\e[0m"
            fi
        fi

        # === INFOS CONTAINER & CONFIG ===
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            echo -e "\e[2;35m--------------------------------------------------\e[0m"
            echo -e "📄\e[2;36m Informations actuelles de Wireguard :\e[0m"
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
                    if (( DAYS > 0 )); then
                        UPTIME_STR="${DAYS}j ${HOURS}h ${MINUTES}m ${SECONDS}s"
                    elif (( HOURS > 0 )); then
                        UPTIME_STR="${HOURS}h ${MINUTES}m ${SECONDS}s"
                    elif (( MINUTES > 0 )); then
                        UPTIME_STR="${MINUTES}m ${SECONDS}s"
                    else
                        UPTIME_STR="${SECONDS}s"
                    fi
                    echo -e "\e[32m✅ Wireguard est en cours d'exécution.\e[0m"
                    echo -e "\e[37m⏱️  Durée : $UPTIME_STR\e[0m\n"
                    ;;
                exited)
                    echo -e "\e[33m⏸️  Wireguard est arrêté (exited)\e[0m"
                    ;;
                created)
                    echo -e "\e[33m🟡 Wireguard est créé mais pas démarré\e[0m\n"
                    ;;
                *)
                    if docker ps -a --format '{{.Names}}' | grep -qw wg-easy; then
                        echo -e "\e[5;31m❌ Wireguard n'est pas en cours d'exécution.\e[0m"
                        echo -e "\e[33mDerniers logs du conteneur Wireguard :\e[0m"
                        docker logs --tail 10 wg-easy 2>&1
                        LAST_EXIT_CODE=$(docker inspect -f '{{.State.ExitCode}}' wg-easy 2>/dev/null)
                        if [[ "$LAST_EXIT_CODE" != "0" ]]; then
                            echo -e "\e[31m⚠️  Le dernier lancement du conteneur a échoué (exit code: $LAST_EXIT_CODE).\e[0m"
                        fi
                        echo
                    else
                        echo -e "\e[5;31m❌ Wireguard n'est pas en cours d'exécution.\e[0m\n"
                    fi
                    ;;
            esac
        fi

        # === INFOS RÉSEAU & CONFIG ===
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            printf "\e[1;36m%-22s : \e[0;33m%s\e[0m\n" "Adresse IP du poste" "$(hostname -I | awk '{print $1}')"
            INTERFACE=$(ip route | awk '/default/ {print $5; exit}')
            DHCP_STATE="Inconnu"
            if [[ -n "$INTERFACE" ]]; then
            if grep -q "dhcp" "/etc/network/interfaces" 2>/dev/null || grep -q "dhcp" "/etc/netplan/"*.yaml 2>/dev/null; then
                DHCP_STATE="DHCP"
            elif nmcli device show "$INTERFACE" 2>/dev/null | grep -q "IP4.DHCP4.OPTION"; then
                DHCP_STATE="DHCP"
            else
                DHCP_STATE="Statique"
            fi
            fi
            printf "\e[0;36m%-22s : \e[0;32m%s\e[0m\n" "Adresse IP config." "$DHCP_STATE"
            WEB_PORT=$(grep -oP '^\s*PORT=\K\d+' "$DOCKER_COMPOSE_FILE")
            printf "\e[0;36m%-22s : \e[0;32m%s\e[0m\n" "Port interface web" "${WEB_PORT:-Non défini}"
        else
            echo -e "\e[2;35m--------------------------------------------------\e[0m"
            echo -e "📄\e[2;36m Informations actuelles de Wireguard :\e[0m"
            echo -e "\e[2;35m--------------------------------------------------\e[0m\n"
            echo -e "\e[1;31m⚠️  Le serveur Wireguard n'est pas encore configuré.\e[0m\n"
            echo -e "\e[5;33m         Veuillez configurer pour continuer.\e[0m"
        fi

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
            labels+=("🛠️  Changer le port WEBUI")
            actions+=("change_wg_easy_web_port")
            labels+=("🐳 Mettre à jour le container")
            actions+=("update_wireguard")
            labels+=("♻️  Réinitialiser la configuration")
            actions+=("RAZ_docker_compose")
            labels+=("🔑 Modifier le mot de passe technique")
            actions+=("change_tech_password")

            # Groupe 3 : Outils & informations
            group_separators+=(${#labels[@]})
            group_titles+=("📦 Outils & informations")
            labels+=("🐧 Outils système Linux")
            actions+=("debian_tools_menu")
            labels+=("🛠️  Script & Mises à jour")
            actions+=("menu_script_update")
            labels+=("📦 Mettre à jour les modules")
            actions+=("update_modules")
            labels+=("📋 Afficher les versions des modules")
            actions+=("show_modules_versions")
            labels+=("🔀 Changer de canal stable/beta")
            actions+=("switch_channel")
            labels+=("📝 Voir le changelog")
            actions+=("show_changelog")
        else
            # Groupe unique si pas de docker-compose
            group_separators+=(0)
            group_titles+=("🛠️ Configuration initiale")
            labels+=("🛠️ Créer la configuration")
            actions+=("configure_values")
            labels+=("🔑 Modifier le mot de passe technique")
            actions+=("change_tech_password")
            labels+=("🐧 Outils système Linux")
            actions+=("debian_tools_menu")
            labels+=("🛠️  Script & Mises à jour")
            actions+=("menu_script_update")
            labels+=("📦 Mettre à jour les modules")
            actions+=("update_modules")
            labels+=("📋 Afficher les versions des modules")
            actions+=("show_modules_versions")
            labels+=("🔀 Changer de canal stable/beta")
            actions+=("switch_channel")
            labels+=("📝 Voir le changelog")
            actions+=("show_changelog")
        fi

        # Affichage du menu dynamique avec séparateurs de groupes
        local group_idx=0
        for i in "${!labels[@]}"; do
            if [[ " ${group_separators[@]} " =~ " $i " ]]; then
                echo -e "\n\e[1;36m--- ${group_titles[$group_idx]} ---\e[0m"
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
                change_tech_password) change_tech_password ;;
                debian_tools_menu) debian_tools_menu ;;
                menu_script_update) menu_script_update ;;
                update_modules) update_modules ;;
                show_modules_versions) show_modules_versions ;;
                switch_channel) switch_channel ;;
                show_changelog) show_changelog; SKIP_PAUSE=1 ;;
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