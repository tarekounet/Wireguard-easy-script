#!/bin/bash
# Fonctions de planification et gestion alimentation pour admin_menu.sh

# Fonctions de gestion alimentation/planification
power_scheduling_menu() {
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           ⏰ PLANIFICATION ALIMENTATION         \e[0m"
        echo -e "\n\e[48;5;24m\e[97m  📅 OPTIONS DE PLANIFICATION  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 1\e[0m \e[97mProgrammer un redémarrage\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 2\e[0m \e[97mProgrammer un arrêt\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 3\e[0m \e[97mAnnuler une programmation\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 4\e[0m \e[97mVoir les tâches programmées\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;31m 0\e[0m \e[97mRetour au menu principal\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        echo -ne "\n\e[1;33mEntrez votre choix : \e[0m"
        read -r POWER_CHOICE
        case $POWER_CHOICE in
            1) schedule_reboot ;;
            2) schedule_shutdown ;;
            3) cancel_scheduled_task ;;
            4) show_scheduled_tasks ;;
            0) break ;;
            *) echo -e "\e[1;31mChoix invalide.\e[0m" ;;
        esac
    # (Bloc if supprimé, il était vide et causait une erreur de syntaxe)
    done
}

power_management_menu() {
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           ⚙️ GESTION ALIMENTATION         \e[0m"
        echo -e "\n\e[48;5;24m\e[97m  🔌 OPTIONS D'ALIMENTATION  \e[0m"
        echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 1\e[0m \e[97mRedémarrer maintenant\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;36m 2\e[0m \e[97mArrêter maintenant\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        echo -e "\n\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m    ├─ \e[0m\e[1;31m 0\e[0m \e[97mRetour au menu principal\e[0m"
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
        echo -ne "\n\e[1;33mEntrez votre choix : \e[0m"
        read -r POWER_MANAGEMENT_CHOICE
        case $POWER_MANAGEMENT_CHOICE in
            1) immediate_reboot ;;
            2) immediate_shutdown ;;
            0) break ;;
            *) echo -e "\e[1;31mChoix invalide.\e[0m" ;;
        esac
    # (Bloc if supprimé, il était vide et causait une erreur de syntaxe)
    done
}

immediate_reboot() {
    echo -ne "\n\e[1;33mConfirmer le redémarrage ? [o/N] : \e[0m"
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
        echo -e "\n\e[1;33mRedémarrage en cours...\e[0m"
        sudo reboot
    else
        echo -e "\n\e[1;33mRedémarrage annulé.\e[0m"
    fi
}

immediate_shutdown() {
    echo -ne "\n\e[1;33mConfirmer l'arrêt du système ? [o/N] : \e[0m"
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
        echo -e "\n\e[1;33mArrêt en cours...\e[0m"
        sudo shutdown now
    else
        echo -e "\n\e[1;33mArrêt annulé.\e[0m"
    fi
}

schedule_reboot() {
    echo -ne "\n\e[1;33mEntrez l'heure du redémarrage (HH:MM) : \e[0m"
    read -r REBOOT_TIME
    sudo shutdown -r "$REBOOT_TIME"
    echo -e "\n\e[1;32mRedémarrage programmé à $REBOOT_TIME.\e[0m"
}

schedule_shutdown() {
    echo -ne "\n\e[1;33mEntrez l'heure de l'arrêt (HH:MM) : \e[0m"
    read -r SHUTDOWN_TIME
    sudo shutdown -h "$SHUTDOWN_TIME"
    echo -e "\n\e[1;32mArrêt programmé à $SHUTDOWN_TIME.\e[0m"
}

cancel_scheduled_task() {
    sudo killall at
    echo -e "\n\e[1;32mToutes les tâches programmées ont été annulées.\e[0m"
}

show_scheduled_tasks() {
    echo -e "\n\e[1;34mTâches programmées :\e[0m"
    atq
}
