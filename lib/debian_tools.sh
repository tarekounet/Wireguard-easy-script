##############################
#        VERSION MODULE      #
##############################

DEBIAN_TOOLS_VERSION="1.1.0"

##############################
#      MENU PRINCIPAL        #
##############################

debian_tools_menu() {
    while true; do
        clear
        echo -e "\n\e[2;35m--------------------------------------------------\e[0m"
        echo -e "\e[1;36m            🐧 MENU OUTILS SYSTÈME 🐧\e[0m"
        echo -e "\e[2;35m--------------------------------------------------\e[0m"

        # Groupes de labels et d'actions
        local labels=()
        local actions=()

        # Groupe : Informations système
        labels+=("📦 Afficher la version de Debian")
        actions+=("show_debian_version")
        labels+=("💾 Afficher l'espace disque")
        actions+=("show_disk_space")
        labels+=("📊 Moniteur système : Afficher les performances (btop)")
        actions+=("show_system_monitor")

        # Groupe : Réseau & Docker
        labels+=("🐳 Afficher l'état du service Docker")
        actions+=("show_docker_status")
        labels+=("🌐 Modifier l'adresse IP du serveur")
        actions+=("configure_ip_vm")

        # Groupe : Administration système
        labels+=("🔄 Mettre à jour le système")
        actions+=("update_system")
        labels+=("🖥️ Modifier le nom de la VM")
        actions+=("modify_vm_name")
        labels+=("🔐 Modifier le port SSH")
        actions+=("modify_ssh_port")

        # Groupe : Actions sur la VM
        labels+=("🔁 Redémarrer la VM")
        actions+=("reboot_vm")
        labels+=("⚡ Éteindre la VM")
        actions+=("shutdown_vm")
        labels+=("💻 Ouvrir une session bash")
        actions+=("open_bash_session")

        # Affichage du menu dynamique avec séparateurs de groupes
        local group_separators=(3 5 9 12)
        local group_titles=(
            "🖥️  Informations système"
            "🌐 Réseau & Docker"
            "🔧 Administration système"
            "⚡ Actions sur la VM"
        )
        local group_idx=0
        for i in "${!labels[@]}"; do
            if [[ " ${group_separators[@]} " =~ " $i " ]]; then
                echo -e "\n\e[1;36m--- ${group_titles[$group_idx]} ---\e[0m"
                ((group_idx++))
            fi
            printf "\e[1;32m%d) \e[0m\e[0;37m%s\e[0m\n" $((i+1)) "${labels[$i]}"
        done
        echo -e "\n\e[1;32m0) \e[0m\e[0;37mRetour au menu principal\e[0m"

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
                open_bash_session) open_bash_session ;;
                *) echo -e "\e[1;31mAction inconnue.\e[0m" ;;
            esac
        else
            echo -e "\e[1;31mChoix invalide.\e[0m"
            sleep 1
        fi

        echo -e "\nAppuyez sur une touche pour revenir au menu..."
        read -n 1 -s
    done
}