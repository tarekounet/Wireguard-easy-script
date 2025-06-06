##############################
#        VERSION MODULE      #
##############################

MENU_VERSION="1.1.0"

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
            CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' wireguard 2>/dev/null)
            case "$CONTAINER_STATUS" in
                running)
                    STARTED_AT=$(docker inspect -f '{{.State.StartedAt}}' wireguard)
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
                    if docker ps -a --format '{{.Names}}' | grep -qw wireguard; then
                        echo -e "\e[5;31m❌ Wireguard n'est pas en cours d'exécution.\e[0m"
                        echo -e "\e[33mDerniers logs du conteneur Wireguard :\e[0m"
                        docker logs --tail 10 wireguard 2>&1
                        LAST_EXIT_CODE=$(docker inspect -f '{{.State.ExitCode}}' wireguard 2>/dev/null)
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

        # === AFFICHAGE DU MENU ===
        echo -e "\n\e[2;35m--------------------------------------------------\e[0m"
        echo -e "🏠\e[2;36m MENU PRINCIPAL :\e[0m"
        echo -e "\e[2;35m--------------------------------------------------\e[0m"
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            echo -e "\n\e[1;36m--- Gestion et maintenance de Wireguard ---\e[0m"
            if [[ "$CONTAINER_STATUS" == "running" ]]; then
                echo -e "\e[1;90m1) 🚀 Lancer le service (déjà lancé)\e[0m"
                echo -e "\e[1;32m2) \e[0m\e[0;37m🛑 Arrêter le service\e[0m"
                echo -e "\e[1;32m3) \e[0m\e[0;37m🔄 Redémarrer le service\e[0m"
            else
                echo -e "\e[1;32m1) \e[0m\e[0;37m🚀 Lancer le service\e[0m"
                echo -e "\e[1;90m2) 🛑 Arrêter le service (déjà arrêté)\e[0m"
                echo -e "\e[1;90m3) 🔄 Redémarrer le service (service arrêté)\e[0m"
            fi
            echo -e "\e[1;32m4) \e[0m\e[0;37m🛠️  changer le port WEBUI\e[0m"
            echo -e "\e[1;32m5) \e[0m\e[0;37m🐳 Mettre à jour le container\e[0m"
            echo -e "\e[1;32m6) \e[0m\e[0;37m♻️  Réinitialiser la configuration\e[0m"
            echo -e "\n\e[1;36m--- Configuration ---\e[0m"
            echo -e "\e[1;32m7) \e[0m\e[0;37m🔑 Modifier le mot de passe technique\e[0m"
            echo -e "\e[1;32m8) \e[0m\e[0;37m🐧 Outils système Linux\e[0m"
            echo -e "\e[1;32m9) \e[0m\e[0;37m🛠️  Script & Mises à jour\e[0m"
            echo -e "\n\e[1;32m0) \e[0m\e[0;37m🚪 Quitter le script\e[0m"
        else
            echo -e "\e[1;36m--- Configuration ---\e[0m"
            echo -e "\e[1;32m1) \e[0m\e[0;37m🛠️ Créer la configuration\e[0m"
            echo -e "\e[1;32m2) \e[0m\e[0;37m🔑 Modifier le mot de passe technique\e[0m"
            echo -e "\e[1;32m3) \e[0m\e[0;37m🐧 Outils système Linux\e[0m"
            echo -e "\e[1;32m4) \e[0m\e[0;37m🛠️  Script & Mises à jour\e[0m"
            echo -e "\n\e[1;32m0) \e[0m\e[0;37m🚪 Quitter le script\e[0m"
        fi

        echo
        read -p $'\e[1;33mEntrez votre choix : \e[0m' ACTION
        clear
        SKIP_PAUSE=0

        # === ACTIONS PRINCIPALES ===
        if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
            case $ACTION in
                1)  
                    if [[ "$CONTAINER_STATUS" != "running" ]]; then
                        echo "Démarrage de Wireguard..."
                        docker compose -f "$DOCKER_COMPOSE_FILE" up -d
                        echo "Wireguard démarré avec succès ! 🚀"
                    else
                    SKIP_PAUSE=1
                    fi
                    ;;
                2) 
                    if [[ "$CONTAINER_STATUS" == "running" ]]; then
                        echo "Arrêt de Wireguard..."
                        docker compose -f "$DOCKER_COMPOSE_FILE" down
                        echo "Wireguard arrêté avec succès ! 🛑"
                    else
                    SKIP_PAUSE=1
                    fi
                    ;;               
                3) 
                    if [[ "$CONTAINER_STATUS" == "running" ]]; then
                        echo "Redémarrage de Wireguard..."
                        docker compose -f "$DOCKER_COMPOSE_FILE" restart
                    else
                    SKIP_PAUSE=1
                    fi
                    ;;
                4) change_wg_easy_web_port ;;
                5)
                    echo "Mise à jour de Wireguard..."
                    docker compose -f "$DOCKER_COMPOSE_FILE" down --rmi all --volumes --remove-orphans
                    docker compose -f "$DOCKER_COMPOSE_FILE" pull
                    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
                    echo "Wireguard mis à jour et purgé avec succès ! ⬆️"
                    ;;
                6) RAZ_docker_compose ;;
                7) change_tech_password ;;
                8) debian_tools_menu ;;
                9) menu_script_update ;;
                10) update_modules ;;
                11) show_modules_versions ;;
                12)
                    if [[ "$CURRENT_CHANNEL" == "stable" && -n "$VERSION_STABLE_CONF" && -n "$VERSION_BETA_CONF" && "$VERSION_STABLE_CONF" > "$VERSION_BETA_CONF" ]]; then
                        echo -e "\e[31mLa version STABLE est plus récente que la version BETA. Passage au canal BETA interdit.\e[0m"
                        SKIP_PAUSE=0
                    else
                        switch_channel
                    fi
                    ;;
                13) show_changelog; SKIP_PAUSE=1 ;;
                0)
                    clear
                    echo -e "\e[1;32mAu revoir ! 👋\e[0m"
                    SKIP_PAUSE=1
                    exit 0
                    ;;
                *)
                    echo -e "\e[1;31mChoix invalide.\e[0m"
                    ;;
            esac
        else
            case $ACTION in
                1) configure_values ;;
                2) change_tech_password ;;
                3) debian_tools_menu ;;
                4) menu_script_update ;;
                5) update_modules ;;
                6) show_modules_versions ;;
                7) switch_channel ;;
                8) show_changelog; SKIP_PAUSE=1 ;;
                0)
                    clear
                    echo -e "\e[1;32mAu revoir ! 👋\e[0m"
                    SKIP_PAUSE=1
                    exit 0
                    ;;
                *)
                    echo -e "\e[1;31mChoix invalide.\e[0m"
                    ;;
            esac
        fi

        if [[ "$SKIP_PAUSE" != "1" ]]; then
            echo -e "\nAppuyez sur une touche pour revenir au menu..."
            read -n 1 -s
        fi
    done
}

##############################
#   MISE À JOUR DU SCRIPT    #
##############################

update_script() {
    clear
    echo -e "\e[1;36m===== Mise à jour du script =====\e[0m"
    if [[ "$SCRIPT_CHANNEL" == "beta" ]]; then
        UPDATE_URL="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/beta/config_wg.sh"
    else
        UPDATE_URL="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh"
    fi
    if curl -fsSL "$UPDATE_URL" -o "$0.new"; then
        if ! cmp -s "$0" "$0.new"; then
            cp "$0" "$SCRIPT_BACKUP"
            mv "$0.new" "$0"
            chmod +x "$0"
            echo -e "\e[32mScript mis à jour avec succès !\e[0m"
            echo -e "\nAppuyez sur une touche pour relancer le script..."
            read -n 1 -s
            exec "$0"
        else
            rm "$0.new"
            echo -e "\e[33mAucune mise à jour disponible.\e[0m"
        fi
    else
        echo -e "\e[31mLa mise à jour du script a échoué.\e[0m"
    fi
}

##############################
#    CHANGEMENT DE CANAL     #
##############################

switch_channel() {
    if [[ "$SCRIPT_CHANNEL" == "stable" ]]; then
        EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
        read -sp $'\e[1;33mEntrez le mot de passe technique pour passer en beta : \e[0m' PASS
        echo
        ENTERED_HASH=$(openssl passwd -6 -salt Qw8n0Qw8 "$PASS")
        if [[ "$ENTERED_HASH" != "$EXPECTED_HASH" ]]; then
            echo -e "\e[1;31mMot de passe incorrect. Passage en beta annulé.\e[0m"
            sleep 2
            return
        fi
        echo -e "\e[1;33m⚠️  Vous allez passer sur le canal beta. Ce canal peut contenir des fonctionnalités instables ou expérimentales.\e[0m"
        read -p $'\e[1;33mConfirmez-vous vouloir passer en beta et accepter les risques ? (o/N) : \e[0m' CONFIRM_BETA
        if [[ "$CONFIRM_BETA" == "o" || "$CONFIRM_BETA" == "O" ]]; then
            set_conf_value "SCRIPT_CHANNEL" "beta"
            set_conf_value "BETA_CONFIRMED" "1"
            if curl -fsSL "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/beta/config_wg.sh" -o "$0.new"; then
                mv "$0.new" "$0"
                chmod +x "$0"
                echo -e "\e[1;35mLe script beta a été téléchargé. Redémarrage...\e[0m"
                sleep 1
                exec "$0"
            else
                echo -e "\e[1;31mErreur lors du téléchargement du script beta.\e[0m"
                sleep 2
            fi
        else
            set_conf_value "BETA_CONFIRMED" "0"
            set_conf_value "SCRIPT_CHANNEL" "stable"
            echo -e "\e[1;33mChangement annulé. Retour au menu principal.\e[0m"
            sleep 1
        fi
    else
        set_conf_value "SCRIPT_CHANNEL" "stable"
        set_conf_value "BETA_CONFIRMED" "0"
        if curl -fsSL "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh" -o "$0.new"; then
            mv "$0.new" "$0"
            chmod +x "$0"
            echo -e "\e[1;32mLe script stable a été téléchargé. Redémarrage...\e[0m"
            sleep 1
            exec "$0"
        else
            echo -e "\e[1;31mErreur lors du téléchargement du script stable.\e[0m"
            sleep 2
        fi
    fi
}
