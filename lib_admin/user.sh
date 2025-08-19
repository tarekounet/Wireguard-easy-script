# Valeur minimale pour la longueur du mot de passe
MIN_PASSWORD_LENGTH=8
#!/bin/bash
# Fonctions de gestion des utilisateurs

check_human_users() {
    local count=$(awk -F: '($3>=1000)&&($1!~/^(root|nobody|systemd|sshd|www-data|backup|games|mail|news|uucp|proxy|bin|daemon|lp|sync|list|ftp|_.*)$/){print $1}' /etc/passwd | wc -l)
    if [[ "$count" -eq 0 ]]; then
        clear
        echo -e "\e[48;5;24m\e[97m  👥 GESTION DES UTILISATEURS  \e[0m"
        echo -e "\n\e[1;31m❌ Aucun utilisateur humain trouvé.\e[0m"
        echo -e "\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
        return 1
    fi
}

create_technical_user() {
    clear
    echo -e "\e[48;5;236m\e[97m           👤 CRÉATION D'UTILISATEUR              \e[0m"
    
    echo -e "\n\e[48;5;24m\e[97m  📝 INFORMATIONS UTILISATEUR  \e[0m"
    
    # Étape 1: Nom d'utilisateur
    local NEWUSER=""
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           👤 CRÉATION D'UTILISATEUR              \e[0m"
        echo -e "\n\e[48;5;24m\e[97m  📝 ÉTAPE 1/3 - NOM D'UTILISATEUR  \e[0m"
        
        echo -e "\n\e[1;33mNom d'utilisateur :\e[0m"
        echo -e "\e[90m  • Format : lettres minuscules, chiffres, tiret, underscore\e[0m"
        echo -e "\e[90m  • Longueur : 2-32 caractères\e[0m"
        echo -e "\e[90m  • Tapez 'annuler' pour revenir au menu principal\e[0m"
        echo -ne "\e[1;36m→ \e[0m"
        read -r NEWUSER
        
        # Option d'annulation
        if [[ "$NEWUSER" == "annuler" || "$NEWUSER" == "cancel" || "$NEWUSER" == "exit" ]]; then
            echo -e "\e[1;33m❌ Création d'utilisateur annulée\e[0m"
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
            return
        fi
        
        if [[ -z "$NEWUSER" ]]; then
            echo -e "\e[1;31m✗ Le nom d'utilisateur ne peut pas être vide\e[0m"            continue
        elif ! validate_input "username" "$NEWUSER"; then
            echo -e "\e[1;31m✗ Format invalide\e[0m"            continue
        elif id "$NEWUSER" &>/dev/null; then
            echo -e "\e[1;31m✗ L'utilisateur '$NEWUSER' existe déjà\e[0m"            continue
        elif [[ "$NEWUSER" =~ ^(root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|ftp|nobody|systemd.*|_.*|sshd|messagebus|uuidd)$ ]]; then
            echo -e "\e[1;31m✗ Nom réservé au système\e[0m"            continue
        fi
        
        echo -e "\e[1;32m✓ Nom d'utilisateur valide : $NEWUSER\e[0m"
        while true; do
            echo -e "\n\e[1;33mQue souhaitez-vous faire ?\e[0m"
            echo -e "\e[90m[1]\e[0m Valider ce nom"
            echo -e "\e[90m[2]\e[0m Modifier le nom d'utilisateur"
            echo -e "\e[90m[0]\e[0m Annuler la création"
            echo -ne "\n\e[1;33mVotre choix : \e[0m"
            read -r CHOICE_USER
            case "$CHOICE_USER" in
                1)
                    break 2
                    ;;
                2)
                    continue 1
                    ;;
                0)
                    echo -e "\e[1;33m❌ Création d'utilisateur annulée\e[0m"
                    echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                    read -n1 -s
                    return
                    ;;
                *)
                    echo -e "\e[1;31mChoix invalide.\e[0m"
                    ;;
            esac
        done
    done
    
    # Étape 2: Mot de passe
    local NEWPASS=""
    while true; do
        clear
        echo -e "\e[48;5;236m\e[97m           👤 CRÉATION D'UTILISATEUR              \e[0m"
        echo -e "\n\e[48;5;24m\e[97m  📝 ÉTAPE 2/3 - MOT DE PASSE  \e[0m"
        
        echo -e "\n\e[90m📊 Informations saisies :\e[0m"
        echo -e "    \e[90m👤 Utilisateur :\e[0m \e[1;36m$NEWUSER\e[0m"
        
        echo -e "\n\e[1;33mMot de passe :\e[0m"
        echo -e "\e[90m  • Minimum ${MIN_PASSWORD_LENGTH} caractères\e[0m"
        echo -e "\e[90m  • Utilisez des majuscules, minuscules, chiffres et symboles\e[0m"
        echo -e "\e[90m  • Laissez vide pour revenir à l'étape précédente\e[0m"
        echo -ne "\e[1;36m→ \e[0m"
        read -rs NEWPASS
        echo
        
        # Option de retour en arrière
        if [[ -z "$NEWPASS" ]]; then
            echo -e "\e[1;33m⬅️  Retour à l'étape précédente\e[0m"            break  # Retourne à la boucle du nom d'utilisateur
        fi
        
        if [[ ${#NEWPASS} -lt $MIN_PASSWORD_LENGTH ]]; then
            echo -e "\e[1;31m✗ Mot de passe trop court (minimum ${MIN_PASSWORD_LENGTH} caractères)\e[0m"
            echo -e "\e[1;32mAppuyez sur une touche pour recommencer...\e[0m"
            read -n1 -s
            continue
        fi
        
        echo -ne "\e[1;33mConfirmation du mot de passe : \e[0m\e[1;36m→ \e[0m"
        read -rs NEWPASS2
        echo
        
        if [[ "$NEWPASS" != "$NEWPASS2" ]]; then
            echo -e "\e[1;31m✗ Les mots de passe ne correspondent pas\e[0m"
            echo -e "\e[1;32mAppuyez sur une touche pour recommencer...\e[0m"
            read -n1 -s
            continue
        fi
        
        echo -e "\e[1;32m✓ Mot de passe valide\e[0m"
        echo -e "\n\e[1;33mConfirmer ce mot de passe ? [o/N/retour] : \e[0m"
        read -r CONFIRM_PASS
        
        case "$CONFIRM_PASS" in
            [oOyY])
                # Étape 3: Récapitulatif et confirmation finale
                while true; do
                    clear
                    echo -e "\e[48;5;236m\e[97m           👤 CRÉATION D'UTILISATEUR              \e[0m"
                    echo -e "\n\e[48;5;24m\e[97m  📝 ÉTAPE 3/3 - CONFIRMATION FINALE  \e[0m"
                    
                    echo -e "\n\e[48;5;22m\e[97m  📋 RÉCAPITULATIF  \e[0m"
                    echo -e "\e[90m┌─────────────────────────────────────────────────┐\e[0m"
                    echo -e "\e[90m│\e[0m \e[1;36mUtilisateur :\e[0m $NEWUSER"
                    echo -e "\e[90m│\e[0m \e[1;36mGroupes :\e[0m docker, sudo"
                    echo -e "\e[90m│\e[0m \e[1;36mShell :\e[0m /bin/bash"
                    echo -e "\e[90m│\e[0m \e[1;36mDossier home :\e[0m /home/$NEWUSER"
                    echo -e "\e[90m│\e[0m \e[1;36mDossier script :\e[0m /home/$NEWUSER/wireguard-script-manager"
                    echo -e "\e[90m└─────────────────────────────────────────────────┘\e[0m"
                    
                    echo -e "\n\e[1;33mOptions disponibles :\e[0m"
                    echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
                    echo -e "\e[90m    ├─ \e[0m\e[1;32m V\e[0m \e[97mValider\e[0m"
                    echo -e "\e[90m    ├─ \e[0m\e[1;36m N\e[0m \e[97mModifier le nom d'utilisateur\e[0m"
                    echo -e "\e[90m    ├─ \e[0m\e[1;33m R\e[0m \e[97mModifier le mot de passe\e[0m"
                    echo -e "\e[90m    ├─ \e[0m\e[1;31m A\e[0m \e[97mAnnuler\e[0m"
                    echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
                    
                    echo -ne "\n\e[1;33mVotre choix [V/N/R/A] : \e[0m"
                    read -r FINAL_CHOICE
                    
                    case "$FINAL_CHOICE" in
                        [vV])
                            # Validation de l'utilisateur
                            echo -e "\n\e[1;33m🔄 Création de l'utilisateur en cours...\e[0m"
                            
                            if useradd -m -s /bin/bash -G docker "$NEWUSER" 2>/dev/null; then
                                if echo "$NEWUSER:$NEWPASS" | chpasswd 2>/dev/null; then
                                    USER_HOME="/home/$NEWUSER"
                                    USER_SCRIPT_DIR="$USER_HOME/wireguard-script-manager"
                                    mkdir -p "$USER_SCRIPT_DIR"
                                    chown -R "$NEWUSER:$NEWUSER" "$USER_SCRIPT_DIR"
                                    chmod 775 "$USER_SCRIPT_DIR"
                                    
                                    echo -e "\n\e[1;32m✅ UTILISATEUR CRÉÉ AVEC SUCCÈS\e[0m"
                                    echo -e "\e[90m┌─────────────────────────────────────────────────┐\e[0m"
                                    echo -e "\e[90m│\e[0m \e[1;36mUtilisateur :\e[0m $NEWUSER"
                                    echo -e "\e[90m│\e[0m \e[1;36mGroupes :\e[0m docker"
                                    echo -e "\e[90m│\e[0m \e[1;36mDossier :\e[0m $USER_SCRIPT_DIR"
                                    echo -e "\e[90m└─────────────────────────────────────────────────┘\e[0m"
                                    
                                    echo -ne "\n\e[1;33mConfigurer le lancement automatique du script ? [o/N] : \e[0m"
                                    read -r AUTOSTART
                                    if [[ "$AUTOSTART" =~ ^[oOyY]$ ]]; then
                                        configure_user_autostart "$NEWUSER" "$USER_SCRIPT_DIR"
                                    fi
                                    
                                    echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                                    read -n1 -s
                                    return
                                else
                                    echo -e "\e[1;31m❌ Erreur lors de la définition du mot de passe\e[0m"
                                    userdel -r "$NEWUSER" 2>/dev/null || true
                                fi
                            else
                                echo -e "\e[1;31m❌ Erreur lors de la création de l'utilisateur\e[0m"
                            fi
                            
                            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                            read -n1 -s
                            return
                            ;;
                        [rR])
                            break 2  # Retourne à la saisie du mot de passe
                            ;;
                        [aA])
                            echo -e "\e[1;33m❌ Création d'utilisateur annulée\e[0m"
                            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                            read -n1 -s
                            return
                            ;;
                        *)
                            echo -e "\e[1;31m✗ Choix invalide. Utilisez C, R ou A\e[0m"                            ;;
                    esac
                done
                ;;
            [rR]|retour)
                continue  # Recommence la saisie du mot de passe
                ;;
            *)
                echo -e "\e[1;33m❌ Création d'utilisateur annulée\e[0m"
                echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
                read -n1 -s
                return
                ;;
        esac
    done
}

user_management_menu() {
    check_human_users || return
    while true; do
        clear
    echo -e "\e[48;5;236m\e[97m           👥 GESTION DES UTILISATEURS           \e[0m"

        # Liste des utilisateurs humains
        mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody")&&($7!="/usr/sbin/nologin")&&($7!="/bin/false")&&($7!="/sbin/nologin")&&($7!="")&&($1!~"^_")&&($1!~"^systemd")&&($1!~"^daemon")&&($1!~"^mail")&&($1!~"^ftp")&&($1!~"^www-data")&&($1!~"^backup")&&($1!~"^list")&&($1!~"^proxy")&&($1!~"^uucp")&&($1!~"^news")&&($1!~"^gnats"){print $1}' /etc/passwd)

        if [[ ${#USERS[@]} -eq 0 ]]; then
            echo -e "\n\e[1;31m❌ Aucun utilisateur humain trouvé.\e[0m"
            echo -e "\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
            return
        fi

        echo -e "\n\e[48;5;24m\e[97m  👥 UTILISATEURS DISPONIBLES  \e[0m"
        echo -e "\e[90m┌─────────────────────────────────────────────────────────────┐\e[0m"
        for i in "${!USERS[@]}"; do
            num=$((i+1))
            echo -e "\e[90m│\e[0m [${num}] \e[1;36m${USERS[i]}\e[0m"
        done
        echo -e "\e[90m└─────────────────────────────────────────────────────────────┘\e[0m"

    echo -e "\n\e[48;5;22m\e[97m  🔧 ACTIONS DISPONIBLES  \e[0m"
    echo -e "\e[90m┌─────────────────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36mA\e[0m Ajouter un utilisateur"
    echo -e "\e[90m│\e[0m \e[1;36mM\e[0m Modifier un utilisateur"
    echo -e "\e[90m│\e[0m \e[1;36mS\e[0m Supprimer un utilisateur"
    echo -e "\e[90m│\e[0m \e[1;31m0\e[0m Retour au menu principal"
    echo -e "\e[90m└─────────────────────────────────────────────────────────────┘\e[0m"

        echo -ne "\n\e[1;33m👉 Votre choix : \e[0m"
        read -r CHOICE

        case $CHOICE in
            [Aa])
                create_technical_user
                ;;
            [Mm])
                modify_user_menu
                ;;
            [Ss])
                remove_user_secure
                ;;
            0)
                break
                ;;
            *)
                echo -e "\e[1;31m❌ Choix invalide !\e[0m"
                ;;
        esac
    done
}

modify_user_menu() {
    clear
    echo -e "\e[48;5;236m\e[97m           ✏️  MODIFICATION D'UTILISATEUR          \e[0m"
    
    # Filter only real human users: UID >= 1000, valid shell, exclude system accounts
    mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody")&&($7!="/usr/sbin/nologin")&&($7!="/bin/false")&&($7!="/sbin/nologin")&&($7!="")&&($1!~"^_")&&($1!~"^systemd")&&($1!~"^daemon")&&($1!~"^mail")&&($1!~"^ftp")&&($1!~"^www-data")&&($1!~"^backup")&&($1!~"^list")&&($1!~"^proxy")&&($1!~"^uucp")&&($1!~"^news")&&($1!~"^gnats"){print $1}' /etc/passwd)
    
    if [[ ${#USERS[@]} -eq 0 ]]; then
        echo -e "\n\e[1;31m❌ Aucun utilisateur humain trouvé.\e[0m"
        echo -e "\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
        return
    fi
    
    echo -e "\n\e[48;5;24m\e[97m  👥 UTILISATEURS DISPONIBLES  \e[0m"
    echo -e "\e[90m┌─────┬─────────────────┬─────────────────┬─────────────────────────────┐\e[0m"
    echo -e "\e[90m│\e[0m \e[1;36mNum\e[0m \e[90m│\e[0m \e[1;36mUtilisateur\e[0m     \e[90m│\e[0m \e[1;36mShell\e[0m           \e[90m│\e[0m \e[1;36mRépertoire\e[0m              \e[90m│\e[0m"
    echo -e "\e[90m├─────┼─────────────────┼─────────────────┼─────────────────────────────┤\e[0m"
    
    for i in "${!USERS[@]}"; do
        local user="${USERS[$i]}"
        local shell=$(getent passwd "$user" | cut -d: -f7)
        local home=$(getent passwd "$user" | cut -d: -f6)
    printf "\e[90m│\e[0m %-15s \e[90m│\e[0m %-15s \e[90m│\e[0m %-27s \e[90m│\e[0m\n" "$user" "$(basename "$shell")" "$home"
    done
    
    echo -e "\e[90m└─────┴─────────────────┴─────────────────┴─────────────────────────────┘\e[0m"
    echo -e "\n\e[48;5;22m\e[97m  🔧 ACTIONS DISPONIBLES  \e[0m"
    echo -e "\e[90m┌─────────────────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m│\e[0m \e[1;31m0\e[0m Retour au menu principal"
    echo -e "\e[90m└─────────────────────────────────────────────────────────────┘\e[0m"
    echo -ne "\n\e[1;33mSélectionnez un utilisateur [1-${#USERS[@]}] ou 0 pour annuler : \e[0m"
    read -r IDX
    
    if [[ "$IDX" == "0" ]]; then
        return
    fi
    
    IDX=$((IDX-1))
    if [[ $IDX -ge 0 && $IDX -lt ${#USERS[@]} ]]; then
        local SELECTED_USER="${USERS[$IDX]}"
        user_modification_options "$SELECTED_USER"
    else
        echo -e "\e[1;31m✗ Sélection invalide.\e[0m"
    fi
}

user_modification_options() {
    local user="$1"
    while true; do
        clear
    echo -e "${COLORS[YELLOW]}═══ MODIFICATION DE L'UTILISATEUR : $user ═══${COLORS[NC]}"
    echo -e "${COLORS[WHITE]}[1]${COLORS[NC]} Changer le mot de passe"
    echo -e "${COLORS[WHITE]}[2]${COLORS[NC]} Modifier les groupes"
    echo -e "${COLORS[WHITE]}[3]${COLORS[NC]} Verrouiller/Déverrouiller le compte"
    echo -e "${COLORS[WHITE]}[4]${COLORS[NC]} Définir l'expiration du mot de passe"
    echo -e "${COLORS[WHITE]}[5]${COLORS[NC]} Voir les informations de l'utilisateur"
    echo -e "${COLORS[WHITE]}[0]${COLORS[NC]} Retour"
    echo -ne "${COLORS[WHITE]}Votre choix [0-5] : ${COLORS[NC]}"
        read -r SUBCHOICE
        case $SUBCHOICE in
            1)
                echo -e "${COLORS[YELLOW]}Changement du mot de passe pour $user...${COLORS[NC]}"
                passwd "$user"
                ;;
            2)
                modify_user_groups "$user"
                ;;
            3)
                toggle_user_lock "$user"
                ;;
            4)
                set_password_expiry "$user"
                ;;
            5)
                show_user_info "$user"
                ;;
            0)
                break
                ;;
            *)
                echo -e "${COLORS[RED]}Sélection invalide.${COLORS[NC]}"
                ;;
        esac
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
    done
}

remove_user_secure() {
    while true; do
        clear
        echo -e "\e[48;5;52m\e[97m  🗑️ SUPPRESSION SÉCURISÉE D'UN UTILISATEUR  \e[0m"
        echo -e "\e[90m┌─────────────────────────────────────────────────────────────┐\e[0m"
        # Liste des utilisateurs humains
        mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody")&&($7!="/usr/sbin/nologin")&&($7!="/bin/false")&&($7!="/sbin/nologin")&&($7!="")&&($1!~"^_")&&($1!~"^systemd")&&($1!~"^daemon")&&($1!~"^mail")&&($1!~"^ftp")&&($1!~"^www-data")&&($1!~"^backup")&&($1!~"^list")&&($1!~"^proxy")&&($1!~"^uucp")&&($1!~"^news")&&($1!~"^gnats"){print $1}' /etc/passwd)
        if [[ ${#USERS[@]} -eq 0 ]]; then
            echo -e "\e[1;31m❌ Aucun utilisateur humain trouvé.\e[0m"
            echo -e "\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
            return
        fi
        echo -e "\e[1;33mUtilisateurs humains pouvant être supprimés :\e[0m"
        echo -e "\e[90m│\e[0m"
        for i in "${!USERS[@]}"; do
            local user="${USERS[$i]}"
            local shell=$(getent passwd "$user" | cut -d: -f7)
            local home=$(getent passwd "$user" | cut -d: -f6)
            printf "\e[90m│\e[0m [\e[1;36m%d\e[0m] \e[97m%-15s\e[0m  \e[1;34mShell:\e[0m %-15s  \e[1;32mHome:\e[0m %s\n" $((i+1)) "$user" "$shell" "$home"
        done
        echo -e "\e[90m└─────────────────────────────────────────────────────────────┘\e[0m"
        echo -e "\n\e[1;31m[0] Retour au menu précédent\e[0m"
        echo -ne "\n\e[1;33mNuméro de l'utilisateur à supprimer [1-${#USERS[@]}] : \e[0m"
        read -r IDX
        if [[ "$IDX" == "0" ]]; then
            break
        fi
        IDX=$((IDX-1))
        if [[ $IDX -ge 0 && $IDX -lt ${#USERS[@]} ]]; then
            local TARGET_USER="${USERS[$IDX]}"
            echo -e "\e[1;31mATTENTION : Ceci supprimera définitivement l'utilisateur '$TARGET_USER' et toutes ses données !\e[0m"
            echo -ne "\e[1;31mTapez 'SUPPRIMER $TARGET_USER' pour confirmer : \e[0m"
            read -r CONFIRMATION
            if [[ "$CONFIRMATION" == "SUPPRIMER $TARGET_USER" ]]; then
                pkill -u "$TARGET_USER" 2>/dev/null || true
                pkill -9 -u "$TARGET_USER" 2>/dev/null || true
                deluser --remove-home "$TARGET_USER" 2>/dev/null || userdel -r "$TARGET_USER"
                echo -e "\e[1;32m✓ Utilisateur '$TARGET_USER' supprimé avec succès\e[0m"
            else
                echo -e "\e[1;33mOpération annulée.\e[0m"
            fi
        else
            echo -e "\e[1;31mSélection invalide.\e[0m"
        fi
        echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
    done
}

modify_user_groups() {
    local user="$1"
    
    # Vérifier que c'est un utilisateur humain
    if ! is_human_user "$user"; then
        echo -e "${RED}Erreur : '$user' n'est pas un utilisateur humain valide.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    
    clear
    echo -e "${YELLOW}═══ MODIFICATION DES GROUPES POUR : $user ═══${NC}"
    
    echo -e "${WHITE}Groupes actuels :${NC}"
    groups "$user"
    
    echo -e "\n${WHITE}Groupes disponibles :${NC}"
    echo "docker, sudo, www-data, users, plugdev, netdev"
    
    echo -e "\n${WHITE}Options :${NC}"
    echo "[1] Ajouter à un groupe"
    echo "[2] Retirer d'un groupe"
    echo "[0] Retour"
    
    echo -ne "${WHITE}Votre choix [0-2] : ${NC}"
    read -r GROUP_CHOICE
    
    case $GROUP_CHOICE in
        1)
            echo -ne "${WHITE}Nom du groupe à ajouter : ${NC}"
            read -r GROUP_NAME
            if getent group "$GROUP_NAME" &>/dev/null; then
                usermod -a -G "$GROUP_NAME" "$user"
                echo -e "${GREEN}✓ Utilisateur $user ajouté au groupe $GROUP_NAME${NC}"
            else
                echo -e "${RED}Groupe $GROUP_NAME introuvable${NC}"
            fi
            ;;
        2)
            echo -ne "${WHITE}Nom du groupe à retirer : ${NC}"
            read -r GROUP_NAME
            if groups "$user" | grep -q "$GROUP_NAME"; then
                gpasswd -d "$user" "$GROUP_NAME"
                echo -e "${GREEN}✓ Utilisateur $user retiré du groupe $GROUP_NAME${NC}"
            else
                echo -e "${RED}L'utilisateur $user n'est pas dans le groupe $GROUP_NAME${NC}"
            fi
            ;;
    esac
}

toggle_user_lock() {
    local user="$1"
    
    # Vérifier que c'est un utilisateur humain
    if ! is_human_user "$user"; then
        echo -e "${RED}Erreur : '$user' n'est pas un utilisateur humain valide.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    
    clear
    echo -e "${YELLOW}═══ VERROUILLAGE/DEVERROUILLAGE : $user ═══${NC}"
    
    # Check current lock status
    if passwd -S "$user" | grep -q " L "; then
        echo -e "${RED}L'utilisateur $user est actuellement VERROUILLE${NC}"
        echo -ne "${WHITE}Deverrouiller le compte ? [o/N] : ${NC}"
        read -r UNLOCK
        if [[ "$UNLOCK" =~ ^[oOyY]$ ]]; then
            passwd -u "$user"
            echo -e "${GREEN}✓ Compte $user deverrouille${NC}"
        fi
    else
        echo -e "${GREEN}L'utilisateur $user est actuellement DEVERROUILLE${NC}"
        echo -ne "${WHITE}Verrouiller le compte ? [o/N] : ${NC}"
        read -r LOCK
        if [[ "$LOCK" =~ ^[oOyY]$ ]]; then
            passwd -l "$user"
            echo -e "${RED}✓ Compte $user verrouille${NC}"
        fi
    fi

}

set_password_expiry() {
    local user="$1"
    
    # Vérifier que c'est un utilisateur humain
    if ! is_human_user "$user"; then
        echo -e "${RED}Erreur : '$user' n'est pas un utilisateur humain valide.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    
    clear
    echo -e "${YELLOW}═══ EXPIRATION DU MOT DE PASSE : $user ═══${NC}"
    
    echo -e "${WHITE}Informations actuelles :${NC}"
    chage -l "$user"
    
    echo -e "\n${WHITE}Options :${NC}"
    echo "[1] Définir une date d'expiration"
    echo "[2] Forcer le changement au prochain login"
    echo "[3] Supprimer l'expiration"
    echo "[0] Retour"
    
    echo -ne "${WHITE}Votre choix [0-3] : ${NC}"
    read -r EXPIRY_CHOICE
    
    case $EXPIRY_CHOICE in
        1)
            echo -ne "${WHITE}Date d'expiration (YYYY-MM-DD) : ${NC}"
            read -r EXPIRY_DATE
            if [[ "$EXPIRY_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                chage -E "$EXPIRY_DATE" "$user"
                echo -e "${GREEN}✓ Date d'expiration définie${NC}"
            else
                echo -e "${RED}Format de date invalide${NC}"
            fi
            ;;
        2)
            chage -d 0 "$user"
            echo -e "${GREEN}✓ Changement de mot de passe force au prochain login${NC}"
            ;;
        3)
            chage -E -1 "$user"
            echo -e "${GREEN}✓ Expiration supprimee${NC}"
            ;;
    esac
}

show_user_info() {
    local user="$1"
    
    # Vérifier que c'est un utilisateur humain
    if ! is_human_user "$user"; then
        echo -e "${RED}Erreur : '$user' n'est pas un utilisateur humain valide.${NC}"
        read -n1 -r -p "Appuyez sur une touche pour continuer..." _
        return
    fi
    
    clear
    echo -e "${YELLOW}═══ INFORMATIONS DETAILLEES : $user ═══${NC}"
    
    echo -e "${WHITE}Informations de base :${NC}"
    id "$user"
    
    echo -e "\n${WHITE}Informations du compte :${NC}"
    getent passwd "$user"
    
    echo -e "\n${WHITE}Statut du mot de passe :${NC}"
    passwd -S "$user"
    
    echo -e "\n${WHITE}Informations d'expiration :${NC}"
    chage -l "$user"
    
    echo -e "\n${WHITE}Dernières connexions :${NC}"
    last "$user" | head -5
    
    echo -e "\n${WHITE}Processus actifs :${NC}"
    ps -u "$user" --no-headers | wc -l | xargs echo "Nombre de processus :"
    
    if [[ -d "/home/$user" ]]; then
        echo -e "\n${WHITE}Utilisation disque du répertoire home :${NC}"
        du -sh "/home/$user" 2>/dev/null || echo "Impossible de calculer"
    fi
}

configure_user_autostart() {
    local user="$1"
    local script_dir="$2"
    local profile="/home/$user/.bash_profile"
    local script_path="$script_dir/config_wg.sh"
    local github_url="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh"
    
    echo -e "${YELLOW}Configuration du demarrage automatique pour $user...${NC}"
    
    # Télécharger le script config_wg.sh depuis GitHub
    echo -e "${WHITE}Telechargement du script config_wg.sh depuis GitHub...${NC}"
    if command -v curl &>/dev/null; then
        if curl -fsSL "$github_url" -o "$script_path"; then
            echo -e "${GREEN}✓ Script telecharge avec succes${NC}"
        else
            echo -e "${RED}✗ Echec du telechargement avec curl${NC}"
            # Essayer avec wget si curl echoue
            if command -v wget &>/dev/null; then
                echo -e "${WHITE}Tentative avec wget...${NC}"
                if wget -q "$github_url" -O "$script_path"; then
                    echo -e "${GREEN}✓ Script telecharge avec wget${NC}"
                else
                    echo -e "${RED}✗ Echec du telechargement avec wget${NC}"
                    echo -e "${YELLOW}Creation d'un script de demarrage basique...${NC}"
                    create_basic_startup_script "$script_path"
                fi
            else
                echo -e "${YELLOW}Creation d'un script de demarrage basique...${NC}"
                create_basic_startup_script "$script_path"
            fi
        fi
    elif command -v wget &>/dev/null; then
        if wget -q "$github_url" -O "$script_path"; then
            echo -e "${GREEN}✓ Script telecharge avec wget${NC}"
        else
            echo -e "${RED}✗ Echec du telechargement avec wget${NC}"
            echo -e "${YELLOW}Creation d'un script de demarrage basique...${NC}"
            create_basic_startup_script "$script_path"
        fi
    else
        echo -e "${RED}Ni curl ni wget disponible${NC}"
        echo -e "${YELLOW}Creation d'un script de demarrage basique...${NC}"
        create_basic_startup_script "$script_path"
    fi
    
    # Rendre le script executable
    chmod +x "$script_path"
    chown "$user:$user" "$script_path"
    
    # Configurer le demarrage automatique dans .bash_profile
    if ! grep -q "$script_path" "$profile" 2>/dev/null; then
        echo '# Auto-start Wireguard management script' >> "$profile"
        echo '[[ $- == *i* ]] && cd ~/wireguard-script-manager && bash ./config_wg.sh' >> "$profile"
        chown "$user:$user" "$profile"
        chmod 644 "$profile"
        echo -e "${GREEN}✓ Demarrage automatique configure pour $user${NC}"
    else
        echo -e "${YELLOW}Demarrage automatique deja configure pour $user${NC}"
    fi
}
