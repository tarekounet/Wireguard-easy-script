##############################
#        VERSION MODULE      #
##############################

UTILS_VERSION="1.2.3"

##############################
#        acces ROOT          #
##############################

run_as_root() {
    if [[ $EUID -ne 0 ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

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
    for file in "$(dirname "${BASH_SOURCE[0]}")"/*.sh; do
        mod=$(basename "$file" .sh)
        local_var=$(echo "${mod^^}_VERSION")
        local_version="${!local_var:-inconnue}"
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
    for file in "$(dirname "${BASH_SOURCE[0]}")"/*.sh; do
        mod_name=$(basename "$file" .sh)
        # Ignore utils.sh si tu ne veux pas l'afficher
        [[ "$mod_name" == "utils" ]] && continue
        # Cherche la variable VERSION dans le fichier
        version=$(grep -m1 -E 'VERSION="?([0-9.]+)"?' "$file" | grep -oE '[0-9]+\.[0-9.]+' || echo "inconnue")
        printf "\e[0;36m%-30s : \e[0;32m%s\e[0m\n" "$mod_name" "$version"
    done
    echo -e "\n\e[1;33mAppuyez sur une touche pour revenir au menu...\e[0m"
    read
}

show_changelog() {
    clear
    if [[ -f "CHANGELOG.md" ]]; then
        less -R "CHANGELOG.md"
    else
        echo -e "\e[31mAucun changelog trouvé.\e[0m"
        sleep 2
    fi
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

##############################
#     Check des prerequis    #
############################## 

check_and_install_prerequisites() {
    local missing=0

    # Docker
    if ! command -v docker >/dev/null 2>&1; then
        msg_warn "Docker n'est pas installé. Installation en cours..."
        run_as_root apt update
        run_as_root apt install -y docker.io
        missing=1
    fi

    # docker compose (plugin ou standalone)
    if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
        msg_warn "docker compose n'est pas installé. Installation en cours..."
        run_as_root apt install -y docker-compose-plugin
        missing=1
    fi

    # sudo
    if ! command -v sudo >/dev/null 2>&1; then
        msg_warn "sudo n'est pas installé. Installation en cours..."
        apt update
        apt install -y sudo
        missing=1
    fi

    # curl
    if ! command -v curl >/dev/null 2>&1; then
        msg_warn "curl n'est pas installé. Installation en cours..."
        run_as_root apt update
        run_as_root apt install -y curl
        missing=1
    fi

    # btop (optionnel)
    if ! command -v btop >/dev/null 2>&1; then
        msg_warn "btop n'est pas installé (optionnel, pour le monitoring). Installation en cours..."
        run_as_root apt update
        run_as_root apt install -y btop
    fi

    if [[ "$missing" -eq 1 ]]; then
        msg_success "Les prérequis manquants ont été installés. Veuillez relancer le script si besoin."
    else
        msg_success "Tous les prérequis sont présents."
    fi
}

################################
#   Création de l'user + acl   #
################################

setup_script_user() {
    local user="system"
    local target_dir="/home/$user/github/Wireguard-easy-script"
    local script_name="config_wg.sh"
    local script_entry="$target_dir/$script_name"
    local password

    # Demande le mot de passe à l'utilisateur (en masqué)
    read -s -p "Entrez le mot de passe à définir pour l'utilisateur '$user' : " password
    echo

    # Crée l'utilisateur s'il n'existe pas
    if ! id "$user" &>/dev/null; then
        run_as_root useradd -m -s /bin/bash "$user"
        echo "$user:$password" | run_as_root chpasswd
        msg_success "Utilisateur '$user' créé avec succès."
    else
        msg_info "L'utilisateur '$user' existe déjà."
    fi

    # Ajoute au groupe docker
    if ! id -nG "$user" | grep -qw docker; then
        run_as_root usermod -aG docker "$user"
        msg_success "Utilisateur '$user' ajouté au groupe docker."
    fi

    # Crée le dossier cible si besoin
    run_as_root mkdir -p "$target_dir"

    # Copie le script principal si absent
    if [[ ! -f "$script_entry" ]]; then
        # Trouve le chemin absolu du script courant
        local current_script_path="$(realpath "$0")"
        run_as_root cp "$current_script_path" "$script_entry"
        msg_success "Script principal copié dans $target_dir."
    fi

    # Donne les droits d'écriture sur le dossier du script
    run_as_root chown -R "$user":"$user" "$target_dir"
    run_as_root chmod -R u+rwX "$target_dir"

    # Ajoute le lancement auto du script à la connexion (dans .bash_profile)
    local profile="/home/$user/.bash_profile"
    if ! grep -q "$script_entry" "$profile" 2>/dev/null; then
        echo "[[ \$- == *i* ]] && bash \"$script_entry\"" | run_as_root tee -a "$profile" >/dev/null
        msg_success "Le script sera lancé automatiquement à la connexion de $user."
    fi
}