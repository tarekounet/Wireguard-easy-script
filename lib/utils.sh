##############################
#        VERSION MODULE      #
##############################

UTILS_VERSION="1.1.0"

##############################
#      AFFICHAGE COULEUR     #
##############################

msg_info()    { echo -e "\e[1;36m$1\e[0m"; }
msg_success() { echo -e "\e[1;32m$1\e[0m"; }
msg_warn()    { echo -e "\e[1;33m$1\e[0m"; }
msg_error()   { echo -e "\e[1;31m$1\e[0m"; }

##############################
#      VALIDATION ENTRÉES    #
##############################

validate_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 ))
}
validate_yesno() {
    local choice="${1,,}"
    [[ "$choice" == "o" || "$choice" == "n" || -z "$choice" ]]
}
validate_ip() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && \
    awk -F. '{for(i=1;i<=4;i++) if($i>255) exit 1}' <<< "$ip"
}

##############################
#      CHANGE PORT WEB       #
##############################

change_wg_easy_web_port() {
    local compose_file="$DOCKER_COMPOSE_FILE"
    local new_port

    read -p $'\e[1;33mEntrez le nouveau port pour l’interface web (par défaut 51821) : \e[0m' new_port
    if ! validate_port "$new_port"; then
        echo -e "\e[1;31mPort invalide.\e[0m"
        return 1
    fi

    # Modifie la variable d'environnement PORT="" dans le docker-compose
    if grep -qE 'PORT="?([0-9]+)"?' "$compose_file"; then
        sed -i -E "s/(PORT=)\"?[0-9]+\"?/\1\"$new_port\"/" "$compose_file"
        echo -e "\e[1;32mLe port de l’interface web a été modifié à : $new_port\e[0m"
    else
        echo -e "\e[1;31mImpossible de trouver la variable PORT dans $compose_file.\e[0m"
        return 1
    fi

    # Redémarre le conteneur pour appliquer le changement
    docker compose -f "$compose_file" down
    docker compose -f "$compose_file" up -d
    echo -e "\e[1;32mWireguard redémarré avec le nouveau port web.\e[0m"
}


##############################
#         LOGGING            #
##############################

log_action() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> /var/log/wg-easy-script.log
}

##############################
#     GESTION DES VERSIONS   #
##############################

version_gt() {
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=${#ver1[@]}; i<3; i++)); do ver1[i]=0; done
    for ((i=${#ver2[@]}; i<3; i++)); do ver2[i]=0; done
    for ((i=0; i<3; i++)); do
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 0
        elif ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 1
        fi
    done
    return 1
}

get_github_branch() {
    # Utilise la variable globale SCRIPT_CHANNEL
    if [[ "$SCRIPT_CHANNEL" == "beta" ]]; then
        echo "beta"
    else
        echo "main"
    fi
}

get_remote_module_version() {
    local module="$1"
    local branch
    branch=$(get_github_branch)
    curl -fsSL "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/$branch/lib/$module" | grep -m1 -E 'VERSION="?([0-9.]+)"?' | grep -oE '[0-9]+\.[0-9.]+'
}

##############################
#   AFFICHAGE DES VERSIONS   #
##############################

show_modules_versions() {
    msg_info "Versions des modules chargés :"
    for mod in utils conf docker menu debian_tools; do
        local_var=$(echo "${mod^^}_VERSION")
        local_version="${!local_var}"
        remote_version=$(get_remote_module_version "$mod.sh")
        if [[ -z "$remote_version" ]]; then
            status="\e[33m(Version distante inconnue)\e[0m"
        elif [[ "$local_version" != "$remote_version" ]]; then
            status="\e[33m(Mise à jour dispo: $remote_version)\e[0m"
        else
            status="\e[32m(à jour)\e[0m"
        fi
        printf "  %-16s : %s %b\n" "$mod.sh" "$local_version" "$status"
    done
}

show_modules_versions_fancy() {
    clear
    echo -e "\e[1;36m===== Versions des modules chargés =====\e[0m"
    printf "\e[0;36m%-30s : \e[0;32m%s\e[0m\n" "Utilitaires généraux" "$UTILS_VERSION"
    printf "\e[0;36m%-30s : \e[0;32m%s\e[0m\n" "Configuration principale" "$CONF_VERSION"
    printf "\e[0;36m%-30s : \e[0;32m%s\e[0m\n" "Gestion Docker" "$DOCKER_VERSION"
    printf "\e[0;36m%-30s : \e[0;32m%s\e[0m\n" "Menu principal" "$MENU_VERSION"
    printf "\e[0;36m%-30s : \e[0;32m%s\e[0m\n" "Outils Debian" "$DEBIAN_TOOLS_VERSION"
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu...\e[0m"
    read -n 1 -s
}

show_changelog() {
    clear
    msg_info "===== CHANGELOG DU SCRIPT ====="
    if [[ -f CHANGELOG.md ]]; then
        cat CHANGELOG.md
    else
        msg_error "Aucun fichier CHANGELOG.md trouvé."
    fi
    msg_warn "Appuyez sur une touche pour revenir au menu..."
    read -n 1 -s
}

##############################
#     MISE À JOUR MODULES    #
##############################

check_updates() {
    MODULE_UPDATE_AVAILABLE=0
    SCRIPT_UPDATE_AVAILABLE=0

    # Vérification des modules
    for mod in utils conf docker menu debian_tools; do
        local_var=$(echo "${mod^^}_VERSION")
        local_version="${!local_var}"
        remote_version=$(get_remote_module_version "$mod.sh")
        if [[ -n "$remote_version" && "$local_version" != "$remote_version" ]]; then
            MODULE_UPDATE_AVAILABLE=1
            break
        fi
    done

    # Vérification du script principal
    local branch
    branch=$(get_github_branch)
    remote_script_version=$(curl -fsSL "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/$branch/config_wg.sh" | grep -m1 -E 'SCRIPT_BASE_VERSION_INIT="?([0-9.]+)"?' | grep -oE '[0-9]+\.[0-9.]+')
    if [[ -n "$remote_script_version" && "$SCRIPT_BASE_VERSION_INIT" != "$remote_script_version" ]]; then
        SCRIPT_UPDATE_AVAILABLE=1
    fi
}

update_modules() {
    local branch
    branch=$(get_github_branch)
    local updated=0
    for mod in utils conf docker menu debian_tools; do
        remote_version=$(get_remote_module_version "$mod.sh")
        local_var=$(echo "${mod^^}_VERSION")
        local_version="${!local_var}"
        if [[ -n "$remote_version" && "$local_version" != "$remote_version" ]]; then
            if curl -fsSL -o "lib/$mod.sh" "https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/$branch/lib/$mod.sh"; then
                msg_success "Module \"$mod\" mis à jour (v$local_version → v$remote_version)"
                updated=1
            else
                msg_error "Échec de la mise à jour du module \"$mod\""
            fi
        else
            msg_info "Module \"$mod\" est déjà à jour (v$local_version)."
        fi
    done
    if [[ "$updated" -eq 1 ]]; then
        msg_warn "Relance le script pour charger les nouveaux modules."
    else
        msg_info "Tous les modules sont déjà à jour."
    fi
}

#################################
#   SCAN PORT AVEC VALIDATION   #
#################################

find_external_port_for_51820() {
    if ! command -v nmap >/dev/null 2>&1; then
        echo -e "\e[1;33mnmap n'est pas installé. Installation en cours...\e[0m"
        sudo apt update && sudo apt install -y nmap
        if ! command -v nmap >/dev/null 2>&1; then
            echo -e "\e[1;31mErreur : l'installation de nmap a échoué. Veuillez l'installer manuellement.\e[0m"
            return 1
        fi
    fi

    IP_PUBLIC=$(curl -s https://api.ipify.org)
    echo -e "\e[1;36mIP publique détectée : $IP_PUBLIC\e[0m"
    echo -e "\e[1;33mRecherche automatique des ports UDP ouverts sur votre box (1-10000, cela peut prendre du temps)...\e[0m"

    PORTS_FOUND=()
    while read -r line; do
        port=$(echo "$line" | awk -F/ '{print $1}')
        PORTS_FOUND+=("$port")
    done < <(nmap -sU --open -p 1-10000 "$IP_PUBLIC" | grep -E '^[0-9]+/udp\s+open')

    if [[ ${#PORTS_FOUND[@]} -eq 0 ]]; then
        echo -e "\e[1;32mAucun port UDP ouvert détecté sur votre box dans la plage 1-10000.\e[0m"
        return 1
    fi

    echo -e "\e[1;33mPorts UDP ouverts détectés : ${PORTS_FOUND[*]}\e[0m"
    # On retourne la liste des ports trouvés
    FOUND_PORTS="${PORTS_FOUND[*]}"
}

auto_detect_and_validate_nat_port() {
    find_external_port_for_51820
    if [[ -z "$FOUND_PORTS" ]]; then
        echo -e "\e[1;31mAucun port UDP ouvert détecté, impossible de valider la redirection NAT.\e[0m"
        return 1
    fi

    for port in $FOUND_PORTS; do
        echo -e "\e[1;36mTest de la redirection NAT sur le port $port...\e[0m"
        # Utilise la fonction de validation avec docker web de test
        # On force le port à tester sans demander à l'utilisateur
        IP_PUBLIC=$(curl -s https://api.ipify.org)
        docker rm -f wg-port-test >/dev/null 2>&1
        docker run -d --name wg-port-test -p "$port":80 nginx:alpine >/dev/null
        sleep 2
        if curl -s --max-time 5 "http://$IP_PUBLIC:$port" | grep -qi 'nginx'; then
            echo -e "\e[1;32m✅ Succès : le port $port est bien ouvert et redirigé vers votre machine !\e[0m"
            docker rm -f wg-port-test >/dev/null
            set_conf_value "WG_EXTERNAL_PORT" "$port"
            return 0
        else
            echo -e "\e[1;31m❌ Échec : impossible d'accéder à http://$IP_PUBLIC:$port"
            docker rm -f wg-port-test >/dev/null
        fi
    done

    echo -e "\e[1;31mAucun des ports ouverts détectés ne fonctionne pour la redirection NAT avec un conteneur web de test.\e[0m"
    return 1
}