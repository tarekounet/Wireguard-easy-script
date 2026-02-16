#!/bin/bash

##############################
#   VARIABLES GÉNÉRALES      #
##############################

GITHUB_USER="tarekounet"
GITHUB_REPO="Wireguard-easy-script"
BRANCH="main"
VERSION_FILE="version.txt"
CHANGELOG_FILE="CHANGELOG.md"
# Utilisation du HOME de l'utilisateur actuel
USER_HOME="$HOME"

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

export GITHUB_USER
export GITHUB_REPO
export BRANCH

# Version par défaut pour fallback
readonly DEFAULT_VERSION="0.31.0"

##############################
#   FONCTIONS UTILITAIRES    #
##############################

# Fonction pour mettre à jour les modules depuis GitHub
update_modules_from_github() {
    echo "🔄 Mise à jour des modules depuis GitHub..."
    for mod in utils docker menu ; do
        echo "Mise à jour de lib/$mod.sh depuis GitHub ($BRANCH)..."
        if curl -fsSL --connect-timeout 10 --max-time 20 -o "lib/$mod.sh" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/lib/$mod.sh" 2>/dev/null; then
            chmod +x "lib/$mod.sh"
            echo "✅ Module lib/$mod.sh mis à jour avec succès"
        else
            echo "⚠️  Échec de la mise à jour de lib/$mod.sh"
            if [[ ! -f "lib/$mod.sh" ]]; then
                echo "❌ Module manquant et impossible à télécharger - Arrêt du script"
                echo "💡 Vérifiez votre connexion réseau et réessayez"
                exit 1
            else
                echo "📱 Utilisation de la version locale existante de lib/$mod.sh"
            fi
        fi
    done
}

# Fonction pour récupérer ou créer le fichier version.txt
get_or_create_version() {
    if [[ ! -f "$VERSION_FILE" ]]; then
        echo "📥 Fichier version.txt manquant, récupération depuis GitHub..."
        
        # Try with curl first
        REMOTE_VERSION=""
        if command -v curl >/dev/null 2>&1; then
            REMOTE_VERSION=$(curl -fsSL --connect-timeout 3 --max-time 10 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/version.txt" 2>/dev/null | head -n1 | tr -d '\n\r ' || echo "")
        fi
        
        # Fallback with wget
        if [[ -z "$REMOTE_VERSION" ]] && command -v wget >/dev/null 2>&1; then
            REMOTE_VERSION=$(wget -qO- --timeout=5 --tries=1 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/version.txt" 2>/dev/null | head -n1 | tr -d '\n\r ' || echo "")
        fi
        
        if [[ -n "$REMOTE_VERSION" ]]; then
            echo "$REMOTE_VERSION" > "$VERSION_FILE"
            echo "✓ Fichier version.txt créé avec la version : $REMOTE_VERSION"
            echo "$REMOTE_VERSION"
            return
        fi
        
        # Si échec, créer avec la version par défaut
        echo "$DEFAULT_VERSION" > "$VERSION_FILE"
        echo "⚠️  Impossible de récupérer la version depuis GitHub, utilisation de la version par défaut : $DEFAULT_VERSION"
        echo "$DEFAULT_VERSION"
    else
        VERSION_FROM_FILE=$(cat "$VERSION_FILE" 2>/dev/null | head -n1 | tr -d '\n\r ')
        if [[ -n "$VERSION_FROM_FILE" ]]; then
            echo "$VERSION_FROM_FILE"
        else
            echo "$DEFAULT_VERSION" > "$VERSION_FILE"
            echo "⚠️  Fichier version.txt vide, recréation avec version par défaut : $DEFAULT_VERSION"
            echo "$DEFAULT_VERSION"
        fi
    fi
}

# Fonction pour récupérer le fichier CHANGELOG.md
get_or_create_changelog() {
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        echo "📥 Fichier CHANGELOG.md manquant, récupération depuis GitHub..."
        if curl -fsSL --connect-timeout 10 --max-time 20 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/CHANGELOG.md" -o "$CHANGELOG_FILE" 2>/dev/null; then
            if [[ -f "$CHANGELOG_FILE" && -s "$CHANGELOG_FILE" ]]; then
                echo "✓ Fichier CHANGELOG.md récupéré avec succès depuis GitHub"
                return 0
            fi
        fi
        # Si échec, ne pas créer de fichier
        echo "⚠️  Changelog non disponible (impossible de récupérer depuis GitHub)"
        return 1
    else
        echo "✓ Fichier CHANGELOG.md déjà présent"
        return 0
    fi
}

# Détection de la version du script
SCRIPT_VERSION=$(get_or_create_version)

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
    
    # Vérifier la version du script sur GitHub avec gestion d'erreur robuste
    LATEST_SCRIPT_VERSION=""
    
    # First attempt: Primary URL with short timeout
    if command -v curl >/dev/null 2>&1; then
        LATEST_SCRIPT_VERSION=$(curl -fsSL --connect-timeout 3 --max-time 10 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/version.txt" 2>/dev/null | head -n1 | tr -d '\n\r ' || echo "")
    fi
    
    # Fallback: Try with wget if curl failed
    if [[ -z "$LATEST_SCRIPT_VERSION" ]] && command -v wget >/dev/null 2>&1; then
        LATEST_SCRIPT_VERSION=$(wget -qO- --timeout=5 --tries=1 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/version.txt" 2>/dev/null | head -n1 | tr -d '\n\r ' || echo "")
    fi
    
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
                if curl -fsSL --connect-timeout 10 --max-time 30 -o "$0.tmp" "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/config_wg.sh" 2>/dev/null; then
                    chmod +x "$0.tmp"
                    mv "$0.tmp" "$0"
                    
                    # Mettre à jour le fichier version.txt
                    echo "$LATEST_SCRIPT_VERSION" > "$VERSION_FILE"
                    
                    # Mettre à jour le changelog
                    echo "📥 Mise à jour du changelog..."
                    if curl -fsSL --connect-timeout 10 --max-time 20 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/CHANGELOG.md" -o "$CHANGELOG_FILE.tmp" 2>/dev/null; then
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
                    echo "⚠️  Échec du téléchargement de la mise à jour - Continuons avec la version actuelle"
                    rm -f "$0.tmp" 2>/dev/null
                    echo "📱 Poursuite avec la version locale : $SCRIPT_VERSION"
                fi
            else
                echo "✅ Script à jour (version locale $SCRIPT_VERSION >= version distante $LATEST_SCRIPT_VERSION)"
            fi
        else
            echo "✅ Script à jour (version $SCRIPT_VERSION)"
        fi
    else
        echo "⚠️  Impossible de vérifier la version en ligne - Connexion réseau ou serveur indisponible"
        echo "📱 Continuons avec la version locale : $SCRIPT_VERSION"
    fi
}

# Exécuter la mise à jour automatique seulement si le script est lancé directement
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    auto_update_on_startup "$@"
fi

##############################
#   AUTO-BOOTSTRAP MODULES   #
##############################

# Création des dossiers nécessaires
for dir in lib; do
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
for mod in utils docker menu ; do
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
done
echo "✓ Tous les modules sont chargés"

##############################
#   INITIALISATION DE LA CONF
##############################

# Détermination de la version WG-Easy (logique simplifiée)
WG_EASY_VERSION_DEFAULT="15.1.0"
WG_EASY_VERSION=""

echo "🔍 Détermination de la version WG-Easy..."

# 1. Si docker-compose.yml existe, utiliser sa version (PRIORITÉ)
if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
    WG_EASY_VERSION=$(grep -o 'ghcr.io/wg-easy/wg-easy:[^[:space:]]*' "$DOCKER_COMPOSE_FILE" 2>/dev/null | cut -d: -f3 | head -n1)
    if [[ -n "$WG_EASY_VERSION" ]]; then
        echo "✓ Version depuis docker-compose.yml : $WG_EASY_VERSION"
    fi
fi

# 2. Si pas de version docker-compose, utiliser le fichier local WG_EASY_VERSION
if [[ -z "$WG_EASY_VERSION" && -f "WG_EASY_VERSION" ]]; then
    WG_EASY_VERSION=$(cat "WG_EASY_VERSION" 2>/dev/null | head -n1 | tr -d '\n\r ')
    if [[ -n "$WG_EASY_VERSION" ]]; then
        echo "✓ Version depuis fichier local WG_EASY_VERSION : $WG_EASY_VERSION"
    fi
fi

# 3. Si toujours vide, récupérer depuis GitHub
if [[ -z "$WG_EASY_VERSION" ]]; then
    WG_EASY_VERSION=$(curl -fsSL --connect-timeout 5 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/WG_EASY_VERSION" 2>/dev/null | head -n1 | tr -d '\n\r')
    if [[ -n "$WG_EASY_VERSION" ]]; then
        echo "✓ Version depuis GitHub : $WG_EASY_VERSION"
        # Sauvegarder dans fichier local
        echo "$WG_EASY_VERSION" > "WG_EASY_VERSION"
    fi
fi

# 4. Fallback sur version par défaut
if [[ -z "$WG_EASY_VERSION" ]]; then
    WG_EASY_VERSION="$WG_EASY_VERSION_DEFAULT"
    echo "✗ Utilisation version par défaut : $WG_EASY_VERSION"
    echo "$WG_EASY_VERSION" > "WG_EASY_VERSION"
fi

# Vérification des mises à jour WG-Easy disponibles
echo "� Vérification des mises à jour WG-Easy..."
WG_EASY_LATEST=$(curl -fsSL --connect-timeout 5 "https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$BRANCH/WG_EASY_VERSION" 2>/dev/null | head -n1 | tr -d '\n\r')

if [[ -n "$WG_EASY_LATEST" && "$WG_EASY_LATEST" != "$WG_EASY_VERSION" ]]; then
    echo "🆕 Nouvelle version WG-Easy disponible : $WG_EASY_LATEST (actuelle : $WG_EASY_VERSION)"
    if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
        echo "📥 Mise à jour automatique du docker-compose.yml..."
        cp "$DOCKER_COMPOSE_FILE" "$DOCKER_COMPOSE_FILE.bak.$(date +%Y%m%d_%H%M%S)"
        sed -i "s|image: ghcr.io/wg-easy/wg-easy:.*|image: ghcr.io/wg-easy/wg-easy:$WG_EASY_LATEST|" "$DOCKER_COMPOSE_FILE"
        echo "$WG_EASY_LATEST" > "WG_EASY_VERSION"
        WG_EASY_VERSION="$WG_EASY_LATEST"
        echo "✅ Mis à jour vers la version $WG_EASY_LATEST"
    fi
else
    echo "✅ WG-Easy à jour : $WG_EASY_VERSION"
fi

##############################
#   LANCEMENT DU SCRIPT      #
##############################

# Lancement du menu principal uniquement si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main_menu
fi
