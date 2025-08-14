# Définition des couleurs ANSI
YELLOW="\033[1;33m"
WHITE="\033[1;37m"
RED="\033[1;31m"
GREEN="\033[1;32m"
NC="\033[0m"
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
    clear
    echo -e "${COLORS[RED]}═══ REDÉMARRAGE IMMÉDIAT ═══${COLORS[NC]}"
    echo -e "${COLORS[RED]}ATTENTION : Le système va redémarrer immédiatement !${COLORS[NC]}"
    echo -ne "${COLORS[WHITE]}Confirmer le redémarrage ? [o/N] : ${COLORS[NC]}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
    echo -e "${COLORS[RED]}Redémarrage en cours...${COLORS[NC]}"
        shutdown -r now
    else
    echo -e "${COLORS[YELLOW]}Redémarrage annulé.${COLORS[NC]}"
    fi
}

# Immediate shutdown
immediate_shutdown() {
    clear
    echo -e "${COLORS[RED]}═══ ARRÊT IMMÉDIAT ═══${COLORS[NC]}"
    echo -e "${COLORS[RED]}ATTENTION : Le système va s'arrêter immédiatement !${COLORS[NC]}"
    echo -ne "${COLORS[WHITE]}Confirmer l'arrêt ? [o/N] : ${COLORS[NC]}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
    echo -e "${COLORS[RED]}Arrêt en cours...${COLORS[NC]}"
        shutdown -h now
    else
    echo -e "${COLORS[YELLOW]}Arrêt annulé.${COLORS[NC]}"
    fi
}

# Schedule reboot
schedule_reboot() {
    clear
    echo -e "${YELLOW}═══ PROGRAMMER UN REDÉMARRAGE ═══${NC}"
    echo -e "${WHITE}Formats acceptés :${NC}"
    echo -e "  - +X (dans X minutes)"
    echo -e "  - HH:MM (heure spécifique)"
    echo -e "  - now (immédiatement)"
    echo -ne "${WHITE}Quand redémarrer ? : ${NC}"
    read -r WHEN
    
    if [[ -n "$WHEN" ]]; then
        echo -ne "${WHITE}Message optionnel : ${NC}"
        read -r MESSAGE
        
        if [[ -n "$MESSAGE" ]]; then
            shutdown -r "$WHEN" "$MESSAGE"
        else
            shutdown -r "$WHEN"
        fi
        
        echo -e "${GREEN}✓ Redémarrage programmé${NC}"
    else
        echo -e "${RED}Heure invalide.${NC}"
    fi
}

# Schedule shutdown
schedule_shutdown() {
    clear
    echo -e "${YELLOW}═══ PROGRAMMER UN ARRÊT ═══${NC}"
    echo -e "${WHITE}Formats acceptés :${NC}"
    echo -e "  - +X (dans X minutes)"
    echo -e "  - HH:MM (heure spécifique)"
    echo -e "  - now (immédiatement)"
    echo -ne "${WHITE}Quand arrêter ? : ${NC}"
    read -r WHEN
    
    if [[ -n "$WHEN" ]]; then
        echo -ne "${WHITE}Message optionnel : ${NC}"
        read -r MESSAGE
        
        if [[ -n "$MESSAGE" ]]; then
            shutdown -h "$WHEN" "$MESSAGE"
        else
            shutdown -h "$WHEN"
        fi
        
        echo -e "${GREEN}✓ Arrêt programmé${NC}"
    else
        echo -e "${RED}Heure invalide.${NC}"
    fi
}

# Cancel scheduled task
cancel_scheduled_task() {
    clear
    echo -e "${YELLOW}═══ ANNULER UNE PROGRAMMATION ═══${NC}"
    
    if shutdown -c 2>/dev/null; then
        echo -e "${GREEN}✓ Tâche programmée annulée${NC}"
    else
        echo -e "${RED}Aucune tâche programmée ou erreur lors de l'annulation${NC}"
    fi
}

# Show scheduled tasks
show_scheduled_tasks() {
    clear
    echo -e "${YELLOW}═══ TÂCHES PROGRAMMÉES ═══${NC}"
    
    echo -e "${WHITE}Tâches shutdown/reboot :${NC}"
    if pgrep shutdown &>/dev/null; then
        echo -e "${YELLOW}Une tâche shutdown est active${NC}"
        ps aux | grep shutdown | grep -v grep
    else
        echo -e "${GREEN}Aucune tâche shutdown programmée${NC}"
    fi
    
    echo -e "\n${WHITE}Tâches cron système :${NC}"
        local cron_tasks=$(crontab -l 2>/dev/null)
        if [ -n "$cron_tasks" ]; then
            echo "$cron_tasks" | head -10
        else
            echo -e "${GREEN}Aucune tâche cron utilisateur programmée${NC}"
        fi
    
    echo -e "\n${WHITE}Timers systemd actifs :${NC}"
        local timers=$(systemctl list-timers --no-pager | head -10)
        if [ -n "$timers" ]; then
            echo "$timers"
        else
            echo -e "${GREEN}Aucun timer systemd actif${NC}"
        fi

        echo -e "\n${YELLOW}Appuyez sur une touche pour revenir au menu...${NC}"
        read -n 1 -r
}