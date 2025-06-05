##############################
#        VERSION MODULE      #
##############################
menu_script_VERSION="1.0.0"

##############################
#    MENU SCRIPT FUNCTIONS   #
##############################

show_script_update_menu() {
    echo -e "\n\e[1;36m========== Script & Mises à jour ==========\e[0m"
    if [[ "$1" == "with_config" ]]; then
        if [[ "$SCRIPT_UPDATE_AVAILABLE" -eq 1 ]]; then
            echo -e "\e[5;33m9) 🔼 Mettre à jour le script (nouvelle version dispo)\e[0m"
        else
            echo -e "\e[1;32m9) \e[0m\e[0;37m🔼 Mettre à jour le script\e[0m"
        fi
        if [[ "$MODULE_UPDATE_AVAILABLE" -eq 1 ]]; then
            echo -e "\e[5;33m10) ⬆️  Mettre à jour les modules (mise à jour dispo)\e[0m"
        else
            echo -e "\e[1;32m10) \e[0m\e[0;37m⬆️  Mettre à jour les modules\e[0m"
        fi
        echo -e "\e[1;32m11) \e[0m\e[0;37m📦 Afficher les versions des modules\e[0m"
        echo -e "\e[1;32m12) \e[0m\e[0;37m🔀 Changer de canal (stable/beta)\e[0m"
        echo -e "\e[1;32m13) \e[0m\e[0;37m📝 Voir le changelog\e[0m"
        echo -e "\n\e[1;33mAppuyez sur 0 pour revenir au menu principal.\e[0m"
    else
        if [[ "$SCRIPT_UPDATE_AVAILABLE" -eq 1 ]]; then
            echo -e "\e[5;33m4) 🔼 Mettre à jour le script (nouvelle version dispo)\e[0m"
        else
            echo -e "\e[1;32m4) \e[0m\e[0;37m🔼 Mettre à jour le script\e[0m"
        fi
        if [[ "$MODULE_UPDATE_AVAILABLE" -eq 1 ]]; then
            echo -e "\e[5;33m5) ⬆️  Mettre à jour les modules (mise à jour dispo)\e[0m"
        else
            echo -e "\e[1;32m5) \e[0m\e[0;37m⬆️  Mettre à jour les modules\e[0m"
        fi
        echo -e "\e[1;32m6) \e[0m\e[0;37m📦 Afficher les versions des modules\e[0m"
        echo -e "\e[1;32m7) \e[0m\e[0;37m🔀 Changer de canal (stable/beta)\e[0m"
        echo -e "\e[1;32m8) \e[0m\e[0;37m📝 Voir le changelog\e[0m"
        echo -e "\n\e[1;33mAppuyez sur 0 pour revenir au menu principal.\e[0m"
    fi
}
menu_script_update() {
    while true; do
        clear
        show_script_update_menu only_menu
        echo
        read -p $'\e[1;33mEntrez votre choix (0 pour retour) : \e[0m' CHOICE
        case $CHOICE in
            0|9|4) break ;;  # Retour immédiat sans pause
            10|5) update_modules ;;
            11|6) show_modules_versions ;;
            12|7) switch_channel ;;
            13|8) show_changelog ;;
            *) echo -e "\e[1;31mChoix invalide.\e[0m"; sleep 1 ;;
        esac
    done
}