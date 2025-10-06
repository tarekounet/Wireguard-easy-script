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
        if [[ "$CONFIRMATION" == "RAZ WIREGUARD" ]]; then
                # Vérifier la présence de Docker
                if ! command -v docker &>/dev/null; then
                    echo -e "\n\e[1;31m❌ Docker n'est pas disponible sur ce système. Impossible de gérer les conteneurs/volumes.\e[0m"
                else
                    # 1) Si un fichier docker-compose existe, tenter docker compose down dans le répertoire
                    compose_file=""
                    for f in "$docker_wg_path/docker-compose.yml" "$docker_wg_path/docker-compose.yaml"; do
                        if [[ -f "$f" ]]; then
                            compose_file="$f"
                            break
                        fi
                    done

                    if [[ -n "$compose_file" ]]; then
                        echo -e "\n\e[1;33mFichier compose détecté: $compose_file. Arrêt de la stack (docker compose down)...\e[0m"
                        pushd "$docker_wg_path" >/dev/null 2>&1 || true
                        if docker compose version >/dev/null 2>&1; then
                            docker compose down || true
                        else
                            docker-compose down || true
                        fi
                        popd >/dev/null 2>&1 || true
                    else
                        # fallback: arrêter wg-easy si présent
                        if docker ps --format '{{.Names}}' | grep -q "^wg-easy$"; then
                            echo -e "\n\e[1;33mArrêt du conteneur Docker wg-easy...\e[0m"
                            docker stop wg-easy >/dev/null 2>&1 || true
                        fi
                    fi

                    # 2) Détecter et forcer la suppression des conteneurs qui montent le volume
                    blockers=()
                    for cid in $(docker ps -aq); do
                        mounts=$(docker inspect -f '{{range .Mounts}}{{.Name}} {{end}}' "$cid" 2>/dev/null || echo "")
                        if echo "$mounts" | grep -qw 'docker-wireguard_etc_wireguard'; then
                            blockers+=("$cid")
                        fi
                    done

                    if [[ ${#blockers[@]} -gt 0 ]]; then
                        echo -e "\n\e[1;33mSuppression forcée des conteneurs qui utilisent le volume...\e[0m"
                        for cid in "${blockers[@]}"; do
                            name=$(docker inspect -f '{{.Name}}' "$cid" 2>/dev/null | sed 's/^\\///')
                            echo -e "  - Suppression $name ($cid)"
                            docker rm -f "$cid" >/dev/null 2>&1 && echo -e "    \e[1;32m✓ $name supprimé\e[0m" || echo -e "    \e[1;31m⚠️  Échec suppression $name ($cid)\e[0m"
                        done
                    else
                        echo -e "\n\e[1;33mAucun conteneur ne semble utiliser le volume (ou déjà arrêté).\e[0m"
                    fi

                    # 3) Supprimer le volume
                    if docker volume ls --format '{{.Name}}' | grep -q '^docker-wireguard_etc_wireguard$'; then
                        echo -e "\n\e[1;33mSuppression du volume Docker 'docker-wireguard_etc_wireguard'...\e[0m"
                        if docker volume rm docker-wireguard_etc_wireguard; then
                            echo -e "\e[1;32m✓ Volume 'docker-wireguard_etc_wireguard' supprimé\e[0m"
                        else
                            echo -e "\e[1;31m⚠️  Échec lors de la suppression du volume après tentative automatique. Supprimez manuellement : docker volume rm docker-wireguard_etc_wireguard\e[0m"
                        fi
                    else
                        echo -e "\n\e[1;33mℹ️  Volume 'docker-wireguard_etc_wireguard' introuvable, rien à supprimer\e[0m"
                    fi
                fi
                echo -e "\n\e[1;32m✓ RAZ Docker-WireGuard effectué pour $TARGET_USER (opérations automatiques exécutées)\e[0m"
            else
                echo -e "\n\e[1;33mOpération annulée\e[0m"
            fi
                                    echo -e "\e[1;32m✓ Volume 'docker-wireguard_etc_wireguard' supprimé\e[0m"
                                else
                                    echo -e "\e[1;31m⚠️  Échec lors de la suppression du volume après suppression des conteneurs. Supprimez manuellement avec : docker volume rm docker-wireguard_etc_wireguard\e[0m"
                                fi
                            else
                                echo -e "\n\e[1;33mOpération annulée par l'utilisateur. Vous pouvez supprimer manuellement le(s) conteneur(s) ou le volume.\e[0m"
                                echo -e "\e[1;33mCommandes utiles :\e[0m"
                                echo -e "  docker ps -a --no-trunc | grep <container-id>" 
                                echo -e "  docker rm -f <container-id>" 
                                echo -e "  docker volume rm docker-wireguard_etc_wireguard"
                            fi
                        else
                            echo -e "\n\e[1;31m⚠️  Aucune référence trouvée aux conteneurs, mais la suppression a échoué. Vous pouvez tenter manuellement : docker volume rm docker-wireguard_etc_wireguard\e[0m"
                        fi
                    fi
                else
                    echo -e "\n\e[1;33mℹ️  Volume 'docker-wireguard_etc_wireguard' introuvable, rien à supprimer\e[0m"
                fi
            fi
            echo -e "\n\e[1;32m✓ RAZ Docker-WireGuard effectué pour $TARGET_USER (volume supprimé si présent)\e[0m"
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
    echo -e "\e[48;5;236m\e[97m           🐳 VÉRIFICATION DE DOCKER (INSTALLÉ + DÉMON)           \e[0m"

    # Vérifier si la commande docker est présente
    if ! command -v docker &>/dev/null; then
        echo -e "\n\e[1;31m❌ Docker n'est pas installé sur ce système.\e[0m"
        echo -e "\e[1;33m➡️  Installez Docker manuellement puis relancez le script.\e[0m"
        return 1
    fi

    # Vérifier que le démon Docker répond
    if ! docker info >/dev/null 2>&1; then
        echo -e "\n\e[1;31m❌ Docker est installé mais le démon ne répond pas (le service Docker n'est pas démarré).\e[0m"
        echo -e "\e[1;33m➡️  Démarrez le service Docker (par ex. 'systemctl start docker' ou redémarrez la machine) puis relancez le script.\e[0m"
        return 2
    fi

    echo -e "\n\e[1;32m✓ Docker est installé et le démon répond.\e[0m"
    return 0
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