#!/bin/bash
##############################
#         VARIABLES          #
##############################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

# Détection du bon HOME utilisateur même en sudo/root
if [[ $EUID -eq 0 && -n "$SUDO_USER" ]]; then
    USER_HOME="$(getent passwd $SUDO_USER | cut -d: -f6)"
else
    USER_HOME="$HOME"
fi

# Chemins principaux
DOCKER_WG_DIR="$USER_HOME/docker-wireguard"
DOCKER_COMPOSE_FILE="$DOCKER_WG_DIR/docker-compose.yml"
WG_CONF_DIR="$DOCKER_WG_DIR/config"
VERSION_FILE="$SCRIPT_DIR/version.txt"
WG_EASY_VERSION_FILE="$SCRIPT_DIR/WG_EASY_VERSION"

# URLs GitHub
GITHUB_BASE_URL="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main"
VERSION_URL="$GITHUB_BASE_URL/version.txt"
WG_EASY_VERSION_URL="$GITHUB_BASE_URL/WG_EASY_VERSION"

# Variables globales
WG_EASY_UPDATE_AVAILABLE=0
readonly SCRIPT_AUTHOR="Tarek.E"

# S'assurer que les dossiers existent
mkdir -p "$WG_CONF_DIR"

##############################
#      FONCTIONS UTILES      #
##############################

# Récupération sécurisée des versions
get_script_version() {
    cat "$VERSION_FILE" 2>/dev/null | head -n1 | tr -d '\n\r ' || echo ""
}

get_latest_script_version() {
    curl -fsSL --connect-timeout 10 "$VERSION_URL" 2>/dev/null | head -n1 | tr -d '\n\r '
}

get_wg_easy_github_version() {
    curl -fsSL --connect-timeout 10 "$WG_EASY_VERSION_URL" 2>/dev/null | head -n1 | tr -d '\n\r '
}

get_wg_easy_local_version() {
    local version=""
    
    # Priorité 1: docker-compose.yml
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        version=$(grep -o 'ghcr.io/wg-easy/wg-easy:[^[:space:]]*' "$DOCKER_COMPOSE_FILE" 2>/dev/null | cut -d: -f3 | head -n1)
    fi
    
    echo "$version"
}

# Comparaison de versions
version_gt() {
    [ "$1" = "$2" ] && return 1
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | tail -n1)" = "$1" ]
}

# Affichage des informations de version
# Affichage des informations container
display_container_info() {
    local wg_easy_distant="$(get_wg_easy_github_version)"
    local wg_easy_local="$(get_wg_easy_local_version)"
    
    # Sauvegarder la version GitHub
    [[ -n "$wg_easy_distant" ]] && echo "$wg_easy_distant" > "$WG_EASY_VERSION_FILE"
    
    # Vérifier d'abord si le conteneur existe
    if ! docker ps -a --format '{{.Names}}' | grep -qw wg-easy 2>/dev/null; then
        container_status=""
    else
        container_status=$(docker inspect -f '{{.State.Status}}' wg-easy 2>/dev/null)
    fi
    
    # Debug: afficher l'état détecté seulement si DEBUG est activé
    [[ -n "$DEBUG" ]] && echo "DEBUG: container_status='$container_status'"
    
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo -e "\e[48;5;235m\e[97m           📊 ÉTAT DU SERVICE WIREGUARD           \e[0m"

        
        case "$container_status" in
            running)
                local started_at=$(docker inspect -f '{{.State.StartedAt}}' wg-easy 2>/dev/null)
                if [[ -n "$started_at" ]]; then
                    local current_time=$(date +%s)
                    local start_time=$(date -d "$started_at" +%s 2>/dev/null)
                    if [[ -n "$start_time" && "$start_time" -gt 0 ]]; then
                        local seconds_up=$((current_time - start_time))
                        if [[ "$seconds_up" -gt 0 ]]; then
                            local days=$((seconds_up/86400))
                            local hours=$(( (seconds_up%86400)/3600 ))
                            local minutes=$(( (seconds_up%3600)/60 ))
                            local uptime_str=$(printf "%d jours, %02dh:%02dm" "$days" "$hours" "$minutes")
                            echo -e "\n    \e[1;42m\e[30m ✓ ACTIF \e[0m \e[97mService Wireguard en fonctionnement\e[0m"
                            echo -e "    \e[90m⏱️  Uptime :\e[0m \e[1;32m$uptime_str\e[0m"
                        else
                            echo -e "\n    \e[1;42m\e[30m ✓ ACTIF \e[0m \e[97mService Wireguard en fonctionnement\e[0m"
                        fi
                    else
                        echo -e "\n    \e[1;42m\e[30m ✓ ACTIF \e[0m \e[97mService Wireguard en fonctionnement\e[0m"
                    fi
                else
                    echo -e "\n    \e[1;42m\e[30m ✓ ACTIF \e[0m \e[97mService Wireguard en fonctionnement\e[0m"
                fi
                ;;
            exited)
                echo -e "\n    \e[1;43m\e[30m ⏸ ARRÊTÉ \e[0m \e[97mService Wireguard arrêté\e[0m"
                ;;
            created)
                echo -e "\n    \e[1;44m\e[30m ⧗ CRÉÉ \e[0m \e[97mService créé mais non démarré\e[0m"
                ;;
            *)
                if [[ -n "$container_status" ]]; then
                    # Le conteneur existe mais n'est pas dans un état reconnu
                    echo -e "\n    \e[1;41m\e[97m ✗ ERREUR \e[0m \e[97mService en erreur (état: $container_status)\e[0m"
                    log_error "Container wg-easy dans un état inattendu: $container_status"
                    local last_exit_code=$(docker inspect -f '{{.State.ExitCode}}' wg-easy 2>/dev/null)
                    if [[ "$last_exit_code" != "0" ]]; then
                        echo -e "    \e[90m⚠️  Code d'erreur :\e[0m \e[1;31m$last_exit_code\e[0m"
                        log_error "Container wg-easy exit code: $last_exit_code"
                    fi
                else
                    # Le conteneur n'existe pas
                    echo -e "\n    \e[1;45m\e[97m ⚫ ARRÊT \e[0m \e[97mService arrêté\e[0m"
                fi
                ;;
        esac
        
        # Affichage version WireGuard Easy Container
        if [[ -n "$wg_easy_distant" && -n "$wg_easy_local" && "$wg_easy_local" != "$wg_easy_distant" ]]; then
            echo -e "    \e[90m🐳 Container :\e[0m \e[1;36m$wg_easy_local\e[0m"
            echo -e "    \e[1;43m\e[30m ⚡ NOUVEAU \e[0m \e[1;33mVersion $wg_easy_distant disponible\e[0m"
            WG_EASY_UPDATE_AVAILABLE=1
        elif [[ -n "$wg_easy_local" ]]; then
            echo -e "    \e[90m🐳 Container :\e[0m \e[1;36m$wg_easy_local\e[0m \e[1;32m(à jour)\e[0m"
        else
            echo -e "    \e[90m🐳 Container :\e[0m \e[1;31mNon détectée\e[0m"
        fi
        
        # Informations réseau
        display_network_info
    else

        echo -e "\e[48;5;235m\e[97m           ⚠️  CONFIGURATION REQUISE             \e[0m"

        echo -e "\n    \e[1;43m\e[30m ! CONFIG \e[0m \e[97mLe serveur Wireguard n'est pas encore configuré\e[0m"
        echo -e "    \e[90m📝 Utilisez l'option de configuration pour commencer\e[0m"
    fi
    
    # Export pour les autres fonctions
    export CONTAINER_STATUS="$container_status"
}

# Affichage des informations réseau
display_network_info() {
    local ip_address=$(hostname -I | awk '{print $1}')
    local interface=$(ip route | awk '/default/ {print $5; exit}')
    local web_port=$(grep -oP 'PORT=\K[0-9]+' "$DOCKER_COMPOSE_FILE" 2>/dev/null | head -n1)

    # Détermination du type d'adresse IP
    local dhcp_state="Statique"
    if [[ -n "$interface" ]] && (grep -q "dhcp" "/etc/network/interfaces" 2>/dev/null || \
        grep -q "dhcp" "/etc/netplan/"*.yaml 2>/dev/null || \
        nmcli device show "$interface" 2>/dev/null | grep -q "IP4.DHCP4.OPTION"); then
        dhcp_state="DHCP"
    fi

    echo -e "    \e[90m🌐 Adresse IP :\e[0m \e[1;36m$ip_address\e[0m \e[90m($dhcp_state)\e[0m"
    echo -e "    \e[90m🔗 Port web :\e[0m \e[1;36m${web_port:-Non défini}\e[0m"
}

# Construction et affichage du menu principal
display_main_menu() {

    local labels=()
    local actions=()
    local group_separators=()
    local group_titles=()

    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        build_configured_menu labels actions group_separators group_titles
    else
        build_initial_menu labels actions group_separators group_titles
    fi

    display_menu_items labels group_separators group_titles
    export MENU_LABELS=("${labels[@]}")
    export MENU_ACTIONS=("${actions[@]}")
}

# Construction du menu pour configuration existante
build_configured_menu() {
    local -n labels_ref=$1
    local -n actions_ref=$2
    local -n separators_ref=$3
    local -n titles_ref=$4

    # Groupe 1 : Gestion du service
    separators_ref+=(0)
    titles_ref+=("🚀 SERVICE WIREGUARD")
    
    if [[ "$CONTAINER_STATUS" == "running" ]]; then
        labels_ref+=("Démarrer le service" "Arrêter le service" "Redémarrer le service")
        actions_ref+=("" "shutdown_wireguard" "restart_wireguard")
    else
        labels_ref+=("Démarrer le service" "Arrêter le service" "Redémarrer le service")
        actions_ref+=("start_wireguard" "" "")
    fi
    
    # Ajouter l'option de mise à jour du container
    local update_label="Mettre à jour le container"
    [[ "$WG_EASY_UPDATE_AVAILABLE" == "1" ]] && update_label+=" ⚡ MISE À JOUR DISPONIBLE"
    labels_ref+=("$update_label")
    actions_ref+=("update_wireguard_container")

    # Groupe 2 : Outils
    separators_ref+=(${#labels_ref[@]})
    titles_ref+=("🔧 OUTILS & INFORMATIONS")
    labels_ref+=("Voir le changelog")
    actions_ref+=("show_changelog")
}

# Construction du menu pour configuration initiale
build_initial_menu() {
    local -n labels_ref=$1
    local -n actions_ref=$2
    local -n separators_ref=$3
    local -n titles_ref=$4

    separators_ref+=(0)
    titles_ref+=("🛠️ CONFIGURATION INITIALE")
    labels_ref+=("Créer la configuration Wireguard" "Voir le changelog")
    actions_ref+=("configure_values" "show_changelog")
}

# Affichage des éléments du menu
display_menu_items() {
    local -n labels_ref=$1
    local -n separators_ref=$2
    local -n titles_ref=$3
    
    local group_idx=0
    echo ""
    
    for i in "${!labels_ref[@]}"; do
        # Affichage du titre de groupe
        if [[ " ${separators_ref[@]} " =~ " $i " ]]; then
            if [[ $group_idx -gt 0 ]]; then
                echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
                echo ""
            fi
            
            # Couleurs de fond différentes selon le groupe
            local bg_color=""
            case "${titles_ref[$group_idx]}" in
                *"SERVICE WIREGUARD"*) bg_color="\e[48;5;22m" ;;  # Vert foncé
                *"OUTILS & INFORMATIONS"*) bg_color="\e[48;5;94m" ;;  # Orange foncé
                *"CONFIGURATION INITIALE"*) bg_color="\e[48;5;17m" ;;  # Bleu marine
                *) bg_color="\e[48;5;24m" ;;  # Bleu par défaut
            esac
            
            echo -e "${bg_color}\e[97m  ${titles_ref[$group_idx]}  \e[0m"
            echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
            ((group_idx++))
        fi
        
        # Préparation de l'affichage selon l'état
        local prefix="├─"
        local suffix="│"
        local item_color="\e[97m"  # Blanc
        local number_color="\e[1;36m"  # Cyan bold
        local status=""
        
        # Détermination du statut et des couleurs
        if [[ "${labels_ref[$i]}" =~ MISE\ À\ JOUR\ DISPONIBLE ]]; then
            status=" \e[1;43m\e[30m NOUVEAU \e[0m"
            item_color="\e[1;33m"  # Jaune bold
        elif [[ "$CONTAINER_STATUS" == "running" && "${labels_ref[$i]}" == "Démarrer le service" ]]; then
            status=" \e[1;42m\e[30m ACTIF \e[0m"
            item_color="\e[90m"  # Gris
            number_color="\e[90m"  # Gris
        elif [[ "$CONTAINER_STATUS" != "running" && ("${labels_ref[$i]}" == "Arrêter le service" || "${labels_ref[$i]}" == "Redémarrer le service") ]]; then
            status=" \e[1;41m\e[97m ARRÊTÉ \e[0m"
            item_color="\e[90m"  # Gris
            number_color="\e[90m"  # Gris
        fi
        
        # Affichage de l'option
        echo -e "\e[90m    $prefix \e[0m$number_color$(printf "%2d" $((i+1)))\e[0m $item_color${labels_ref[$i]}\e[0m$status"
    done
    
    # Fermeture du dernier groupe
    if [[ ${#labels_ref[@]} -gt 0 ]]; then
        echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
    fi
    
    echo ""
    echo -e "\e[90m    ┌─────────────────────────────────────────────────┐\e[0m"
    echo -e "\e[90m    ├─ \e[0m\e[1;31m 0\e[0m \e[97mQuitter le programme\e[0m \e[1;31m🚪\e[0m"
    echo -e "\e[90m    └─────────────────────────────────────────────────┘\e[0m"
    
    # Footer discret avec version
    echo -e "\n\e[90m    ${SCRIPT_AUTHOR} • v$(get_script_version)\e[0m"
}

# Gestion du choix utilisateur
handle_user_choice() {
    echo
    read -p $'\e[1;33mEntrez votre choix : \e[0m' CHOICE
    
    if [[ -z "$CHOICE" ]]; then
        echo -e "\e[1;31mAucune saisie détectée. Merci de saisir un numéro.\e[0m"
        return
    fi
    
    clear
    local skip_pause=0

    if [[ "$CHOICE" == "0" ]]; then
        clear
        echo -e "\e[1;32mAu revoir ! 👋\e[0m"
        exit 0
    elif [[ "$CHOICE" =~ ^[1-9][0-9]*$ && "$CHOICE" -le "${#MENU_ACTIONS[@]}" ]]; then
        local action="${MENU_ACTIONS[$((CHOICE-1))]}"
        execute_action "$action" skip_pause
    else
        echo -e "\e[1;31mChoix invalide.\e[0m"
    fi

    if [[ "$skip_pause" != "1" ]]; then
        echo -e "\nAppuyez sur une touche pour revenir au menu..."
        read -n 1 -s
    fi
}

# Exécution des actions
execute_action() {
    local action="$1"
    local -n skip_ref=$2
    
    case "$action" in
        start_wireguard) start_wireguard; skip_ref=1 ;;
        shutdown_wireguard) stop_wireguard; skip_ref=1 ;;
        restart_wireguard) restart_wireguard; skip_ref=1 ;;
        update_wireguard_container) update_wireguard_container; skip_ref=1 ;;
        show_changelog) show_changelog ;;
        configure_values) configure_values ;;
        "") ;; # Option inactive
        *) echo -e "\e[1;31mChoix invalide.\e[0m" ;;
    esac
}

##############################
#      MENU PRINCIPAL        #
##############################

main_menu() {
    while true; do
        detect_new_wg_easy_version
        clear
        show_logo_ascii
        
        # Informations container et configuration
        display_container_info
        
        # Menu principal
        display_main_menu
        
        # Traitement du choix utilisateur
        handle_user_choice
    done
}

##############################
#    FONCTIONS ADMIN         #
##############################

# Affichage du changelog
show_changelog() {
    echo -e "\e[1;36m=== CHANGELOG DU SCRIPT ===\e[0m\n"
    
    if [[ -f "$SCRIPT_DIR/CHANGELOG.md" ]]; then
        # Afficher les 30 premières lignes du changelog
        head -n 30 "$SCRIPT_DIR/CHANGELOG.md" | while IFS= read -r line; do
            if [[ "$line" =~ ^#[[:space:]] ]]; then
                # Titre principal en cyan
                echo -e "\e[1;36m$line\e[0m"
            elif [[ "$line" =~ ^##[[:space:]] ]]; then
                # Sous-titre en jaune
                echo -e "\e[1;33m$line\e[0m"
            elif [[ "$line" =~ ^-[[:space:]] ]]; then
                # Éléments de liste en vert
                echo -e "\e[0;32m$line\e[0m"
            else
                # Texte normal
                echo -e "\e[0;37m$line\e[0m"
            fi
        done
        
        if [[ $(wc -l < "$SCRIPT_DIR/CHANGELOG.md") -gt 30 ]]; then
            echo -e "\n\e[1;33m... (voir le fichier CHANGELOG.md complet pour plus d'informations)\e[0m"
        fi
    else
        echo -e "\e[1;31m❌ Fichier CHANGELOG.md non trouvé\e[0m"
    fi
}

# Détection de nouvelle version WG-Easy (fonction vide pour compatibilité)
detect_new_wg_easy_version() {
    # Cette fonction est maintenant intégrée dans la logique de display_container_info
    return 0
}

# Menu de configuration auto-update
# Note: Les autres fonctions d'administration système ont été supprimées
# selon les spécifications du menu simplifié