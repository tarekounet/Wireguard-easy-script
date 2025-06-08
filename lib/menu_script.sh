# Protection : ce module ne doit être chargé que par config_wg.sh
if [[ "$(basename -- "$0")" == "menu_script.sh" ]]; then
    echo -e "\e[1;31mCe module ne doit pas être lancé directement, mais via config_wg.sh !\e[0m"
    exit 1
fi

##############################
#        VERSION MODULE      #
##############################
MENU_SCRIPT_VERSION="1.1.0"

##############################
#    MENU SCRIPT FUNCTIONS   #
##############################

menu_script_update() {
    while true; do
        clear
        echo -e "\n\e[1;36m========== Script & Mises à jour ==========\e[0m"

        # Groupes de labels et d'actions
        local labels=()
        local actions=()
        local group_separators=()
        local group_titles=()

        # Groupe 1 : Mises à jour
        group_separators+=(0)
        group_titles+=("🔄 Mises à jour")
        if [[ "$SCRIPT_UPDATE_AVAILABLE" -eq 1 ]]; then
            labels+=("🔼 Mettre à jour le script (nouvelle version dispo)")
            actions+=("update_script")
        fi
        if [[ "$MODULE_UPDATE_AVAILABLE" -eq 1 ]]; then
            labels+=("⬆️  Mettre à jour les modules (mise à jour dispo)")
            actions+=("update_modules")
        fi

        # Groupe 2 : Informations
        group_separators+=(${#labels[@]})
        group_titles+=("📦 Informations")
        labels+=("📦 Afficher les versions des modules")
        actions+=("show_modules_versions")

        # Groupe 3 : Canal & changelog
        group_separators+=(${#labels[@]})
        group_titles+=("🔀 Canal & changelog")
        labels+=("🔀 Changer de canal (stable/beta)")
        actions+=("switch_channel")
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
        echo -e "\n\e[1;32m0) \e[0m\e[0;37mRetour au menu principal\e[0m"

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
                update_script) update_script ;;
                update_modules) update_modules ;;
                show_modules_versions) show_modules_versions ;;
                switch_channel) switch_channel ;;
                show_changelog) show_changelog ;;
                *) echo -e "\e[1;31mAction inconnue.\e[0m" ;;
            esac
        else
            echo -e "\e[1;31mChoix invalide.\e[0m"; sleep 1
        fi
    done
}