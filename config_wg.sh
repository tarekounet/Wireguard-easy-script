#!/bin/bash

add_script_autostart_to_user() {
    TARGETUSER="$1"
    PROFILE="/home/$TARGETUSER/.bash_profile"
    SCRIPT_PATH="/home/$TARGETUSER/wireguard-script-manager/config_wg.sh"
    if ! grep -q "$SCRIPT_PATH" "$PROFILE" 2>/dev/null; then
        echo '[[ $- == *i* ]] && cd ~/wireguard-script-manager && bash ./config_wg.sh' >> "$PROFILE"
        chown "$TARGETUSER:$TARGETUSER" "$PROFILE"
    fi
}

##############################
#   VARIABLES GÉNÉRALES      #
##############################

GITHUB_USER="tarekounet"
GITHUB_REPO="Wireguard-easy-script"
BRANCH="main"
CONF_FILE="config/wg-easy.conf"
VERSION_FILE="version.txt"
CHANGELOG_FILE="CHANGELOG.md"
SCRIPT_VERSION="0.9.0"  # Version par défaut
SCRIPT_BACKUP="config_wg.sh.bak"
# Détection du bon HOME utilisateur même en sudo/root
if [[ $EUID -eq 0 && -n "$SUDO_USER" ]]; then
    USER_HOME="$(getent passwd $SUDO_USER | cut -d: -f6)"
else
    USER_HOME="$HOME"
fi

# Vérifier plusieurs emplacements possibles pour docker-wireguard
POSSIBLE_DOCKER_DIRS=(
    "$USER_HOME/docker-wireguard"
    "./docker-wireguard"
    "../docker-wireguard"
    "$USER_HOME/wireguard-script-manager/docker-wireguard"
    "docker-wireguard"
)

DOCKER_WG_DIR=""
DOCKER_COMPOSE_FILE=""

# Trouver le bon répertoire docker-wireguard
for dir in "${POSSIBLE_DOCKER_DIRS[@]}"; do
    if [[ -d "$dir" && -f "$dir/docker-compose.yml" ]]; then
        DOCKER_WG_DIR="$dir"
        DOCKER_COMPOSE_FILE="$DOCKER_WG_DIR/docker-compose.yml"
        echo "✓ Répertoire docker-wireguard trouvé : $DOCKER_WG_DIR"
        break
    fi
done

# Si aucun répertoire trouvé, utiliser le chemin par défaut
if [[ -z "$DOCKER_WG_DIR" ]]; then
    DOCKER_WG_DIR="$USER_HOME/docker-wireguard"
    DOCKER_COMPOSE_FILE="$DOCKER_WG_DIR/docker-compose.yml"
    echo "✗ Aucun répertoire docker-wireguard trouvé, utilisation du chemin par défaut : $DOCKER_WG_DIR"
fi

WG_CONF_DIR="$DOCKER_WG_DIR/config"
SCRIPT_BASE_VERSION_INIT="0.9.0"

export GITHUB_USER
export GITHUB_REPO
export BRANCH

# Fonction pour récupérer ou créer le fichier version.txt
get_or_create_version() {
    if [[ ! -f "$VERSION_FILE" ]]; then
        echo "📥 Fichier version.txt manquant, récupération depuis GitHub..."
        if REMOTE_VERSION=$(curl -fsSL --connect-timeout 5 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/version.txt" 2>/dev/null | head -n1 | tr -d '\n\r '); then
            if [[ -n "$REMOTE_VERSION" ]]; then
                echo "$REMOTE_VERSION" > "$VERSION_FILE"
                echo "✓ Fichier version.txt créé avec la version : $REMOTE_VERSION"
                echo "$REMOTE_VERSION"
                return
            fi
        fi
        # Si échec, créer avec la version par défaut
        echo "$SCRIPT_BASE_VERSION_INIT" > "$VERSION_FILE"
        echo "✗ Impossible de récupérer la version depuis GitHub, utilisation de la version par défaut : $SCRIPT_BASE_VERSION_INIT"
        echo "$SCRIPT_BASE_VERSION_INIT"
    else
        VERSION_FROM_FILE=$(cat "$VERSION_FILE" 2>/dev/null | head -n1 | tr -d '\n\r ')
        if [[ -n "$VERSION_FROM_FILE" ]]; then
            echo "$VERSION_FROM_FILE"
        else
            echo "$SCRIPT_BASE_VERSION_INIT" > "$VERSION_FILE"
            echo "$SCRIPT_BASE_VERSION_INIT"
        fi
    fi
}

# Fonction pour récupérer le fichier CHANGELOG.md
get_or_create_changelog() {
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        echo "📥 Fichier CHANGELOG.md manquant, récupération depuis GitHub..."
        if curl -fsSL --connect-timeout 10 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/CHANGELOG.md" -o "$CHANGELOG_FILE" 2>/dev/null; then
            if [[ -f "$CHANGELOG_FILE" && -s "$CHANGELOG_FILE" ]]; then
                echo "✓ Fichier CHANGELOG.md récupéré avec succès depuis GitHub"
                return 0
            fi
        fi
        # Si échec, ne pas créer de fichier
        echo "✗ Changelog non disponible (impossible de récupérer depuis GitHub)"
        return 1
    else
        echo "✓ Fichier CHANGELOG.md déjà présent"
        return 0
    fi
}

# Détection de la version du script
SCRIPT_VERSION=$(get_or_create_version)
SCRIPT_BASE_VERSION_INIT="$SCRIPT_VERSION"

# Récupération ou création du changelog
get_or_create_changelog

echo "Version du script : $SCRIPT_VERSION"

##############################
#   MISE À JOUR AUTOMATIQUE  #
##############################

# Fonction de comparaison de versions (format: X.Y.Z)
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    # Normaliser les versions (enlever les préfixes 'v' éventuels)
    version1="${version1#v}"
    version2="${version2#v}"
    
    # Comparer les versions
    printf '%s\n%s' "$version1" "$version2" | sort -V | head -n1
}

# Fonction de mise à jour automatique
auto_update_on_startup() {
    echo "🔄 Vérification des mises à jour..."
    
    # Vérifier la version du script sur GitHub
    LATEST_SCRIPT_VERSION=$(curl -fsSL --connect-timeout 5 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/version.txt" 2>/dev/null | head -n1 | tr -d '\n\r ')
    
    if [[ -n "$LATEST_SCRIPT_VERSION" ]]; then
        # Comparer les versions - ne mettre à jour que si la version distante est plus récente
        if [[ "$LATEST_SCRIPT_VERSION" != "$SCRIPT_VERSION" ]]; then
            OLDEST_VERSION=$(compare_versions "$SCRIPT_VERSION" "$LATEST_SCRIPT_VERSION")
            if [[ "$OLDEST_VERSION" == "$SCRIPT_VERSION" ]]; then
                echo "🆕 Nouvelle version du script disponible : $LATEST_SCRIPT_VERSION (actuelle : $SCRIPT_VERSION)"
                echo "📥 Mise à jour automatique en cours..."
                
                # Sauvegarder le script actuel
                cp "$0" "${0}.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null
                
                # Télécharger la nouvelle version
                if curl -fsSL -o "$0.tmp" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/config_wg.sh"; then
                    chmod +x "$0.tmp"
                    mv "$0.tmp" "$0"
                    
                    # Mettre à jour le fichier version.txt
                    echo "$LATEST_SCRIPT_VERSION" > "$VERSION_FILE"
                    
                    # Mettre à jour le changelog
                    echo "📥 Mise à jour du changelog..."
                    if curl -fsSL --connect-timeout 10 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/CHANGELOG.md" -o "$CHANGELOG_FILE.tmp" 2>/dev/null; then
                        if [[ -f "$CHANGELOG_FILE.tmp" && -s "$CHANGELOG_FILE.tmp" ]]; then
                            mv "$CHANGELOG_FILE.tmp" "$CHANGELOG_FILE"
                            echo "✅ Changelog mis à jour"
                        else
                            rm -f "$CHANGELOG_FILE.tmp" 2>/dev/null
                            echo "⚠️  Changelog inchangé (fichier vide ou invalide)"
                        fi
                    else
                        echo "⚠️  Impossible de mettre à jour le changelog"
                    fi
                    
                    # Mettre à jour les modules aussi
                    echo "🔄 Mise à jour des modules suite à la nouvelle version..."
                    update_modules_from_github
                    
                    echo "✅ Script mis à jour vers la version $LATEST_SCRIPT_VERSION"
                    echo "🔄 Redémarrage du script avec la nouvelle version..."
                    
                    # Relancer le script avec la nouvelle version
                    exec bash "$0" "$@"
                else
                    echo "❌ Échec de la mise à jour du script"
                    rm -f "$0.tmp" 2>/dev/null
                fi
            else
                echo "✅ Script à jour (version locale $SCRIPT_VERSION >= version distante $LATEST_SCRIPT_VERSION)"
            fi
        else
            echo "✅ Script à jour (version $SCRIPT_VERSION)"
        fi
    else
        echo "⚠️  Impossible de vérifier la version distante"
        echo "✅ Script version locale : $SCRIPT_VERSION"
    fi
}

# Exécuter la mise à jour automatique seulement si le script est lancé directement
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    auto_update_on_startup "$@"
fi

# Fonction pour mettre à jour les modules depuis GitHub
update_modules_from_github() {
    echo "🔄 Mise à jour des modules depuis GitHub..."
    for mod in utils conf docker menu ; do
        echo "Mise à jour de lib/$mod.sh depuis GitHub ($BRANCH)..."
        if curl -fsSL -o "lib/$mod.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/lib/$mod.sh"; then
            chmod +x "lib/$mod.sh"
            echo "✅ Module lib/$mod.sh mis à jour avec succès"
        else
            echo "❌ Échec de la mise à jour de lib/$mod.sh"
            if [[ ! -f "lib/$mod.sh" ]]; then
                echo "❌ Module manquant et impossible à télécharger"
                exit 1
            else
                echo "⚠️  Utilisation de la version locale existante"
            fi
        fi
        # Pause de 1 seconde entre chaque téléchargement
        sleep 1
    done
}

# Fonction pour mettre à jour le changelog indépendamment
update_changelog_from_github() {
    echo "🔄 Vérification du changelog sur GitHub..."
    
    if curl -fsSL --connect-timeout 10 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/CHANGELOG.md" -o "$CHANGELOG_FILE.tmp" 2>/dev/null; then
        if [[ -f "$CHANGELOG_FILE.tmp" && -s "$CHANGELOG_FILE.tmp" ]]; then
            # Comparer les contenus si le fichier local existe
            if [[ -f "$CHANGELOG_FILE" ]]; then
                if ! cmp -s "$CHANGELOG_FILE" "$CHANGELOG_FILE.tmp"; then
                    # Créer une sauvegarde avant de remplacer
                    cp "$CHANGELOG_FILE" "$CHANGELOG_FILE.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null
                    mv "$CHANGELOG_FILE.tmp" "$CHANGELOG_FILE"
                    echo "✅ Changelog mis à jour depuis GitHub"
                    return 0
                else
                    rm -f "$CHANGELOG_FILE.tmp"
                    echo "✅ Changelog déjà à jour"
                    return 0
                fi
            else
                mv "$CHANGELOG_FILE.tmp" "$CHANGELOG_FILE"
                echo "✅ Changelog récupéré depuis GitHub"
                return 0
            fi
        else
            rm -f "$CHANGELOG_FILE.tmp" 2>/dev/null
            echo "⚠️  Fichier changelog distant vide ou invalide"
            return 1
        fi
    else
        echo "❌ Impossible de récupérer le changelog depuis GitHub"
        return 1
    fi
}

##############################
#   AUTO-BOOTSTRAP MODULES   #
##############################

# Création des dossiers nécessaires
for dir in lib config; do
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        echo "Dossier créé : $dir/"
    fi
    if [[ ! -w "$dir" || ! -r "$dir" ]]; then
        echo "Erreur : le dossier '$dir/' n'est pas accessible en lecture/écriture."
        exit 1
    fi
done

# Vérifier si les modules existent, sinon les télécharger une première fois
MODULES_MISSING=false
for mod in utils conf docker menu ; do
    if [[ ! -f "lib/$mod.sh" ]]; then
        echo "⚠️  Module lib/$mod.sh manquant"
        MODULES_MISSING=true
    fi
done

# Si des modules manquent, les télécharger
if [[ "$MODULES_MISSING" == "true" ]]; then
    echo "📥 Téléchargement des modules manquants..."
    update_modules_from_github
fi

# Chargement des modules
echo "Chargement des modules..."
for f in lib/*.sh; do
    if [[ -f "$f" ]]; then
        echo "Chargement de $f"
        source "$f"
    else
        echo "Erreur : Module $f introuvable après téléchargement"
        exit 1
    fi
    # Pause de 1 seconde entre chaque chargement de module
    sleep 1
done
echo "✓ Tous les modules sont chargés"

##############################
#   INITIALISATION DE LA CONF
##############################

# 1. Récupération depuis GitHub
WG_EASY_VERSION_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/WG_EASY_VERSION"
echo "Récupération de la version WG-Easy depuis GitHub..."

# Essayer de récupérer la version depuis GitHub
WG_EASY_VERSION=$(curl -fsSL --connect-timeout 10 "$WG_EASY_VERSION_URL" 2>/dev/null | head -n1 | tr -d '\n\r')

# Si échec, utiliser une version par défaut
if [[ -z "$WG_EASY_VERSION" ]]; then
    WG_EASY_VERSION="15.1.0"  # Version par défaut récente
    echo "✗ Impossible de récupérer la version depuis GitHub, utilisation de la version par défaut : $WG_EASY_VERSION"
else
    echo "✓ Version récupérée depuis GitHub : $WG_EASY_VERSION"
fi

# Vérification explicite de la version locale
WG_EASY_VERSION_LOCAL_FILE="WG_EASY_VERSION"
WG_EASY_VERSION_LOCAL=""

# D'abord, essayer de lire le fichier WG_EASY_VERSION local (dans le répertoire du script)
echo "Lecture du fichier WG_EASY_VERSION local..."
if [[ -f "$WG_EASY_VERSION_LOCAL_FILE" && -s "$WG_EASY_VERSION_LOCAL_FILE" ]]; then
    WG_EASY_VERSION_LOCAL=$(cat "$WG_EASY_VERSION_LOCAL_FILE" 2>/dev/null | head -n1 | tr -d '\n\r ')
    if [[ -n "$WG_EASY_VERSION_LOCAL" && "$WG_EASY_VERSION_LOCAL" != "" ]]; then
        echo "✓ Version locale trouvée dans WG_EASY_VERSION : $WG_EASY_VERSION_LOCAL"
    else
        echo "✗ Fichier WG_EASY_VERSION vide"
        WG_EASY_VERSION_LOCAL=""
    fi
else
    echo "✗ Fichier WG_EASY_VERSION non trouvé ou vide"
fi

# Si pas de version locale trouvée, créer le fichier avec la version GitHub
if [[ -z "$WG_EASY_VERSION_LOCAL" ]]; then
    echo "$WG_EASY_VERSION" > "$WG_EASY_VERSION_LOCAL_FILE"
    WG_EASY_VERSION_LOCAL="$WG_EASY_VERSION"
    echo "✓ Fichier WG_EASY_VERSION créé avec la version $WG_EASY_VERSION"
fi

# Si docker-compose.yml existe, extraire la version actuelle
echo "Vérification du fichier docker-compose.yml..."
echo "Chemin recherché : $DOCKER_COMPOSE_FILE"

if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
    echo "✓ Fichier docker-compose.yml trouvé dans $DOCKER_WG_DIR"
    CURRENT_VERSION_IN_COMPOSE=$(grep -o 'ghcr.io/wg-easy/wg-easy:[^[:space:]]*' "$DOCKER_COMPOSE_FILE" 2>/dev/null | cut -d: -f3 | head -n1)
    if [[ -n "$CURRENT_VERSION_IN_COMPOSE" ]]; then
        echo "Version actuelle dans docker-compose.yml : $CURRENT_VERSION_IN_COMPOSE"
        # Utiliser la version du docker-compose comme référence locale (priorité sur le fichier WG_EASY_VERSION)
        WG_EASY_VERSION_LOCAL="$CURRENT_VERSION_IN_COMPOSE"
    else
        echo "✗ Impossible d'extraire la version depuis docker-compose.yml"
        echo "→ Utilisation de la version du fichier WG_EASY_VERSION : $WG_EASY_VERSION_LOCAL"
    fi
else
    echo "✗ Fichier docker-compose.yml non trouvé"
    echo "→ Utilisation de la version du fichier WG_EASY_VERSION : $WG_EASY_VERSION_LOCAL"
    echo "✗ Emplacements vérifiés :"
    for dir in "${POSSIBLE_DOCKER_DIRS[@]}"; do
        echo "   - $dir/docker-compose.yml"
    done
fi

# Vérification et comparaison après détection du fichier local
echo "=== DIAGNOSTIC COMPLET ==="
echo "Répertoire de travail : $(pwd)"
echo "Répertoire docker-wireguard : $DOCKER_WG_DIR"
echo "Fichier version.txt : $VERSION_FILE (existe: $(test -f "$VERSION_FILE" && echo "OUI" || echo "NON"))"
echo "Fichier WG_EASY_VERSION : $WG_EASY_VERSION_LOCAL_FILE (existe: $(test -f "$WG_EASY_VERSION_LOCAL_FILE" && echo "OUI" || echo "NON"))"
echo "Fichier docker-compose : $DOCKER_COMPOSE_FILE (existe: $(test -f "$DOCKER_COMPOSE_FILE" && echo "OUI" || echo "NON"))"
echo "=========================="

echo "=== RÉSUMÉ DES VERSIONS ==="
echo "Version GitHub : ${WG_EASY_VERSION:-VIDE}"
echo "Version locale : ${WG_EASY_VERSION_LOCAL:-VIDE}"
echo "Version script : ${SCRIPT_VERSION:-VIDE}"
echo "=========================="

if [[ "$WG_EASY_VERSION_LOCAL" != "$WG_EASY_VERSION" && "$WG_EASY_VERSION" != "inconnu" && -n "$WG_EASY_VERSION_LOCAL" && "$WG_EASY_VERSION_LOCAL" != "inconnu" ]]; then
    echo -e "🆕 Nouvelle version Wireguard Easy disponible : $WG_EASY_VERSION (actuelle : $WG_EASY_VERSION_LOCAL)"
    echo -e "📥 Mise à jour automatique du docker-compose.yml..."
    
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        # Sauvegarder le fichier avant modification
        cp "$DOCKER_COMPOSE_FILE" "$DOCKER_COMPOSE_FILE.bak.$(date +%Y%m%d_%H%M%S)"
        sed -i "s|image: ghcr.io/wg-easy/wg-easy:.*|image: ghcr.io/wg-easy/wg-easy:$WG_EASY_VERSION|" "$DOCKER_COMPOSE_FILE"
        # Mettre à jour le fichier de version locale
        echo "$WG_EASY_VERSION" > "$WG_EASY_VERSION_LOCAL_FILE"
        echo -e "✅ Docker-compose.yml mis à jour automatiquement vers la version $WG_EASY_VERSION"
        echo -e "💾 Sauvegarde créée avec horodatage"
    else
        echo -e "❌ Le fichier docker-compose.yml est introuvable dans $DOCKER_COMPOSE_FILE"
    fi
elif [[ "$WG_EASY_VERSION_LOCAL" == "$WG_EASY_VERSION" ]]; then
    echo -e "✅ Votre version Wireguard Easy est à jour : $WG_EASY_VERSION"
elif [[ -z "$WG_EASY_VERSION_LOCAL" || "$WG_EASY_VERSION_LOCAL" == "inconnu" ]]; then
    echo -e "⚠️  Impossible de déterminer la version actuelle. Fichier docker-compose.yml introuvable."
    echo -e "📝 Assurez-vous que Wireguard Easy est installé et que le fichier docker-compose.yml existe."
fi

# 2. Création du fichier de conf (si besoin)
if [[ ! -f "$CONF_FILE" ]]; then
    msg_warn "Le fichier de configuration n'existe pas. Création en cours..."
    set_tech_password
    EXPECTED_HASH="$(get_conf_value "EXPECTED_HASH")"
    HASH_SALT="$(get_conf_value "HASH_SALT")"
    cat > "$CONF_FILE" <<EOF
EXPECTED_HASH="$EXPECTED_HASH"
HASH_SALT="$HASH_SALT"
WG_EASY_VERSION="$WG_EASY_VERSION"
EOF
    msg_success "Fichier de configuration créé avec succès."
fi

# 3. Mise à jour de la version dans la conf à chaque lancement
set_conf_value "WG_EASY_VERSION" "$WG_EASY_VERSION"

# Vérification du mot de passe technique uniquement si le hash est encore vide
EXPECTED_HASH=$(get_conf_value "EXPECTED_HASH")
if [[ -z "$EXPECTED_HASH" ]]; then
    msg_warn "Aucun mot de passe technique enregistré. Veuillez en définir un."
    set_tech_password
fi

##############################
#   LANCEMENT DU SCRIPT      #
##############################

# Lancement du menu principal uniquement si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main_menu
fi