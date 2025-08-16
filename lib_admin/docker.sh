#!/bin/bash
# Fonctions de gestion Docker pour admin_menu.sh

reset_user_docker_wireguard() {
    clear
    echo -e "\e[48;5;236m\e[97m           🔄 RAZ DOCKER-WIREGUARD UTILISATEUR     \e[0m"
    # Filtrer uniquement les utilisateurs avec un dossier docker-wireguard non vide
    local FILTERED_USERS=()
    local USER_DISPLAY=()
    local idx=1
    for user in $(awk -F: '($3>=1000)&&($1!="nobody")&&($7!="/usr/sbin/nologin")&&($7!="/bin/false")&&($7!="/sbin/nologin")&&($7!="")&&($1!~"^_")&&($1!~"^systemd")&&($1!~"^daemon")&&($1!~"^mail")&&($1!~"^ftp")&&($1!~"^www-data")&&($1!~"^backup")&&($1!~"^list")&&($1!~"^proxy")&&($1!~"^uucp")&&($1!~"^news")&&($1!~"^gnats"){print $1}' /etc/passwd); do
        local home=$(getent passwd "$user" | cut -d: -f6)
        local docker_wg_path="$home/docker-wireguard"
        if [[ -d "$docker_wg_path" ]] && [[ $(find "$docker_wg_path" -type f 2>/dev/null | wc -l) -gt 0 ]]; then
            local file_count=$(find "$docker_wg_path" -type f 2>/dev/null | wc -l)
            FILTERED_USERS+=("$user")
            USER_DISPLAY+=("\e[90m│\e[0m [\e[1;36m$idx\e[0m] \e[97m$user\e[0m  \e[1;32m✓ docker-wireguard ($file_count fichiers)\e[0m")
            idx=$((idx+1))
        fi
    done
    if [[ ${#FILTERED_USERS[@]} -eq 0 ]]; then
        echo -e "\n\e[1;31m❌ Aucun utilisateur avec docker-wireguard configuré\e[0m"
        echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
        return
    fi
    echo -e "\n\e[48;5;24m\e[97m  👥 SÉLECTION UTILISATEUR  \e[0m"
    echo -e "\e[90m┌─────────────────────────────────────────────────────────────┐\e[0m"
    for line in "${USER_DISPLAY[@]}"; do
        echo -e "$line"
    done
    echo -e "\e[90m└─────────────────────────────────────────────────────────────┘\e[0m"
    echo -e "\n\e[48;5;22m\e[97m  🔧 ACTIONS DISPONIBLES  \e[0m"
    echo -e "\e[90m┌─────────────────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m│\e[0m \e[1;31m0\e[0m Retour au menu principal"
    echo -e "\e[90m└─────────────────────────────────────────────────────────────┘\e[0m"
    echo -ne "\n\e[1;33mNuméro de l'utilisateur [1-${#FILTERED_USERS[@]}] ou 0 pour annuler : \e[0m"
    read -r IDX
    if [[ "$IDX" == "0" ]]; then
        return
    fi
    IDX=$((IDX-1))
    if [[ $IDX -ge 0 && $IDX -lt ${#FILTERED_USERS[@]} ]]; then
        local TARGET_USER="${FILTERED_USERS[$IDX]}"
        local user_home=$(getent passwd "$TARGET_USER" | cut -d: -f6)
        local docker_wg_path="$user_home/docker-wireguard"
        clear
        echo -e "\e[48;5;236m\e[97m           🔄 CONFIRMATION RAZ DOCKER-WIREGUARD   \e[0m"
        echo -e "\n\e[48;5;24m\e[97m  📊 INFORMATIONS  \e[0m"
        echo -e "\n    \e[90m👤 Utilisateur :\e[0m \e[1;36m$TARGET_USER\e[0m"
        echo -e "    \e[90m📁 Répertoire :\e[0m \e[1;33m$docker_wg_path\e[0m"
        if [[ ! -d "$docker_wg_path" ]]; then
            echo -e "\n\e[1;31m❌ Le dossier docker-wireguard n'existe pas pour cet utilisateur\e[0m"
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
            return
        fi
        local file_count=$(find "$docker_wg_path" -type f 2>/dev/null | wc -l)
        local dir_count=$(find "$docker_wg_path" -mindepth 1 -type d 2>/dev/null | wc -l)
        echo -e "    \e[90m📄 Fichiers :\e[0m \e[1;32m$file_count\e[0m"
        echo -e "    \e[90m📂 Dossiers :\e[0m \e[1;32m$dir_count\e[0m"
        if [[ $file_count -eq 0 && $dir_count -eq 0 ]]; then
            echo -e "\n\e[1;33m⚠️  Le dossier est déjà vide\e[0m"
            echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
            read -n1 -s
            return
        fi
        echo -e "\n\e[1;31m⚠️  ATTENTION :\e[0m"
        echo -e "    \e[97m• Tout le contenu du dossier docker-wireguard sera supprimé\e[0m"
        echo -e "    \e[97m• Cette action est irréversible\e[0m"
        echo -e "    \e[97m• Les configurations WireGuard seront perdues\e[0m"
    echo -e "\n\e[1;33mTapez exactement 'RAZ WIREGUARD' pour confirmer :\e[0m"
    echo -ne "\e[1;36m→ \e[0m"
    read -r CONFIRMATION
    if [[ "$CONFIRMATION" == "RAZ WIREGUARD" ]]; then
            # Détection et arrêt du conteneur wg-easy si actif
            if docker ps --format '{{.Names}}' | grep -q "^wg-easy$"; then
                echo -e "\n\e[1;33mArrêt du conteneur Docker wg-easy...\e[0m"
                docker stop wg-easy
                echo -e "\e[1;32m✓ Conteneur wg-easy arrêté\e[0m"
            fi
            rm -rf "$docker_wg_path"/* "$docker_wg_path"/.??* 2>/dev/null
            echo -e "\n\e[1;32m✓ Dossier docker-wireguard réinitialisé pour $TARGET_USER\e[0m"
        else
            echo -e "\n\e[1;33mOpération annulée\e[0m"
        fi
        echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
    else
        echo -e "\n\e[1;31mSélection invalide\e[0m"
        echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
    fi
}
check_and_install_docker() {
    clear
    echo -e "\e[48;5;236m\e[97m           🐳 VÉRIFICATION DES PRÉREQUIS SYSTÈME           \e[0m"

    echo -e "\n\e[1;33m🔍 Vérification de l'installation Docker, zip et unzip...\e[0m"

    # Vérifier zip
    if ! command -v zip &>/dev/null; then
        echo -e "\e[1;31m❌ zip n'est pas installé\e[0m"
        echo -e "\e[1;33mInstallation de zip...\e[0m"
        apt-get update && apt-get install -y zip
    else
        echo -e "\e[1;32m✓ zip est déjà installé\e[0m"
    fi

    # Vérifier unzip
    if ! command -v unzip &>/dev/null; then
        echo -e "\e[1;31m❌ unzip n'est pas installé\e[0m"
        echo -e "\e[1;33mInstallation de unzip...\e[0m"
        apt-get update && apt-get install -y unzip
    else
        echo -e "\e[1;32m✓ unzip est déjà installé\e[0m"
    fi

    # Vérifier si Docker est installé
    if command -v docker &>/dev/null; then
        echo -e "\e[1;32m✓ Docker est déjà installé\e[0m"

        # Vérifier si Docker Compose est installé
        if command -v docker-compose &>/dev/null || docker compose version &>/dev/null; then
            echo -e "\e[1;32m✓ Docker Compose est déjà installé\e[0m"

            # Vérifier si le service Docker est actif
            if systemctl is-active docker &>/dev/null; then
                echo -e "\e[1;32m✓ Service Docker est actif\e[0m"
                echo -e "\n\e[1;32m🎉 Docker est prêt à être utilisé !\e[0m"
                return 0
            else
                echo -e "\e[1;33m⚠️  Service Docker inactif, démarrage...\e[0m"
                systemctl start docker
                systemctl enable docker
                echo -e "\e[1;32m✓ Service Docker démarré\e[0m"
                return 0
            fi
        else
            echo -e "\e[1;33m⚠️  Docker Compose manquant, installation...\e[0m"
            # Docker Compose legacy supprimé
        fi
    else
        echo -e "\e[1;31m❌ Docker n'est pas installé\e[0m"
        echo -e "\n\e[1;33m🚀 Lancement de l'installation Docker...\e[0m"
        check_and_install_docker
    fi
}

# Install Docker
install_docker() {
    echo -e "\n\e[48;5;24m\e[97m  📦 INSTALLATION DOCKER (DEBIAN)  \e[0m"
    
    echo -e "\n\e[1;33m📝 Étape 1/8 - Mise à jour des paquets...\e[0m"
    apt-get update || { echo -e "\e[1;31m❌ Échec de la mise à jour\e[0m"; return 1; }
    
    echo -e "\n\e[1;33m📝 Étape 2/8 - Vérification des mises à jour système...\e[0m"
    echo -e "\e[1;36m🔍 Recherche des mises à jour disponibles...\e[0m"
    UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
    if [[ "$UPGRADABLE" -gt 0 ]]; then
        echo -e "\e[1;33m⚠️  $UPGRADABLE paquets peuvent être mis à jour\e[0m"
        echo -ne "\e[1;33mEffectuer les mises à jour système maintenant ? [o/N] : \e[0m"
        read -r UPDATE_SYSTEM
        if [[ "$UPDATE_SYSTEM" =~ ^[oOyY]$ ]]; then
            echo -e "\e[1;33m🔄 Mise à jour du système en cours...\e[0m"
            apt-get upgrade -y || echo -e "\e[1;33m⚠️  Certaines mises à jour ont échoué, continuons...\e[0m"
            echo -e "\e[1;32m✓ Mises à jour système terminées\e[0m"
        else
            echo -e "\e[1;33m⏭️  Mises à jour système ignorées\e[0m"
        fi
    else
        echo -e "\e[1;32m✓ Système déjà à jour\e[0m"
    fi
    
    echo -e "\n\e[1;33m📝 Étape 3/8 - Installation des outils essentiels...\e[0m"
    echo -e "\e[1;36m🔧 Installation de vim et sudo...\e[0m"
    apt-get install -y vim sudo || { echo -e "\e[1;31m❌ Échec installation outils essentiels\e[0m"; return 1; }
    echo -e "\e[1;32m✓ vim et sudo installés\e[0m"
    
    echo -e "\n\e[1;33m📝 Étape 4/8 - Installation des prérequis Docker...\e[0m"
    apt-get install -y ca-certificates curl || { echo -e "\e[1;31m❌ Échec installation prérequis\e[0m"; return 1; }
    
    echo -e "\n\e[1;33m📝 Étape 5/8 - Configuration des clés GPG...\e[0m"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc || { echo -e "\e[1;31m❌ Échec téléchargement clé GPG\e[0m"; return 1; }
    chmod a+r /etc/apt/keyrings/docker.asc
    
    echo -e "\n\e[1;33m📝 Étape 6/8 - Ajout du dépôt Docker...\e[0m"
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null || { echo -e "\e[1;31m❌ Échec ajout dépôt\e[0m"; return 1; }
    
    echo -e "\n\e[1;33m📝 Étape 7/8 - Mise à jour avec le nouveau dépôt...\e[0m"
    apt-get update || { echo -e "\e[1;31m❌ Échec mise à jour dépôt\e[0m"; return 1; }
    
    echo -e "\n\e[1;33m📝 Étape 8/8 - Installation Docker...\e[0m"
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || {
        echo -e "\e[1;31m❌ Échec installation Docker\e[0m"
        return 1
    }
    
    echo -e "\n\e[1;33m🔧 Configuration du service Docker...\e[0m"
    systemctl start docker
    systemctl enable docker
    
    echo -e "\n\e[1;33m🧪 Test de l'installation...\e[0m"
    if docker --version && docker compose version; then
        echo -e "\n\e[1;32m✅ DOCKER INSTALLÉ AVEC SUCCÈS !\e[0m"
        echo -e "\e[90m┌─────────────────────────────────────────────────┐\e[0m"
        echo -e "\e[90m│\e[0m \e[1;36mDocker :\e[0m $(docker --version | cut -d' ' -f3 | tr -d ',')"
        echo -e "\e[90m│\e[0m \e[1;36mDocker Compose :\e[0m $(docker compose version --short 2>/dev/null || echo "Plugin intégré")"
        echo -e "\e[90m│\e[0m \e[1;36mStatut :\e[0m \e[1;32mActif et prêt\e[0m"
        echo -e "\e[90m└─────────────────────────────────────────────────┘\e[0m"
        
        echo -e "\n\e[1;32mAppuyez sur une touche pour continuer...\e[0m"
        read -n1 -s
        return 0
    else
        echo -e "\e[1;31m❌ L'installation semble avoir échoué\e[0m"
        return 1
    fi
}