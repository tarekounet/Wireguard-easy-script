#!/bin/bash
# Menu administrateur indépendant pour la gestion des utilisateurs Wireguard

# Sourcing des fonctions utilitaires pour l'affichage couleur
user_admin_menu() {
    while true; do
        clear
        echo -e "\e[1;36m=== Menu Administrateur Utilisateurs ===\e[0m"
        echo "1) Créer un utilisateur"
        echo "2) Sélectionner un utilisateur pour éditer ou supprimer"
        echo "3) Chercher et RAZ un dossier docker-wireguard"
        echo "4) Outils système (debian_tools)"
        echo "0) Quitter"
        read -p "Choix : " CHOIX
        case $CHOIX in
            1)
while true; do
        read -p "Entrez le nom du nouvel utilisateur : " NEWUSER
        if [[ -z "$NEWUSER" || ${#NEWUSER} -lt 2 ]]; then
            echo "Nom invalide. 2 caractères minimum."
            continue
        elif id "$NEWUSER" &>/dev/null; then
            echo "Ce nom existe déjà. Veuillez en choisir un autre."
            continue
        fi
        while true; do
            read -s -p "Entrez le mot de passe (8 caractères mini) : " NEWPASS
            echo
            read -s -p "Confirmez le mot de passe : " NEWPASS2
            echo
            if [[ ${#NEWPASS} -lt 8 ]]; then
                echo "Mot de passe trop court."
            elif [[ "$NEWPASS" != "$NEWPASS2" ]]; then
                echo "Les mots de passe ne correspondent pas."
            else
                break
            fi
        done
        useradd -m -s /bin/bash -G docker "$NEWUSER"
        echo "$NEWUSER:$NEWPASS" | chpasswd
        echo -e "\e[1;32mNouvel utilisateur '$NEWUSER' créé et ajouté au groupe docker.\e[0m"
        USER_HOME="/home/$NEWUSER/wireguard-script-manager"
        mkdir -p "$USER_HOME"
        chmod u+rwX "$USER_HOME"
        # Proposer le lancement auto à la connexion
        read -p "Souhaitez-vous lancer ce script automatiquement à la connexion de $NEWUSER ? (o/N) : " AUTOSTART
        if [[ "$AUTOSTART" =~ ^[oO]$ ]]; then
            PROFILE="/home/$NEWUSER/.bash_profile"
            SCRIPT_PATH="$USER_HOME/config_wg.sh"
            if ! grep -q "$SCRIPT_PATH" "$PROFILE" 2>/dev/null; then
                echo '[[ $- == *i* ]] && cd ~/wireguard-script-manager && bash ./config_wg.sh' >> "$PROFILE"
                chown "$NEWUSER:$NEWUSER" "$PROFILE"
                echo -e "\e[1;32mLe script sera lancé automatiquement à la connexion de $NEWUSER depuis $SCRIPT_PATH.\e[0m"
            fi
        fi
        break
done
                read -n1 -r -p "Appuie sur une touche pour continuer..." _
                ;;
            2)
                echo "Sélectionne un utilisateur :"
                mapfile -t USERS < <(awk -F: '($3>=1000)&&($1!="nobody"){print $1}' /etc/passwd)
                for i in "${!USERS[@]}"; do
                    printf "%d) %s\n" $((i+1)) "${USERS[$i]}"
                done
                read -p "Numéro de l'utilisateur : " IDX
                IDX=$((IDX-1))
                if [[ $IDX -ge 0 && $IDX -lt ${#USERS[@]} ]]; then
                    SELECTED_USER="${USERS[$IDX]}"
                    echo "1) Modifier le mot de passe de $SELECTED_USER"
                    echo "2) Supprimer $SELECTED_USER"
                    echo "0) Retour"
                    read -p "Choix : " SUBCHOIX
                    case $SUBCHOIX in
                        1)
                            passwd "$SELECTED_USER"
                            ;;
                        2)
                            deluser --remove-home "$SELECTED_USER"
                            ;;
                        0)
                            ;;
                        *)
                            echo "Choix invalide."
                            ;;
                    esac
                else
                    echo "Numéro invalide."
                fi
                read -n1 -r -p "Appuie sur une touche pour continuer..." _
                ;;
            3)
                echo "Recherche des dossiers docker-wireguard dans /home/* ..."
                mapfile -t WG_DIRS < <(find /home -maxdepth 2 -type d -name docker-wireguard 2>/dev/null)
                if [[ ${#WG_DIRS[@]} -eq 0 ]]; then
                    echo "Aucun dossier docker-wireguard trouvé."
                else
                    echo "Dossiers trouvés :"
                    for i in "${!WG_DIRS[@]}"; do
                        printf "%d) %s\n" $((i+1)) "${WG_DIRS[$i]}"
                    done
                    read -p "Numéro du dossier à RAZ (0 pour annuler) : " IDX
                    IDX=$((IDX-1))
                    if [[ $IDX -ge 0 && $IDX -lt ${#WG_DIRS[@]} ]]; then
                        TARGET_DIR="${WG_DIRS[$IDX]}"
                        # Vérifier si un service docker-compose est lancé dans ce dossier
                        if docker compose -f "$TARGET_DIR/docker-compose.yml" ps | grep -q 'Up'; then
                            echo "Un service Wireguard est actif dans ce dossier. Arrêt en cours..."
                            docker compose -f "$TARGET_DIR/docker-compose.yml" down
                        fi
                        read -p "Confirmer la suppression complète de $TARGET_DIR ? (o/N) : " CONFIRM
                        if [[ "$CONFIRM" =~ ^[oO]$ ]]; then
                            # RAZ : suppression du contenu du dossier config uniquement
                            CONF_DIR="$TARGET_DIR/config"
                            if [[ -d "$CONF_DIR" ]]; then
                                rm -rf "$CONF_DIR"/*
                                echo -e "\e[1;32mContenu du dossier $CONF_DIR supprimé.\e[0m"
                            else
                                echo "Dossier $CONF_DIR introuvable."
                            fi
                        else
                            echo "Suppression annulée."
                        fi
                    else
                        echo "Annulation."
                    fi
                fi
                read -n1 -r -p "Appuie sur une touche pour continuer..." _
                ;;
            4)
                debian_tools_menu() {
                    local options=(
                        "Infos système (CPU, RAM, uptime, IP, OS)"
                        "Infos disque (utilisation, partitions)"
                        "Statut Docker et containers"
                        "Mise à jour système (apt update/upgrade)"
                        "Changer le nom de la VM (hostname)"
                        "Changer le port SSH"
                        "Redémarrer la machine"
                        "Éteindre la machine"
                        "Lancer le moniteur système (htop)"
                        "Retour"
                    )
                    local actions=(
                        deb_sysinfo
                        deb_diskinfo
                        deb_dockerstatus
                        deb_update
                        deb_hostname
                        deb_sshport
                        deb_reboot
                        deb_shutdown
                        deb_htop
                        break
                    )
                    deb_sysinfo() {
                        echo -e "\n\e[1;33m--- Infos système ---\e[0m"
                        echo "Hostname : $(hostname)"
                        echo "Uptime   : $(uptime -p)"
                        echo "OS       : $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
                        echo "Kernel   : $(uname -r)"
                        echo "CPU      : $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
                        echo "RAM      : $(free -h | awk '/Mem:/ {print $2" total, "$3" used, "$4" free"}')"
                        echo "IP       : $(hostname -I | awk '{print $1}')"
                        echo "Utilisateurs connectés : $(who | wc -l)"
                    }
                    deb_diskinfo() {
                        echo -e "\n\e[1;33m--- Infos disque ---\e[0m"
                        df -hT
                        echo
                        lsblk
                    }
                    deb_dockerstatus() {
                        echo -e "\n\e[1;33m--- Statut Docker ---\e[0m"
                        if ! command -v docker &>/dev/null; then
                            echo "Docker n'est pas installé."
                        else
                            systemctl status docker --no-pager
                            echo
                            docker ps -a
                        fi
                    }
                    deb_update() {
                        echo -e "\n\e[1;33m--- Mise à jour système ---\e[0m"
                        read -p "Lancer 'apt update && apt upgrade -y' ? (o/N) : " CONFIRM
                        if [[ "$CONFIRM" =~ ^[oO]$ ]]; then
                            apt update && apt upgrade -y
                        else
                            echo "Annulé."
                        fi
                    }
                    deb_hostname() {
                        echo -e "\n\e[1;33m--- Changer le nom de la VM ---\e[0m"
                        read -p "Nouveau nom d'hôte : " NEW_HOST
                        if [[ -n "$NEW_HOST" ]]; then
                            hostnamectl set-hostname "$NEW_HOST"
                            echo "Nom d'hôte changé en $NEW_HOST."
                        else
                            echo "Nom non modifié."
                        fi
                    }
                    deb_sshport() {
                        echo -e "\n\e[1;33m--- Changer le port SSH ---\e[0m"
                        SSHD_CONFIG="/etc/ssh/sshd_config"
                        CUR_PORT=$(grep '^Port ' "$SSHD_CONFIG" | awk '{print $2}' | head -n1)
                        echo "Port SSH actuel : ${CUR_PORT:-22}"
                        read -p "Nouveau port SSH : " NEW_PORT
                        if [[ "$NEW_PORT" =~ ^[0-9]+$ && $NEW_PORT -ge 1 && $NEW_PORT -le 65535 ]]; then
                            sed -i "s/^#*Port .*/Port $NEW_PORT/" "$SSHD_CONFIG"
                            systemctl restart sshd
                            echo "Port SSH changé en $NEW_PORT."
                        else
                            echo "Port non modifié."
                        fi
                    }
                    deb_reboot() {
                        echo -e "\n\e[1;33m--- Redémarrage ---\e[0m"
                        read -p "Redémarrer la machine maintenant ? (o/N) : " CONFIRM
                        if [[ "$CONFIRM" =~ ^[oO]$ ]]; then
                            reboot
                        else
                            echo "Annulé."
                        fi
                    }
                    deb_shutdown() {
                        echo -e "\n\e[1;33m--- Arrêt ---\e[0m"
                        read -p "Éteindre la machine maintenant ? (o/N) : " CONFIRM
                        if [[ "$CONFIRM" =~ ^[oO]$ ]]; then
                            shutdown now
                        else
                            echo "Annulé."
                        fi
                    }
                    deb_htop() {
                        if command -v htop &>/dev/null; then
                            htop
                        else
                            echo "htop n'est pas installé. Installation..."
                            apt update && apt install -y htop && htop
                        fi
                    }
                    while true; do
                        clear
                        echo -e "\e[1;36m=== Outils système Debian ===\e[0m"
                        for i in "${!options[@]}"; do
                            printf "%d) %s\n" $((i+1)) "${options[$i]}"
                        done
                        read -p "Choix : " SYSCHOIX
                        if [[ "$SYSCHOIX" =~ ^[0-9]+$ && $SYSCHOIX -ge 1 && $SYSCHOIX -le ${#options[@]} ]]; then
                            action=${actions[$((SYSCHOIX-1))]}
                            if [[ "$action" == "break" ]]; then
                                break
                            else
                                $action
                            fi
                        else
                            echo "Choix invalide."
                        fi
                        read -n1 -r -p "Appuie sur une touche pour continuer..." _
                    done
                }
                debian_tools_menu
                ;;
            0)
                exit 0
                ;;
            *)
                echo "Choix invalide."
                read -n1 -r -p "Appuie sur une touche pour continuer..." _
                ;;
        esac
    done
}

if [[ $EUID -eq 0 ]]; then
    user_admin_menu
else
    echo -e "\e[1;31mCe menu doit être lancé en tant que root.\e[0m"
    exit 1
fi
