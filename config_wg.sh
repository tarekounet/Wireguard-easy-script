#!/bin/bash

SCRIPT_VERSION="1.0.4_beta"
REMOTE_VERSION=$(curl -s https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/beta/version.txt)
UPDATE_URL="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/beta/config_wg.sh"

# Définir le chemin absolu du fichier docker-compose
# Créer le dossier /mnt/wireguard s'il n'existe pas
if [[ ! -d "/mnt/wireguard" ]]; then
    mkdir -p "/mnt/wireguard"
fi
DOCKER_COMPOSE_FILE="/mnt/wireguard/docker-compose.yml"

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
        PASSWORD_HASH=$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$PASSWORD" | grep -oP "'\K[^']+" | sed 's/\$/\$\$/g')
        ESCAPED_PASSWORD_HASH=$(echo "$PASSWORD_HASH" | sed 's/[\/&]/\\&/g')
    else
        ESCAPED_PASSWORD_HASH="$CURRENT_PASSWORD_HASH"
    fi

    # Appliquer les modifications dans le fichier docker-compose.yml
    sed -i "s/WG_HOST=.*/WG_HOST=$NEW_WG_HOST/" "$DOCKER_COMPOSE_FILE"
    sed -i "s/WG_PORT=.*/WG_PORT=$NEW_EXTERNAL_UDP_PORT/" "$DOCKER_COMPOSE_FILE"
    sed -i "s/$CURRENT_EXTERNAL_UDP_PORT:51820\/udp/$NEW_EXTERNAL_UDP_PORT:51820\/udp/" "$DOCKER_COMPOSE_FILE"
    sed -i "s/$CURRENT_EXTERNAL_TCP_PORT:51821\/tcp/$NEW_EXTERNAL_TCP_PORT:51821\/tcp/" "$DOCKER_COMPOSE_FILE"
    sed -i "s/PASSWORD_HASH=.*/PASSWORD_HASH=$ESCAPED_PASSWORD_HASH/" "$DOCKER_COMPOSE_FILE"

    # Suppression de la sauvegarde après modification réussie
    if [[ -f "$DOCKER_COMPOSE_FILE.bak" ]]; then
        rm -f "$DOCKER_COMPOSE_FILE.bak"
    fi

    echo -e "\e[1;32mLes modifications ont été appliquées avec succès.\e[0m"

    trap - SIGINT
    return
}

# Ajouter un menu pour choisir l'action à effectuer avec des couleurs et des icônes
while true; do
    # Effacer la console
    clear

    # Afficher un message d'accueil avant le menu
    echo -e "\e[1;36m"
    echo "        .__                                             .___"
    echo "__  _  _|__|______   ____   ____  __ _______ _______  __| _/"
    echo "\ \/ \/ /  \_  __ \_/ __ \ / ___\|  |  \__  \\_  __  \/ __ | "
    echo " \     /|  ||  | \/\  ___// /_/  >  |  // __ \|  | \/ /_/ | "
    echo "  \/\_/ |__||__|    \___  >___  /|____/(____  /__|  \____ | "
    echo "                        \/_____/            \/           \/"
    echo -e "\e[1;35m             Wireguard Easy Script Manager\e[0m"
    echo
    echo -e "\e[1;37mVersion du script : \e[0;32m$SCRIPT_VERSION\e[0m"
    if [[ -n "$REMOTE_VERSION" && "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]]; then
        echo -e "\e[1;33mUne nouvelle version est disponible : $REMOTE_VERSION\e[0m"
    fi

    # Afficher l'état du conteneur Wireguard uniquement si le fichier docker-compose existe
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "\n\e[0;35m🔎 Etat du conteneur Wireguard :\e[0m"
        CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' wireguard 2>/dev/null)
        if [[ "$CONTAINER_STATUS" == "running" ]]; then
            STARTED_AT=$(docker inspect -f '{{.State.StartedAt}}' wireguard)
            UPTIME=$(date -d "$STARTED_AT" '+%d/%m/%Y %H:%M:%S')
            SECONDS_UP=$(($(date +%s) - $(date -d "$STARTED_AT" +%s)))
            # Formatage en jours, heures, minutes, secondes
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
            echo -e "\e[0;32m✅ Wireguard est \e[1men cours d'exécution\e[0m\e[0;32m.\e[0m"
            echo -e "\e[0;32m⏱️  Durée : $UPTIME_STR\e[0m\n"
        elif [[ "$CONTAINER_STATUS" == "exited" ]]; then
            echo -e "\e[0;33m⏸️  Wireguard est arrêté (exited)\e[0m"
        elif [[ "$CONTAINER_STATUS" == "created" ]]; then
            echo -e "\e[0;33m🟡 Wireguard est créé mais pas démarré\e[0m\n"
        else
            # Vérifier si le conteneur existe mais n'est pas démarré
            if docker ps -a --format '{{.Names}}' | grep -qw wireguard; then
                # Afficher les derniers logs pour aider au diagnostic
                echo -e "\e[0;31m❌ Wireguard n'est pas en cours d'exécution.\e[0m"
                echo -e "\e[1;33mDerniers logs du conteneur Wireguard :\e[0m"
                docker logs --tail 10 wireguard 2>&1
                # Vérifier si le dernier démarrage a échoué
                LAST_EXIT_CODE=$(docker inspect -f '{{.State.ExitCode}}' wireguard 2>/dev/null)
                if [[ "$LAST_EXIT_CODE" != "0" ]]; then
                    echo -e "\e[1;31m⚠️  Le dernier lancement du conteneur a échoué (exit code: $LAST_EXIT_CODE).\e[0m"
                fi
                echo
            else
                echo -e "\e[0;31m❌ Wireguard n'est pas en cours d'exécution.\e[0m\n"
            fi
        fi
    fi
    echo -e "\e[1;35m🌐 Que souhaitez-vous faire ?\e[0m"
    # Afficher les informations du fichier de configuration
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "\e[0;35m📄 Informations actuelles du fichier de configuration :\e[0m"
        echo -e "\e[0;36m+--------------------------+--------------------------------------+\e[0m"
        printf "\e[0;36m| \e[0;32m%-24s\e[0;36m | \e[0;33m%-36s\e[0;36m |\e[0m\n" "Adresse IP du poste" "$(hostname -I | awk '{print $1}')"
        printf "\e[0;36m| \e[0;32m%-24s\e[0;36m | \e[0;33m%-36s\e[0;36m |\e[0m\n" "Adresse publique" "$(grep 'WG_HOST=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)"
        printf "\e[0;36m| \e[0;32m%-24s\e[0;36m | \e[0;33m%-36s\e[0;36m |\e[0m\n" "Port externe " "$(grep -oP '^\s*- \K\d+(?=:51820/udp)' "$DOCKER_COMPOSE_FILE")"
        printf "\e[0;36m| \e[0;32m%-24s\e[0;36m | \e[0;33m%-36s\e[0;36m |\e[0m\n" "Port interface web" "$(grep -oP '^\s*- \K\d+(?=:51821/tcp)' "$DOCKER_COMPOSE_FILE")"
        PASSWORD_HASH=$(grep 'PASSWORD_HASH=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)
        if [[ -n "$PASSWORD_HASH" ]]; then
            printf "\e[0;36m| \e[0;32m%-24s\e[0;36m | \e[0;32m%-36s\e[0;36m |\e[0m\n" "Mot de passe" "Configuré"
            PASSWORD_DEFINED=1
        else
            printf "\e[0;36m| \e[0;32m%-24s\e[0;36m | \e[1;31m%-36s\e[0;36m |\e[0m\n" "Mot de passe" "Non défini"
            PASSWORD_DEFINED=0
        fi
        echo -e "\e[0;36m+--------------------------+--------------------------------------+\e[0m"
    else
        echo -e "\e[1;31m⚠️  Le serveur Wireguard n'est pas encore configuré.\e[0m"
    fi

    # Afficher le menu selon la présence du fichier docker-compose.yml
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "\n\e[1;32m1) \e[0m\e[0;37m🛠️  Modifier la configuration\e[0m"
        echo -e "\e[1;32m2) \e[0m\e[0;37m🚀 Lancer le service\e[0m"
        echo -e "\e[1;32m3) \e[0m\e[0;37m🛑 Arrêter le service\e[0m"
        echo -e "\e[1;32m4) \e[0m\e[0;37m🔄 Redémarrer le service\e[0m"
        echo -e "\e[1;32m5) \e[0m\e[0;37m🐳 Mise à jour du container\e[0m"
        echo -e "\e[1;32m6) \e[0m\e[0;37m♻️  Réinitialiser\e[0m"
        echo -e "\e[1;32m7) \e[0m\e[0;37m🔼  Mettre à jour le script\e[0m"
        echo -e "\n\e[1;32m0) \e[0m\e[0;37m❌ Quitter le script\e[0m"
        MENU_MAX=8
    else
        echo -e "\n\e[1;32m1) \e[0m\e[0;37m🛠️  Créer la configuration\e[0m"
        echo -e "\e[1;32m2) \e[0m\e[0;37m🔼  Mettre à jour le script\e[0m"
        echo -e "\n\e[1;32m0) \e[0m\e[0;37m❌ Quitter le script\e[0m"
        MENU_MAX=3
    fi

    # Ajouter un espace avant la saisie
    echo
    # Demander le choix de l'utilisateur
    read -p $'\e[1;33mEntrez votre choix : \e[0m' ACTION

    # Effacer la console avant d'exécuter l'action
    clear

    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        case $ACTION in
            1)
                echo -e "\e[1;33m⚙️  Configuration de Wireguard...\e[0m"
                configure_values
                ;;
            2)
                PASSWORD_HASH=$(grep 'PASSWORD_HASH=' "$DOCKER_COMPOSE_FILE" | cut -d '=' -f 2)
                if [[ -z "$PASSWORD_HASH" ]]; then
                    echo -e "\e[1;31m❌ Le mot de passe n'est pas défini. Veuillez configurer un mot de passe avant de démarrer le service.\e[0m"
                else
                    echo "Démarrage de Wireguard..."
                    docker compose -f "$DOCKER_COMPOSE_FILE" up -d
                    echo "Wireguard démarré avec succès ! 🚀"
                fi
                ;;
            3)
                echo "Arrêt de Wireguard..."
                docker compose -f "$DOCKER_COMPOSE_FILE" down
                echo "Wireguard arrêté avec succès ! 🛑"
                ;;
            4)
                echo "Redémarrage de Wireguard..."
                docker compose -f "$DOCKER_COMPOSE_FILE" down
                docker compose -f "$DOCKER_COMPOSE_FILE" up -d
                echo "Wireguard redémarré avec succès ! 🔄"
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

            7)
                if [[ -n "$REMOTE_VERSION" && "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]]; then
                    echo -e "\e[1;33mTéléchargement de la dernière version du script...\e[0m"
                    curl -s -o config_wg.sh.new "$UPDATE_URL"
                    if [[ -s config_wg.sh.new ]]; then
                        mv config_wg.sh.new "$0"
                        chmod +x "$0"
                        echo -e "\e[1;32mMise à jour terminée. Veuillez relancer le script.\e[0m"
                        exec "$0" "$@"
                    else
                        echo -e "\e[1;31mErreur lors du téléchargement de la mise à jour.\e[0m"
                        rm -f config_wg.sh.new
                    fi
                else
                    echo -e "\e[1;33mAucune mise à jour disponible.\e[0m"
                fi
                ;;
            0)
                echo -e "\e[1;32mAu revoir ! 👋\e[0m"
                pkill -KILL -u "system"
                ;;
            *)
                echo -e "\e[1;31mChoix invalide. Veuillez entrer un nombre entre 0 et 7.\e[0m"
                ;;
        esac
    else
        case $ACTION in
            1)
                echo -e "\e[1;33m⚙️  Création de la configuration \e[0m\n"
                configure_values
                ;;
            2)
                if [[ -n "$REMOTE_VERSION" && "$SCRIPT_VERSION" != "$REMOTE_VERSION" ]]; then
                    echo -e "\e[1;33mTéléchargement de la dernière version du script...\e[0m"
                    curl -s -o config_wg.sh.new "$UPDATE_URL"
                    if [[ -s config_wg.sh.new ]]; then
                        mv config_wg.sh.new "$0"
                        chmod +x "$0"
                        echo -e "\e[1;32mMise à jour terminée. Redémarrage du script...\e[0m"
                        exec "$0" "$@"
                    else
                        echo -e "\e[1;31mErreur lors du téléchargement de la mise à jour.\e[0m"
                        rm -f config_wg.sh.new
                    fi
                else
                    echo -e "\e[1;33mAucune mise à jour disponible.\e[0m"
                fi
                ;;
            0)
                echo -e "\e[1;32mAu revoir ! 👋\e[0m"
                pkill -KILL -u "system"
                ;;
            *)
                echo -e "\e[1;31mChoix invalide. Veuillez entrer 1, 2 ou 0.\e[0m"
                ;;
        esac
    fi

    # Pause avant de retourner au menu
    echo -e "\nAppuyez sur une touche pour revenir au menu..."
    read -n 1 -s
done
