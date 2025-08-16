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
            0) break ;;
            *) echo -e "\e[1;31mChoix invalide.\e[0m" ;;
        esac

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
        echo -e "${WHITE}Choisissez le type de programmation :${NC}"
    echo -e "  [1] Dans X minutes"
    echo -e "  [2] À une heure précise (HH:MM)"
    echo -e "  [3] À une date précise (JJ/MM/AAAA HH:MM)"
    echo -e "  [0] Annuler"
        echo -ne "${WHITE}Votre choix : ${NC}"
        read -r REBOOT_TYPE
        case $REBOOT_TYPE in
            1)
                echo -ne "${WHITE}Entrez le nombre de minutes (+X) ou 0 pour annuler : ${NC}"
                read -r MINUTES
                if [[ -z "$MINUTES" || "$MINUTES" == "0" ]]; then
                    echo -e "${YELLOW}Programmation annulée.${NC}"
                    return
                fi
                WHEN="+$MINUTES"
                ;;
            2)
                echo -ne "${WHITE}Entrez l'heure (HH:MM) ou 0 pour annuler : ${NC}"
                read -r HEURE
                if [[ -z "$HEURE" || "$HEURE" == "0" ]]; then
                    echo -e "${YELLOW}Programmation annulée.${NC}"
                    return
                fi
                WHEN="$HEURE"
                ;;
            3)
                echo -ne "${WHITE}Entrez la date et l'heure (JJ/MM/AAAA HH:MM) ou 0 pour annuler : ${NC}"
                read -r DATEHEURE
                if [[ -z "$DATEHEURE" || "$DATEHEURE" == "0" ]]; then
                    echo -e "${YELLOW}Programmation annulée.${NC}"
                    return
                fi
                DATE_CONV=$(echo "$DATEHEURE" | awk -F '[ /:]' '{printf "%04d-%02d-%02d %02d:%02d", $3, $2, $1, $4, $5}')
                WHEN="$DATE_CONV"
                ;;
            0)
                echo -e "${YELLOW}Programmation annulée.${NC}"
                return
                ;;
            *)
                echo -e "${RED}Choix invalide.${NC}"
                return
                ;;
        esac
        echo -ne "${WHITE}Message optionnel (laisser vide pour aucun, 0 pour annuler) : ${NC}"
        read -r MESSAGE
        if [[ "$MESSAGE" == "0" ]]; then
            echo -e "${YELLOW}Programmation annulée.${NC}"
            return
        fi
        echo -ne "${WHITE}Confirmer la programmation ? [o/N ou 0 pour annuler] : ${NC}"
        read -r CONFIRM
        if [[ "$CONFIRM" == "0" ]]; then
            echo -e "${YELLOW}Programmation annulée.${NC}"
            return
        fi
        if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
            if [[ "$REBOOT_TYPE" == "3" ]]; then
                # Utilisation de at pour programmer à une date précise
                if [[ -n "$MESSAGE" ]]; then
                    echo "shutdown -r now '$MESSAGE'" | at "$WHEN"
                else
                    echo "shutdown -r now" | at "$WHEN"
                fi
                echo -e "${GREEN}✓ Redémarrage programmé le $DATEHEURE${NC}"
            else
                if [[ -n "$MESSAGE" ]]; then
                    shutdown -r "$WHEN" "$MESSAGE"
                else
                    shutdown -r "$WHEN"
                fi
                echo -e "${GREEN}✓ Redémarrage programmé ($WHEN)${NC}"
            fi
        else
            echo -e "${YELLOW}Programmation annulée.${NC}"
        fi
}

# Schedule shutdown
schedule_shutdown() {
        clear
        echo -e "${YELLOW}═══ PROGRAMMER UN ARRÊT ═══${NC}"
        echo -e "${WHITE}Choisissez le type de programmation :${NC}"
    echo -e "  [1] Dans X minutes"
    echo -e "  [2] À une heure précise (HH:MM)"
    echo -e "  [3] À une date précise (JJ/MM/AAAA HH:MM)"
    echo -e "  [0] Annuler"
        echo -ne "${WHITE}Votre choix : ${NC}"
        read -r SHUT_TYPE
        case $SHUT_TYPE in
            1)
                echo -ne "${WHITE}Entrez le nombre de minutes (+X) ou 0 pour annuler : ${NC}"
                read -r MINUTES
                if [[ -z "$MINUTES" || "$MINUTES" == "0" ]]; then
                    echo -e "${YELLOW}Programmation annulée.${NC}"
                    return
                fi
                WHEN="+$MINUTES"
                ;;
            2)
                echo -ne "${WHITE}Entrez l'heure (HH:MM) ou 0 pour annuler : ${NC}"
                read -r HEURE
                if [[ -z "$HEURE" || "$HEURE" == "0" ]]; then
                    echo -e "${YELLOW}Programmation annulée.${NC}"
                    return
                fi
                WHEN="$HEURE"
                ;;
            3)
                echo -ne "${WHITE}Entrez la date et l'heure (JJ/MM/AAAA HH:MM) ou 0 pour annuler : ${NC}"
                read -r DATEHEURE
                if [[ -z "$DATEHEURE" || "$DATEHEURE" == "0" ]]; then
                    echo -e "${YELLOW}Programmation annulée.${NC}"
                    return
                fi
                DATE_CONV=$(echo "$DATEHEURE" | awk -F '[ /:]' '{printf "%04d-%02d-%02d %02d:%02d", $3, $2, $1, $4, $5}')
                WHEN="$DATE_CONV"
                ;;
            0)
                echo -e "${YELLOW}Programmation annulée.${NC}"
                return
                ;;
            *)
                echo -e "${RED}Choix invalide.${NC}"
                return
                ;;
        esac
        echo -ne "${WHITE}Message optionnel (laisser vide pour aucun, 0 pour annuler) : ${NC}"
        read -r MESSAGE
        if [[ "$MESSAGE" == "0" ]]; then
            echo -e "${YELLOW}Programmation annulée.${NC}"
            return
        fi
        echo -ne "${WHITE}Confirmer la programmation ? [o/N ou 0 pour annuler] : ${NC}"
        read -r CONFIRM
        if [[ "$CONFIRM" == "0" ]]; then
            echo -e "${YELLOW}Programmation annulée.${NC}"
            return
        fi
        if [[ "$CONFIRM" =~ ^[oOyY]$ ]]; then
            if [[ "$SHUT_TYPE" == "3" ]]; then
                if [[ -n "$MESSAGE" ]]; then
                    echo "shutdown -h now '$MESSAGE'" | at "$WHEN"
                else
                    echo "shutdown -h now" | at "$WHEN"
                fi
                echo -e "${GREEN}✓ Arrêt programmé le $DATEHEURE${NC}"
            else
                if [[ -n "$MESSAGE" ]]; then
                    shutdown -h "$WHEN" "$MESSAGE"
                else
                    shutdown -h "$WHEN"
                fi
                echo -e "${GREEN}✓ Arrêt programmé ($WHEN)${NC}"
            fi
        else
            echo -e "${YELLOW}Programmation annulée.${NC}"
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