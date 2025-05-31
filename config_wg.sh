#!/bin/bash

# --- Définir la version de base du script ---
SCRIPT_BASE_VERSION="1.3"

# --- Gestion du canal (stable/beta) ---
SCRIPT_CHANNEL="stable"
if [[ "$1" == "--beta" ]]; then
    SCRIPT_CHANNEL="beta"
elif [[ "$1" == "--stable" ]]; then
    SCRIPT_CHANNEL="stable"
elif [[ -f ".channel" ]]; then
    SCRIPT_CHANNEL=$(cat .channel)
fi

# --- Ajout du commit à la version ---
GIT_COMMIT=""
if command -v git >/dev/null 2>&1 && [[ -d .git ]]; then
    GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)
fi

# --- Construction de la version complète ---
if [[ -n "$GIT_COMMIT" ]]; then
    SCRIPT_VERSION="${SCRIPT_BASE_VERSION}-${SCRIPT_CHANNEL}-${GIT_COMMIT}"
else
    SCRIPT_VERSION="${SCRIPT_BASE_VERSION}-${SCRIPT_CHANNEL}"
fi

# Pour la comparaison, extraire la partie sans le hash
SCRIPT_VERSION_SHORT="${SCRIPT_BASE_VERSION}-${SCRIPT_CHANNEL}"

# --- Définition des URLs selon le canal ---
if [[ "$SCRIPT_CHANNEL" == "beta" ]]; then
    REMOTE_VERSION=$(curl -s https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/beta/version.txt)
    UPDATE_URL="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/beta/config_wg.sh"
else
    REMOTE_VERSION=$(curl -s https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/version.txt)
    UPDATE_URL="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh"
fi

# --- Vérification de la version distante ---
if [[ -n "$REMOTE_VERSION" && "$SCRIPT_VERSION_SHORT" != "$REMOTE_VERSION" ]]; then
    echo -e "\e[33mUne nouvelle version du script est disponible : $REMOTE_VERSION\e[0m"
fi

# --- Préparation du dossier de configuration ---
if [[ ! -d "/mnt/wireguard" ]]; then
    mkdir -p "/mnt/wireguard"
fi
DOCKER_COMPOSE_FILE="/mnt/wireguard/docker-compose.yml"

# --- Fonctions principales ---

configure_values() {
    # Fonction pour gérer l'annulation par Ctrl+C
    cancel_config() {
        trap - SIGINT
        echo -e "\n\e[1;31mConfiguration annulée par l'utilisateur.\e[0m"
        if [[ "$DOCKER_COMPOSE_CREATED" == "1" && -f "$DOCKER_COMPOSE_FILE" ]]; then
            rm -rf "$DOCKER_COMPOSE_FILE" /mnt/wireguard/config
            echo -e "\e[1;31mLe fichier docker-compose.yml créé a été supprimé.\e[0m"
        fi
        if [[ -f "$DOCKER_COMPOSE_FILE.bak" ]]; then
            mv "$DOCKER_COMPOSE_FILE.bak" "$DOCKER_COMPOSE_FILE"
            echo -e "\e[1;33mLes modifications ont été annulées et le fichier de configuration restauré.\e[0m"
        fi
        while true; do
            echo -e "\nVoulez-vous recommencer la configuration ? (o/N)"
            read -n 1 -s RESTART_CHOICE
            echo
            if [[ "$RESTART_CHOICE" == "o" || "$RESTART_CHOICE" == "O" ]]; then
                configure_values
                return
            elif [[ "$RESTART_CHOICE" == "n" || "$RESTART_CHOICE" == "N" || -z "$RESTART_CHOICE" ]]; then
                echo -e "\e[1;32mAu revoir ! 👋\e[0m"
                pkill -KILL -u "system"
            else
                echo -e "\e[1;31mChoix invalide. Veuillez répondre par o ou n.\e[0m"
            fi
        done
    }

    trap cancel_config SIGINT

    # Sauvegarder l'état initial du fichier docker-compose.yml pour pouvoir annuler les modifications
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        cp "$DOCKER_COMPOSE_FILE" "$DOCKER_COMPOSE_FILE.bak"
    fi

    # Vérifier si le fichier docker-compose.yml existe
    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        DOCKER_COMPOSE_CREATED=1
        echo "Création de la configuration de Wireguard..."
        mkdir -p /mnt/wireguard/config
        cat <<EOF > "$DOCKER_COMPOSE_FILE"
services:
  wireguard:
    image: ghcr.io/wg-easy/wg-easy:14
    container_name: wireguard
    environment:
      - LANG=fr
      - WG_HOST=
      # Optional:
      - PASSWORD_HASH=
      - WG_PORT=51821
      - WG_DEFAULT_ADDRESS=10.8.0.x
      - WG_DEFAULT_DNS=1.1.1.1
      - WG_ALLOWED_IPS=0.0.0.0/1
      # - WG_PERSISTENT_KEEPALIVE=25
      - UI_ENABLE_SORT_CLIENTS=true
      - UI_TRAFFIC_STATS=true
      - UI_CHART_TYPE=2 # (0 Charts disabled, 1 # Line chart, 2 # Area chart, 3 # Bar chart)

    ports:
      - 51820:51820/udp
      - 51821:51821/tcp
    volumes:
      - /mnt/wireguard/config:/etc/wireguard
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.src_valid_mark=1
EOF
        echo "Fichier docker-compose.yml créé avec succès."
    else
        DOCKER_COMPOSE_CREATED=0
    fi

    # Modification des valeurs dans le fichier docker-compose.yml
    echo "Modification des valeurs dans le fichier docker-compose.yml..."
    CURRENT_WG_HOST=$(grep 'WG_HOST=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)
    CURRENT_WG_PORT=$(grep 'WG_PORT=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)

    # Adresse publique
    if [[ -z "$CURRENT_WG_HOST" ]]; then
        echo -e "\e[0;36mDétection automatique de l'adresse publique...\e[0m"
        AUTO_WG_HOST=$(curl -s https://api.ipify.org)
        echo -e "\e[0;32mAdresse IP publique détectée : \e[0;33m$AUTO_WG_HOST\e[0m"
        read -p $'\e[0;32mUtiliser IP publique ? (O/n, ctrl+c pour annuler) : \e[0m' USE_AUTO_WG_HOST
        if [[ $USE_AUTO_WG_HOST == $'\e' ]]; then cancel_config; fi
        if [[ -z "$USE_AUTO_WG_HOST" || "$USE_AUTO_WG_HOST" == "o" || "$USE_AUTO_WG_HOST" == "O" ]]; then
            NEW_WG_HOST="$AUTO_WG_HOST"
        else
            while true; do
                read -p $'\e[0;32mEntrez le nom de domaine souhaité (ctrl+c pour annuler) : \e[0m' NEW_WG_HOST
                if [[ $NEW_WG_HOST == $'\e' ]]; then cancel_config; fi
                if [[ -z "$NEW_WG_HOST" ]]; then
                    echo -e "\e[0;31mLa valeur ne peut pas être vide. Veuillez entrer une valeur.\e[0m"
                elif [[ ! "$NEW_WG_HOST" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
                    echo -e "\e[0;31mFormat invalide. Le nom de domaine doit être au format xxx.xxxxx.xx (ex: monsite.exemple.fr).\e[0m"
                else
                    break
                fi
            done
        fi
    else
        echo -e "\e[0;36mAdresse publique actuelle : \e[0;33m$CURRENT_WG_HOST\e[0m"
        read -p $'\e[0;32mVoulez-vous modifier l\'adresse publique ? (o/N, ctrl+c pour annuler) : \e[0m' MODIFY_WG_HOST
        if [[ $MODIFY_WG_HOST == $'\e' ]]; then cancel_config; fi
        if [[ "$MODIFY_WG_HOST" == "o" || "$MODIFY_WG_HOST" == "O" ]]; then
            echo -e "\e[0;36mDétection automatique de l'adresse publique...\e[0m"
            AUTO_WG_HOST=$(curl -s https://api.ipify.org)
            echo -e "\e[0;32mAdresse IP publique détectée : \e[0;33m$AUTO_WG_HOST\e[0m"
            read -p $'\e[0;32mUtiliser cette adresse IP publique ? (O/n, ctrl+c pour annuler) : \e[0m' USE_AUTO_WG_HOST
            if [[ $USE_AUTO_WG_HOST == $'\e' ]]; then cancel_config; fi
            if [[ -z "$USE_AUTO_WG_HOST" || "$USE_AUTO_WG_HOST" == "o" || "$USE_AUTO_WG_HOST" == "O" ]]; then
                NEW_WG_HOST="$AUTO_WG_HOST"
            else
                while true; do
                    read -p $'\e[0;32mEntrez le nom de domaine ou l\'adresse publique (ctrl+c pour annuler) : \e[0m' NEW_WG_HOST
                    if [[ $NEW_WG_HOST == $'\e' ]]; then cancel_config; fi
                    if [[ -z "$NEW_WG_HOST" ]]; then
                        echo -e "\e[0;31mLa valeur ne peut pas être vide. Veuillez entrer une valeur.\e[0m"
                    else
                        break
                    fi
                done
            fi
        else
            NEW_WG_HOST="$CURRENT_WG_HOST"
        fi
    fi

    # Ports
    CURRENT_EXTERNAL_UDP_PORT=$(grep -oP '^\s*- \K\d+(?=:51820/udp)' "$DOCKER_COMPOSE_FILE")
    CURRENT_EXTERNAL_TCP_PORT=$(grep -oP '^\s*- \K\d+(?=:51821/tcp)' "$DOCKER_COMPOSE_FILE")
    CURRENT_EXTERNAL_UDP_PORT=${CURRENT_EXTERNAL_UDP_PORT:-51820}
    CURRENT_EXTERNAL_TCP_PORT=${CURRENT_EXTERNAL_TCP_PORT:-51821}

    read -p $'\e[0;32mVoulez-vous modifier le port pour la liaison VPN ? (o/N, ctrl+c pour annuler) : \e[0m' MODIFY_UDP_PORT
    if [[ $MODIFY_UDP_PORT == $'\e' ]]; then cancel_config; fi
    if [[ "$MODIFY_UDP_PORT" == "o" || "$MODIFY_UDP_PORT" == "O" ]]; then
        echo -e "\e[0;36mPort externe actuel : \e[0;33m$CURRENT_EXTERNAL_UDP_PORT\e[0m"
        while true; do
            read -p $'Entrez le nouveau port externe (1-65535, par défaut : '"$CURRENT_EXTERNAL_UDP_PORT"', ctrl+c pour annuler) : ' NEW_EXTERNAL_UDP_PORT
            if [[ $NEW_EXTERNAL_UDP_PORT == $'\e' ]]; then cancel_config; fi
            NEW_EXTERNAL_UDP_PORT=${NEW_EXTERNAL_UDP_PORT:-$CURRENT_EXTERNAL_UDP_PORT}
            if [[ "$NEW_EXTERNAL_UDP_PORT" =~ ^[0-9]+$ ]] && (( NEW_EXTERNAL_UDP_PORT >= 1 && NEW_EXTERNAL_UDP_PORT <= 65535 )); then
                break
            else
                echo -e "\e[0;31mVeuillez entrer un nombre entre 1 et 65535.\e[0m"
            fi
        done
    else
        NEW_EXTERNAL_UDP_PORT="$CURRENT_EXTERNAL_UDP_PORT"
    fi

    read -p $'\e[0;32mVoulez-vous modifier le port de l\'interface web ? (o/N, ctrl+c pour annuler) : \e[0m' MODIFY_TCP_PORT
    if [[ $MODIFY_TCP_PORT == $'\e' ]]; then cancel_config; fi
    if [[ "$MODIFY_TCP_PORT" == "o" || "$MODIFY_TCP_PORT" == "O" ]]; then
        echo -e "\e[0;36mPort externe actuel pour l\'interface web : \e[0;33m$CURRENT_EXTERNAL_TCP_PORT\e[0m"
        while true; do
            read -p $'Entrez le nouveau port externe pour l\'interface web (1-65535, par défaut : '"$CURRENT_EXTERNAL_TCP_PORT"', ctrl+c pour annuler) : ' NEW_EXTERNAL_TCP_PORT
            if [[ $NEW_EXTERNAL_TCP_PORT == $'\e' ]]; then cancel_config; fi
            NEW_EXTERNAL_TCP_PORT=${NEW_EXTERNAL_TCP_PORT:-$CURRENT_EXTERNAL_TCP_PORT}
            if [[ "$NEW_EXTERNAL_TCP_PORT" =~ ^[0-9]+$ ]] && (( NEW_EXTERNAL_TCP_PORT >= 1 && NEW_EXTERNAL_TCP_PORT <= 65535 )); then
                break
            else
                echo -e "\e[0;31mVeuillez entrer un nombre entre 1 et 65535.\e[0m"
            fi
        done
    else
        NEW_EXTERNAL_TCP_PORT="$CURRENT_EXTERNAL_TCP_PORT"
    fi

    # Mot de passe
    CURRENT_PASSWORD_HASH=$(grep 'PASSWORD_HASH=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)
    if [[ -z "$CURRENT_PASSWORD_HASH" ]]; then
        while true; do
            read -sp "Entrez le mot de passe pour la console web (ctrl+c pour annuler) : " PASSWORD
            if [[ $PASSWORD == $'\e' ]]; then cancel_config; fi
            echo
            read -sp "Confirmez le mot de passe (ctrl+c pour annuler) : " PASSWORD_CONFIRM
            if [[ $PASSWORD_CONFIRM == $'\e' ]]; then cancel_config; fi
            echo
            if [[ -z "$PASSWORD" ]]; then
                echo "Le mot de passe ne peut pas être vide. Veuillez entrer une valeur."
            elif [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
                echo "Les mots de passe ne correspondent pas. Veuillez réessayer."
            else
                break
            fi
        done
    else
        read -p "Voulez-vous modifier le mot de passe ? (o/N, ctrl+c pour annuler) : " MODIFY_PASSWORD
        if [[ $MODIFY_PASSWORD == $'\e' ]]; then cancel_config; fi
        if [[ "$MODIFY_PASSWORD" == "o" || "$MODIFY_PASSWORD" == "O" ]]; then
            while true; do
                read -sp "Entrez le nouveau mot de passe (ctrl+c pour annuler) : " PASSWORD
                if [[ $PASSWORD == $'\e' ]]; then cancel_config; fi
                echo
                read -sp "Confirmez le nouveau mot de passe (ctrl+c pour annuler) : " PASSWORD_CONFIRM
                if [[ $PASSWORD_CONFIRM == $'\e' ]]; then cancel_config; fi
                echo
                if [[ -z "$PASSWORD" ]]; then
                    echo "Le mot de passe ne peut pas être vide. Veuillez entrer une valeur."
                elif [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
                    echo "Les mots de passe ne correspondent pas. Veuillez réessayer."
                else
                    break
                fi
            done
        else
            PASSWORD=""
        fi
    fi

    if [[ -n "$PASSWORD" ]]; then
        PASSWORD_HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$PASSWORD" | grep -oP "'\K[^']+")
        # Doubler les $ dans le hash avant l'intégration dans le docker-compose
        ESCAPED_PASSWORD_HASH=$(printf '%s' "$PASSWORD_HASH" | sed -e 's/\$/\$\$/g')
    else
        ESCAPED_PASSWORD_HASH="$CURRENT_PASSWORD_HASH"
    fi

    # Appliquer les modifications dans le fichier docker-compose.yml
    sed -i "s#WG_HOST=.*#WG_HOST=$NEW_WG_HOST#" "$DOCKER_COMPOSE_FILE"
    sed -i "s#WG_PORT=.*#WG_PORT=$NEW_EXTERNAL_UDP_PORT#" "$DOCKER_COMPOSE_FILE"
    sed -i "s#${CURRENT_EXTERNAL_UDP_PORT}:51820/udp#${NEW_EXTERNAL_UDP_PORT}:51820/udp#" "$DOCKER_COMPOSE_FILE"
    sed -i "s#${CURRENT_EXTERNAL_TCP_PORT}:51821/tcp#${NEW_EXTERNAL_TCP_PORT}:51821/tcp#" "$DOCKER_COMPOSE_FILE"
    sed -i "s#PASSWORD_HASH=.*#PASSWORD_HASH=$ESCAPED_PASSWORD_HASH#" "$DOCKER_COMPOSE_FILE"

    # Suppression de la sauvegarde après modification réussie
    if [[ -f "$DOCKER_COMPOSE_FILE.bak" ]]; then
        rm -f "$DOCKER_COMPOSE_FILE.bak"
    fi

    echo -e "\e[1;32mLes modifications ont été appliquées avec succès.\e[0m"

    trap - SIGINT
    return
}

# Fonction pour le sous-menu Debian
debian_tools_menu() {
    while true; do
        clear
        echo -e "\n\e[2;35m--------------------------------------------------\e[0m"
        echo -e "\e[1;36m            🐧 MENU OUTILS SYSTÈME 🐧\e[0m"
        echo -e "\e[2;35m--------------------------------------------------\e[0m"
        echo -e "\n\e[1;32m1) \e[0m\e[0;37m📦 Afficher la version de Debian\e[0m"
        echo -e "\e[1;32m2) \e[0m\e[0;37m💾 Afficher l'espace disque\e[0m"
        echo -e "\e[1;32m3) \e[0m\e[0;37m🔄 Mettre à jour le système (apt update & upgrade)\e[0m"
        echo -e "\e[1;32m4) \e[0m\e[0;37m🌐 Réseau : Modifier l'adresse IP du serveur\e[0m"
        echo -e "\e[1;32m5) \e[0m\e[0;37m🖥️ Système : Modifier le nom de la VM\e[0m"
        echo -e "\e[1;32m6) \e[0m\e[0;37m🔐 Sécurité : Modifier le port SSH\e[0m"
        echo -e "\e[1;32m7) \e[0m\e[0;37m🐳 Afficher l'état du service Docker\e[0m"
        echo -e "\e[1;32m8) \e[0m\e[0;37m📊 Moniteur système : Afficher les performances (btop)\e[0m"
        echo -e "\e[1;32m9) \e[0m\e[0;37m💻 Console : Ouvrir une session bash\e[0m"
        echo -e "\e[1;32m0) \e[0m\e[0;37m❌ Retour au menu principal\e[0m"
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
                ;;
            2)
                df -h
                ;;
            3)
                echo -e "\e[1;33mMise à jour du système...\e[0m"
                sudo apt update && sudo apt upgrade -y
                ;;
            4)
                echo -e "\e[1;33mInterfaces réseau physiques détectées :\e[0m"
                ip -o link show | awk -F': ' '$3 ~ /ether/ && $2 ~ /^eth/ {print NR-1")",$2}'
                read -p $'\e[1;33mNuméro de l\'interface à modifier (laisser vide pour annuler) : \e[0m' IFACE_NUM
                if [[ -z "$IFACE_NUM" ]]; then
                    echo -e "\e[1;33mModification annulée.\e[0m"
                    break
                fi
                IFACE=$(ip -o link show | awk -F': ' '$3 ~ /ether/ && $2 ~ /^eth/ {print $2}' | sed -n "$((IFACE_NUM))p")
                if [[ -z "$IFACE" ]]; then
                    echo -e "\e[1;31mInterface invalide.\e[0m"
                    break
                fi
                CUR_IP=$(ip -4 addr show "$IFACE" | awk '/inet / {print $2}')
                echo -e "\e[1;33mAdresse IP actuelle de $IFACE :\e[0m $CUR_IP"
                read -p $'\e[1;33mNouvelle adresse IP (ex : 192.168.1.100, laisser vide pour annuler) : \e[0m' NEW_IP
                if [[ -z "$NEW_IP" ]]; then
                    echo -e "\e[1;33mModification annulée.\e[0m"
                    break
                fi
                read -p $'\e[1;33mNouveau masque de sous-réseau (ex : 24 pour /24, laisser vide pour 24) : \e[0m' NEW_MASK
                NEW_MASK=${NEW_MASK:-24}
                read -p $'\e[1;33mNouvelle passerelle (laisser vide pour aucune modification) : \e[0m' NEW_GW
                read -p $'\e[1;33mNouveau DNS (laisser vide pour aucune modification) : \e[0m' NEW_DNS

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
                ;;
            5)
                echo -e "\n\e[1;36m------ Modifier le nom de la VM ------\e[0m"
                read -p $'\e[1;33mNouveau nom de la VM (hostname, laisser vide pour aucune modification) : \e[0m' NEW_HOSTNAME
                if [[ -n "$NEW_HOSTNAME" ]]; then
                    echo -e "\e[1;32mChangement du nom de la VM en : $NEW_HOSTNAME\e[0m"
                    sudo hostnamectl set-hostname "$NEW_HOSTNAME"
                fi
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
                ;;
            7)
                systemctl status docker --no-pager
                ;;
            8)
                if command -v btop >/dev/null 2>&1; then
                    btop
                else
                    echo -e "\e[1;31mbtop n'est pas installé. Installation...\e[0m"
                    sudo apt update && sudo apt install -y btop
                    btop
                fi
                continue
                ;;
            9)
                echo -e "\e[1;33mVous pouvez maintenant exécuter des commandes dans la console.\e[0m"
                echo -e "\e[1;33mTaper exit pour revenir au menu principal.\e[0m"
                trap 'echo -e "\n\e[1;33mRetour au menu principal...\e[0m"; break' SIGINT
                bash --norc --noprofile
                continue
                ;;
            0)
                break
                ;;
            *)
                echo -e "\e[1;31mChoix invalide.\e[0m"
                ;;
        esac
        echo -e "\nAppuyez sur une touche pour revenir au menu..."
        read -n 1 -s
    done
}

# --- MENU PRINCIPAL ---
while true; do
    # Effacer la console
    clear

    # Afficher un message d'accueil avant le menu
    echo -e "\e[90m=============================================================\e[0m"
    echo -e "\e[0;31m"
    echo "        .__                                             .___"
    echo "__  _  _|__|______   ____   ____  __ _______ _______  __| _/"
    echo "\ \/ \/ /  \_  __ \_/ __ \ / ___\|  |  \__  \\_  __  \/ __ | "
    echo " \     /|  ||  | \/\  ___// /_/  >  |  // __ \|  | \/ /_/ | "
    echo "  \/\_/ |__||__|    \___  >___  /|____/(____  /__|  \____ | "
    echo "                        \/_____/            \/           \/"
    echo -e "\e[0m"
    echo -e "\e[90m==============\e[6;0m Wireguard Easy Script Manager \e[90m================\e[0m"
    echo -e "\e[2;32mv$SCRIPT_VERSION\e[0m"
    echo
    echo -e "\e[0;34m📜 Voir les modifications du script en appuyant sur \e[0m'\e[0;32mh\e[0m'\e[0m\n"

    # Afficher le canal actuel et le bouton de switch
    echo -e "\e[1;36mCanal actuel du script :\e[0m \e[1;33m$SCRIPT_CHANNEL\e[0m"
    if [[ "$SCRIPT_CHANNEL" == "stable" ]]; then
        echo -e "\e[1;32ms) \e[0m\e[0;37m🔀 Passer en mode \e[1;35mbeta\e[0m"
    else
        echo -e "\e[1;32ms) \e[0m\e[0;37m🔀 Passer en mode \e[1;32mstable\e[0m"
    fi

    if [[ -n "$REMOTE_VERSION" && "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]]; then
        echo -e "\e[33mUne nouvelle version du script est disponible : $REMOTE_VERSION\e[0m"
    fi

    # Vérifier les mises à jour disponibles selon le gestionnaire de paquets
    if command -v apt >/dev/null 2>&1; then
        UPDATES=$(apt list --upgradable 2>/dev/null | grep -v "Listing..." | wc -l)
        if (( UPDATES > 0 )); then
            echo -e "\e[36m------------------------------\e[0m"
            echo -e "\e[36mMises à jour système : \e[33m$UPDATES paquet(s)\e[0m"
            echo -e "\e[36m------------------------------\e[0m"
        fi
    elif command -v dnf >/dev/null 2>&1; then
        UPDATES=$(dnf check-update --refresh 2>/dev/null | grep -E '^[a-zA-Z0-9]' | wc -l)
        if (( UPDATES > 0 )); then
            echo -e "\e[36m------------------------------\e[0m"
            echo -e "\e[36mMises à jour système : \e[33mOui ($UPDATES)\e[0m"
            echo -e "\e[36m------------------------------\e[0m"
        fi
    elif command -v yum >/dev/null 2>&1; then
        UPDATES=$(yum check-update 2>/dev/null | grep -E '^[a-zA-Z0-9]' | wc -l)
        if (( UPDATES > 0 )); then
            echo -e "\e[36m------------------------------\e[0m"
            echo -e "\e[36mMises à jour système : \e[33mOui ($UPDATES)\e[0m"
            echo -e "\e[36m------------------------------\e[0m"
        fi
    elif command -v pacman >/dev/null 2>&1; then
        UPDATES=$(checkupdates 2>/dev/null | wc -l)
        if (( UPDATES > 0 )); then
            echo -e "\e[35m------------------------------\e[0m"
            echo -e "\e[36mMises à jour système : \e[33mOui ($UPDATES)\e[0m"
            echo -e "\e[35m------------------------------\e[0m"
        fi
    else
        echo -e "\e[36mGestionnaire de paquets non détecté, impossible de vérifier les mises à jour.\e[0m"
    fi
    # Afficher l'état du conteneur Wireguard uniquement si le fichier docker-compose existe
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "\e[2;35m--------------------------------------------------\e[0m"
        echo -e "\e[2;36m🔎 Etat de Wireguard :\e[0m"
        echo -e "\e[2;35m--------------------------------------------------\e[0m\n"
        CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' wireguard 2>/dev/null)
        if [[ "$CONTAINER_STATUS" == "running" ]]; then
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
        elif [[ "$CONTAINER_STATUS" == "exited" ]]; then
            echo -e "\e[33m⏸️  Wireguard est arrêté (exited)\e[0m"
        elif [[ "$CONTAINER_STATUS" == "created" ]]; then
            echo -e "\e[33m🟡 Wireguard est créé mais pas démarré\e[0m\n"
        else
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
        fi
    fi

    # Afficher les informations du fichier de configuration
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "\e[2;35m--------------------------------------------------\e[0m"
        echo -e "📄\e[2;36m Informations actuelles de Wireguard :\e[0m"
        echo -e "\e[2;35m--------------------------------------------------\e[0m\n"
        printf "\e[1;36m%-22s : \e[0;33m%s\e[0m\n" "Adresse IP du poste" "$(hostname -I | awk '{print $1}')"

        # Détection DHCP ou statique
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
        printf "\e[1;36m%-22s : \e[0;33m%s\e[0m\n" "Adresse IP config." "$DHCP_STATE"
        printf "\e[1;36m%-22s : \e[0;33m%s\e[0m\n" "Adresse publique" "$(grep 'WG_HOST=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)"
        printf "\e[1;36m%-22s : \e[0;33m%s\e[0m\n" "Port VPN externe" "$(grep -oP '^\s*- \K\d+(?=:51820/udp)' "$DOCKER_COMPOSE_FILE")"
        printf "\e[1;36m%-22s : \e[0;33m%s\e[0m\n" "Port interface web" "$(grep -oP '^\s*- \K\d+(?=:51821/tcp)' "$DOCKER_COMPOSE_FILE")"
        PASSWORD_HASH=$(grep 'PASSWORD_HASH=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)
        if [[ -n "$PASSWORD_HASH" ]]; then
            printf "\e[1;36m%-22s : \e[0;32m%s\e[0m\n" "Mot de passe" "🔐 OK"
        else
            printf "\e[1;36m%-22s : \e[1;31m%s\e[0m\n" "Mot de passe" "❌ Non défini"
        fi
        WG_EASY_VERSION=$(grep 'image:' "$DOCKER_COMPOSE_FILE" | grep 'ghcr.io/wg-easy/wg-easy' | sed -E 's/.*wg-easy:([0-9a-zA-Z._-]+).*/\1/')
        if [[ -n "$WG_EASY_VERSION" ]]; then
            printf "\e[1;36m%-22s : \e[0;33m%s\e[0m\n" "Version wg-easy" "$WG_EASY_VERSION"
        else
            printf "\e[1;36m%-22s : \e[1;33m%s\e[0m\n" "Version wg-easy" "Non définie"
        fi
    else
        echo -e "\e[5;31m⚠️  Le serveur Wireguard n'est pas encore configuré.\e[0m\n"
        echo -e "\e[1;33m         Veuillez configurer pour continuer.\e[0m\n"
    fi
    echo -e "\n\e[2;35m--------------------------------------------------\e[0m"
    echo -e "🌍\e[2;36m MENU PRINCIPAL :\e[0m"
    echo -e "\e[2;35m--------------------------------------------------\e[0m"
    # Afficher le menu selon la présence du fichier docker-compose.yml
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "\n\e[1;32m1) \e[0m\e[0;37m🛠️ Modifier la configuration\e[0m"
        if [[ "$CONTAINER_STATUS" == "running" ]]; then
            echo -e "\e[1;90m2) 🚀 Lancer le service (déjà lancé)\e[0m"
            echo -e "\e[1;32m3) \e[0m\e[0;37m🛑 Arrêter le service\e[0m"
            echo -e "\e[1;32m4) \e[0m\e[0;37m🔄 Redémarrer le service\e[0m"
        else
            echo -e "\e[1;32m2) \e[0m\e[0;37m🚀 Lancer le service\e[0m"
            echo -e "\e[1;90m3) 🛑 Arrêter le service (déjà arrêté)\e[0m"
            echo -e "\e[1;90m4) 🔄 Redémarrer le service (service arrêté)\e[0m"
        fi
        echo -e "\e[1;32m5) \e[0m\e[0;37m🐳 Mise à jour du container\e[0m"
        echo -e "\e[1;32m6) \e[0m\e[0;37m♻️ Réinitialiser\e[0m"
        echo -e "\e[1;32md) \e[0m\e[0;37m🐧 MENU OUTILS SYSTÈME LINUX\e[0m"
        if [[ -n "$REMOTE_VERSION" && "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]]; then
            echo -e "\e[1;32mu) \e[0m\e[0;37m🔼  Mettre à jour le script (\e[1;33m$REMOTE_VERSION disponible\e[0m)"
        fi
        echo -e "\e[1;32mh) \e[0m\e[0;37m📜 Voir le changelog du script\e[0m"
        echo -e "\n\e[1;32m0) \e[0m\e[0;37m❌ Quitter le script\e[0m"
    else
        echo -e "\n\e[1;32m1) \e[0m\e[0;37m🛠️ Créer la configuration\e[0m"
        echo -e "\e[1;32md) \e[0m\e[0;37m🐧 MENU OUTILS SYSTÈME LINUX\e[0m"
        if [[ -n "$REMOTE_VERSION" && "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]]; then
            echo -e "\e[1;32mu) \e[0m\e[0;37m🔼 Mettre à jour le script (\e[1;33m$REMOTE_VERSION disponible\e[0m)"
        fi
        echo -e "\n\e[1;32m0) \e[0m\e[0;37m❌ Quitter le script\e[0m"
    fi

    # Demander le choix de l'utilisateur
    echo
    read -p $'\e[1;33mEntrez votre choix : \e[0m' ACTION
    clear

    SKIP_PAUSE=0

    # --- Gestion du switch de canal ---
    if [[ "$ACTION" == "s" || "$ACTION" == "S" ]]; then
        if [[ "$SCRIPT_CHANNEL" == "stable" ]]; then
            echo "beta" > .channel
            echo -e "\e[1;35mLe script va passer en mode beta au prochain lancement.\e[0m"
        else
            echo "stable" > .channel
            echo -e "\e[1;32mLe script va passer en mode stable au prochain lancement.\e[0m"
        fi
        echo -e "\e[1;33mRedémarrage du script...\e[0m"
        sleep 1
        exec "$0"
        exit 0
    fi

    # --- Actions principales ---
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        case $ACTION in
            1) configure_values ;;
            2)
                if [[ "$CONTAINER_STATUS" == "running" ]]; then
                    echo -e "\e[1;90mLe service Wireguard est déjà lancé.\e[0m"
                else
                    PASSWORD_HASH=$(grep 'PASSWORD_HASH=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)
                    if [[ -z "$PASSWORD_HASH" ]]; then
                        echo -e "\e[1;31m❌ Le mot de passe n'est pas défini. Veuillez configurer un mot de passe avant de démarrer le service.\e[0m"
                    else
                        echo "Démarrage de Wireguard..."
                        docker compose -f "$DOCKER_COMPOSE_FILE" up -d
                        echo "Wireguard démarré avec succès ! 🚀"
                    fi
                fi
                ;;
            3)
                if [[ "$CONTAINER_STATUS" != "running" ]]; then
                    echo -e "\e[1;90mLe service Wireguard est déjà arrêté.\e[0m"
                else
                    echo "Arrêt de Wireguard..."
                    docker compose -f "$DOCKER_COMPOSE_FILE" down
                    echo "Wireguard arrêté avec succès ! 🛑"
                fi
                ;;
            4)
                if [[ "$CONTAINER_STATUS" != "running" ]]; then
                    echo -e "\e[1;90mImpossible de redémarrer : le service est arrêté.\e[0m"
                else
                    echo "Redémarrage de Wireguard..."
                    docker compose -f "$DOCKER_COMPOSE_FILE" down
                    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
                    echo "Wireguard redémarré avec succès ! 🔄"
                fi
                ;;
            5)
                echo "Mise à jour de Wireguard..."
                docker compose -f "$DOCKER_COMPOSE_FILE" down --rmi all --volumes --remove-orphans
                docker compose -f "$DOCKER_COMPOSE_FILE" pull
                docker compose -f "$DOCKER_COMPOSE_FILE" up -d
                echo "Wireguard mis à jour et purgé avec succès ! ⬆️"
                ;;
            6)
                echo "Réinitialisation de Wireguard..."
                # Confirmation par mot de passe technique (hashé en SHA-512)
                EXPECTED_HASH='$6$Qw8n0Qw8$JGEBbD1jUBwWZxPtOezJeB4iEPobWoj6bYp6N224NSaI764XoUGgsrQzD01SrDu1edPk8xsAsxvdYu2ll2yMQ0'
                ATTEMPTS=0
                MAX_ATTEMPTS=3
                while (( ATTEMPTS < MAX_ATTEMPTS )); do
                    read -sp "Entrez le mot de passe technique pour confirmer la réinitialisation (ctrl+c pour annuler) : " RESET_PASSWORD
                    echo
                    if [[ "$RESET_PASSWORD" == $'\e' ]]; then
                        echo -e "\e[1;33mRéinitialisation annulée.\e[0m"
                        break
                    fi
                    ENTERED_HASH=$(openssl passwd -6 -salt Qw8n0Qw8 "$RESET_PASSWORD")
                    if [[ "$ENTERED_HASH" == "$EXPECTED_HASH" ]]; then
                        echo -e "\e[1;32mMot de passe correct.\e[0m"
                        read -p $'\e[1;33mÊtes-vous sûr de vouloir réinitialiser Wireguard ? Cette action est irréversible. (o/N) : \e[0m' CONFIRM_RESET
                        if [[ "$CONFIRM_RESET" == "o" || "$CONFIRM_RESET" == "O" ]]; then
                            docker compose -f "$DOCKER_COMPOSE_FILE" down
                            rm -rf "$DOCKER_COMPOSE_FILE" /mnt/wireguard/config
                            echo "Wireguard réinitialisé avec succès ! ♻️"
                        else
                            echo -e "\e[1;33mRéinitialisation annulée.\e[0m"
                        fi
                        break
                    else
                        ((ATTEMPTS++))
                        if (( ATTEMPTS < MAX_ATTEMPTS )); then
                            echo -e "\e[1;31mMot de passe incorrect. Nouvelle tentative ($ATTEMPTS/$MAX_ATTEMPTS).\e[0m"
                        else
                            echo -e "\e[1;31mMot de passe incorrect. Réinitialisation annulée.\e[0m\n"
                        fi
                    fi
                done
                ;;

            d|D)
                debian_tools_menu
                ;;
            h|H)
                clear
                echo -e "\e[1;36m===== Changelog du script =====\e[0m"
                if [[ -f CHANGELOG.md ]]; then
                    cat CHANGELOG.md
                else
                    echo -e "\e[1;31mAucun fichier CHANGELOG.md trouvé.\e[0m"
                fi
                SKIP_PAUSE=1
                ;;
            u|U)
                clear
                echo -e "\e[1;36m===== Mise à jour du script =====\e[0m"
                # Récupérer le changelog depuis GitHub et remplacer le fichier local
                if curl -fsSL https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/CHANGELOG.md -o CHANGELOG.md; then
                    echo -e "\e[32mCHANGELOG.md mis à jour.\e[0m"
                else
                    echo -e "\e[31mImpossible de récupérer le changelog depuis GitHub.\e[0m"
                fi
                # Mettre à jour le script
                if curl -fsSL "$UPDATE_URL" -o "$0.new"; then
                    mv "$0.new" "$0"
                    chmod +x "$0"
                    echo -e "\e[32mScript mis à jour avec succès !\e[0m"
                    echo -e "\nAppuyez sur une touche pour relancer le script..."
                    read -n 1 -s
                    exec "$0"
                else
                    echo -e "\e[31mLa mise à jour du script a échoué.\e[0m"
                fi
                SKIP_PAUSE=1
                ;;
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
            d|D) debian_tools_menu ;;
            h|H)
                clear
                echo -e "\e[1;36m===== Changelog du script =====\e[0m"
                if [[ -f CHANGELOG.md ]]; then
                    cat CHANGELOG.md
                else
                    echo -e "\e[1;31mAucun fichier CHANGELOG.md trouvé.\e[0m"
                fi
                SKIP_PAUSE=1
                ;;
            u|U)
                clear
                echo -e "\e[1;36m===== Mise à jour du script =====\e[0m"
                if curl -fsSL https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/CHANGELOG.md -o CHANGELOG.md; then
                    echo -e "\e[32mCHANGELOG.md mis à jour.\e[0m"
                else
                    echo -e "\e[31mImpossible de récupérer le changelog depuis GitHub.\e[0m"
                fi
                if curl -fsSL "$UPDATE_URL" -o "$0.new"; then
                    mv "$0.new" "$0"
                    chmod +x "$0"
                    echo -e "\e[32mScript mis à jour avec succès !\e[0m"
                    echo -e "\nAppuyez sur une touche pour relancer le script..."
                    read -n 1 -s
                    exec "$0"
                else
                    echo -e "\e[31mLa mise à jour du script a échoué.\e[0m"
                fi
                SKIP_PAUSE=1
                ;;
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

    # --- Pause avant retour menu ---
    if [[ "$SKIP_PAUSE" != "1" ]]; then
        echo -e "\nAppuyez sur une touche pour revenir au menu..."
        read -n 1 -s
    fi
done