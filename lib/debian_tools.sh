DEBIAN_TOOLS_VERSION="1.0.0"

debian_tools_menu() {
    SKIP_PAUSE=1
    while true; do
        clear
        echo -e "\n\e[2;35m--------------------------------------------------\e[0m"
        echo -e "\e[1;36m            🐧 MENU OUTILS SYSTÈME 🐧\e[0m"
        echo -e "\e[2;35m--------------------------------------------------\e[0m"

        echo -e "\n\e[1;33m--- Informations système ---\e[0m"
        echo -e "\e[1;32m1) \e[0m\e[0;37m📦 Afficher la version de Debian\e[0m"
        echo -e "\e[1;32m2) \e[0m\e[0;37m💾 Afficher l'espace disque\e[0m"
        echo -e "\e[1;32m7) \e[0m\e[0;37m🐳 Afficher l'état du service Docker\e[0m"
        echo -e "\e[1;32m8) \e[0m\e[0;37m📊 Moniteur système : Afficher les performances (btop)\e[0m"

        echo -e "\n\e[1;33m--- Administration réseau ---\e[0m"
        echo -e "\e[1;32m4) \e[0m\e[0;37m🌐 Modifier l'adresse IP du serveur\e[0m"

        echo -e "\n\e[1;33m--- Administration système ---\e[0m"
        UPDATE_COUNT=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
        if [[ "$UPDATE_COUNT" -gt 0 ]]; then
            echo -e "\e[1;32m3)  \e[0m\e[5;32m🔄 Mettre à jour le système (apt update & upgrade) - $UPDATE_COUNT paquet(s) à mettre à jour\e[0m"
        else
            echo -e "\e[1;90m3)  🔄 Pas de mise à jour disponible\e[0m"
        fi
        echo -e "\e[1;32m5)  \e[0m\e[0;37m🖥️ Modifier le nom de la VM\e[0m"
        echo -e "\e[1;32m6)  \e[0m\e[0;37m🔐 Modifier le port SSH\e[0m"
        echo -e "\e[1;32m10) \e[0m\e[0;37m🔁 Redémarrer la VM\e[0m"
        echo -e "\e[1;32m11) \e[0m\e[0;37m⚡ Éteindre la VM\e[0m"

        echo -e "\n\e[1;33m--- Divers ---\e[0m"
        echo -e "\e[1;32m9) \e[0m\e[0;37m💻 Ouvrir une session bash\e[0m"

        echo -e "\n\e[1;32m0) \e[0m\e[0;37m❌ Retour au menu principal\e[0m"
        echo
        read -p $'\e[1;33mVotre choix (Debian) : \e[0m' DEBIAN_ACTION
        clear
        case $DEBIAN_ACTION in
            1)
                if [[ -f /etc/debian_version ]]; then
                    echo -e "\e[1;32mVersion Debian :\e[0m $(cat /etc/debian_version)"
                else
                    echo -e "\e[1;31mCe système n'est pas Debian.\e[0m"
                fi
                SKIP_PAUSE_DEBIAN=0
                ;;
            2)
                df -h
                SKIP_PAUSE_DEBIAN=0
                ;;
            3)
                if [[ "$UPDATE_COUNT" -gt 0 ]]; then
                    echo -e "\e[1;33mMise à jour du système...\e[0m"
                    sudo apt update && sudo apt upgrade -y
                    SKIP_PAUSE_DEBIAN=0
                fi
                ;;
            4)
                echo -e "\e[1;33mInterfaces réseau physiques détectées :\e[0m"
                ip -o link show | awk -F': ' '$3 ~ /ether/ && $2 ~ /^eth/ {print NR-1")",$2}'
                read -p $'\e[1;33mNuméro de l\'interface à modifier (laisser vide pour annuler) : \e[0m' IFACE_NUM
                if [[ -z "$IFACE_NUM" ]]; then
                    echo -e "\e[1;33mModification annulée.\e[0m"
                    SKIP_PAUSE_DEBIAN=0
                    break
                fi
                IFACE=$(ip -o link show | awk -F': ' '$3 ~ /ether/ && $2 ~ /^eth/ {print $2}' | sed -n "$((IFACE_NUM))p")
                if [[ -z "$IFACE" ]]; then
                    echo -e "\e[1;31mInterface invalide.\e[0m"
                    SKIP_PAUSE_DEBIAN=0
                    break
                fi

                # Vérification du mode actuel (DHCP ou statique)
                DHCP_STATE="Statique"
                if nmcli device show "$IFACE" 2>/dev/null | grep -q "IP4.DHCP4.OPTION"; then
                    DHCP_STATE="DHCP"
                fi
                echo -e "\e[1;33mMode actuel de l\'interface $IFACE :\e[0m $DHCP_STATE"

                read -p $'\e[1;33mVoulez-vous conserver ce mode ? (o/N) : \e[0m' KEEP_MODE
                if [[ "$KEEP_MODE" == "o" || "$KEEP_MODE" == "O" ]]; then
                    echo -e "\e[1;33mMode conservé.\e[0m"
                else
                    if [[ "$DHCP_STATE" == "DHCP" ]]; then
                        echo -e "\e[1;33mPassage en mode statique...\e[0m"
                        sudo nmcli con mod "$IFACE" ipv4.method manual
                    else
                        echo -e "\e[1;33mPassage en mode DHCP...\e[0m"
                        sudo nmcli con mod "$IFACE" ipv4.method auto
                        sudo nmcli con up "$IFACE"
                        echo -e "\e[1;32mMode DHCP appliqué.\e[0m"
                        SKIP_PAUSE_DEBIAN=0
                        break
                    fi
                fi

                # Modification des valeurs en mode statique
                CUR_IP=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}')
                echo -e "\e[1;33mAdresse IP actuelle de $IFACE :\e[0m $CUR_IP"
                read -p $'\e[1;33mVoulez-vous modifier l\'adresse IP ? (o/N) : \e[0m' MODIFY_IP
                if [[ "$MODIFY_IP" == "o" || "$MODIFY_IP" == "O" ]]; then
                    read -p $'\e[1;33mNouvelle adresse IP (ex : 192.168.1.100, laisser vide pour annuler) : \e[0m' NEW_IP
                    if [[ -z "$NEW_IP" ]]; then
                        echo -e "\e[1;33mModification annulée.\e[0m"
                        SKIP_PAUSE_DEBIAN=0
                        break
                    fi
                    MODIF_RESEAU=1
                else
                    NEW_IP=$(echo "$CUR_IP" | cut -d '/' -f 1)
                fi

                # Masque
                CUR_MASK=$(echo "$CUR_IP" | cut -d '/' -f 2)
                CUR_MASK_DECIMAL=$(ipcalc -m "$CUR_IP" | awk '/Netmask/ {print $2}')
                echo -e "\e[1;33mMasque de sous-réseau actuel :\e[0m $CUR_MASK_DECIMAL"
                read -p $'\e[1;33mVoulez-vous modifier le masque de sous-réseau ? (o/N) : \e[0m' MODIFY_MASK
                if [[ "$MODIFY_MASK" == "o" || "$MODIFY_MASK" == "O" ]]; then
                    read -p $'\e[1;33mNouveau masque de sous-réseau (ex : 255.255.255.0, laisser vide pour 255.255.255.0) : \e[0m' NEW_MASK_DECIMAL
                    NEW_MASK_DECIMAL=${NEW_MASK_DECIMAL:-255.255.255.0}
                    NEW_MASK=$(ipcalc -p "$NEW_IP/$NEW_MASK_DECIMAL" | awk '/Prefix/ {print $2}')
                    MODIF_RESEAU=1
                else
                    NEW_MASK="$CUR_MASK"
                fi

                # Passerelle
                CUR_GW=$(ip route | awk '/default/ {print $3}')
                echo -e "\e[1;33mPasserelle actuelle :\e[0m $CUR_GW"
                read -p $'\e[1;33mVoulez-vous modifier la passerelle ? (o/N) : \e[0m' MODIFY_GW
                if [[ "$MODIFY_GW" == "o" || "$MODIFY_GW" == "O" ]]; then
                    read -p $'\e[1;33mNouvelle passerelle (laisser vide pour aucune modification) : \e[0m' NEW_GW
                    MODIF_RESEAU=1
                else
                    NEW_GW="$CUR_GW"
                fi

                # DNS
                CUR_DNS=$(grep "nameserver" /etc/resolv.conf | awk '{print $2}' | head -n 1)
                echo -e "\e[1;33mDNS actuel :\e[0m $CUR_DNS"
                read -p $'\e[1;33mVoulez-vous modifier le DNS ? (o/N) : \e[0m' MODIFY_DNS
                if [[ "$MODIFY_DNS" == "o" || "$MODIFY_DNS" == "O" ]]; then
                    read -p $'\e[1;33mNouveau DNS (laisser vide pour aucune modification) : \e[0m' NEW_DNS
                    MODIF_RESEAU=1
                else
                    NEW_DNS="$CUR_DNS"
                fi

                # Appliquer uniquement si au moins une modification
                if [[ "$MODIF_RESEAU" == "1" ]]; then
                    sudo ip addr flush dev "$IFACE"
                    sudo ip addr add "$NEW_IP/$NEW_MASK" dev "$IFACE"
                    if [[ -n "$NEW_GW" ]]; then
                        sudo ip route replace default via "$NEW_GW" dev "$IFACE"
                    fi
                    if [[ -n "$NEW_DNS" ]]; then
                        echo "nameserver $NEW_DNS" | sudo tee /etc/resolv.conf > /dev/null
                    fi
                    sudo systemctl restart networking 2>/dev/null || sudo systemctl restart NetworkManager 2>/dev/null
                    echo -e "\e[1;32mConfiguration appliquée. Attention, la connexion SSH peut être interrompue.\e[0m"
                else
                    echo -e "\e[1;33mAucune modification réseau appliquée.\e[0m"
                fi
                SKIP_PAUSE_DEBIAN=0
                ;;
            5)
                echo -e "\n\e[1;36m------ Modifier le nom de la VM ------\e[0m"
                read -p $'\e[1;33mNouveau nom de la VM (hostname, laisser vide pour aucune modification) : \e[0m' NEW_HOSTNAME
                if [[ -n "$NEW_HOSTNAME" ]]; then
                    echo -e "\e[1;32mChangement du nom de la VM en : $NEW_HOSTNAME\e[0m"
                    sudo hostnamectl set-hostname "$NEW_HOSTNAME"
                fi
                SKIP_PAUSE_DEBIAN=0
                ;;
            6)
                echo -e "\n\e[1;36m------ Modifier le port SSH ------\e[0m"
                CURRENT_SSH_PORT=$(grep -E '^Port ' /etc/ssh/sshd_config | head -n1 | awk '{print $2}')
                CURRENT_SSH_PORT=${CURRENT_SSH_PORT:-22}
                echo -e "\e[1;33mPort SSH actuel : $CURRENT_SSH_PORT\e[0m"
                read -p $'\e[1;33mNouveau port SSH (laisser vide pour aucune modification) : \e[0m' NEW_SSH_PORT
                if [[ -n "$NEW_SSH_PORT" ]]; then
                    if [[ "$NEW_SSH_PORT" =~ ^[0-9]+$ ]] && (( NEW_SSH_PORT >= 1 && NEW_SSH_PORT <= 65535 )); then
                        sudo sed -i "s/^#\?Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
                        sudo systemctl restart sshd
                        echo -e "\e[1;32mPort SSH modifié à $NEW_SSH_PORT. Attention, la connexion SSH peut être interrompue.\e[0m"
                    else
                        echo -e "\e[1;31mPort SSH invalide. Aucune modification appliquée.\e[0m"
                    fi
                fi
                SKIP_PAUSE_DEBIAN=0
                ;;
            7)
                systemctl status docker --no-pager
                SKIP_PAUSE_DEBIAN=0
                ;;
            8)
                if command -v btop >/dev/null 2>&1; then
                    btop
                else
                    echo -e "\e[1;31mbtop n'est pas installé. Installation...\e[0m"
                    sudo apt update && sudo apt install -y btop
                    btop
                fi
                SKIP_PAUSE_DEBIAN=1
                continue
                ;;
            9)
                echo -e "\e[1;33mVous pouvez maintenant exécuter des commandes dans la console.\e[0m"
                echo -e "\e[1;33mTaper exit pour revenir au menu principal.\e[0m"
                trap 'echo -e "\n\e[1;33mRetour au menu principal...\e[0m"; break' SIGINT
                bash --norc --noprofile
                SKIP_PAUSE_DEBIAN=1
                continue
                ;;
            10)
                if ask_tech_password; then
                    echo -e "\e[1;33mRedémarrage de la VM...\e[0m"
                    sudo reboot
                else
                    echo -e "\e[1;31mRedémarrage annulé.\e[0m"
                fi
                SKIP_PAUSE_DEBIAN=0
                ;;
            11)
                if ask_tech_password; then
                    echo -e "\e[1;33mExtinction de la VM...\e[0m"
                    sudo poweroff
                else
                    echo -e "\e[1;31mExtinction annulée.\e[0m"
                fi
                SKIP_PAUSE_DEBIAN=0
                ;;
            0)
                break
                ;;
            *)
                echo -e "\e[1;31mChoix invalide.\e[0m"
                SKIP_PAUSE_DEBIAN=0
                ;;
        esac
        if [[ "$SKIP_PAUSE_DEBIAN" != "1" ]]; then
            echo -e "\nAppuyez sur une touche pour revenir au menu..."
            read -n 1 -s
        fi
    done
}