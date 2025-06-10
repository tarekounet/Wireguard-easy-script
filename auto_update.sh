#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$SCRIPT_DIR/config/auto_update.conf"
LOG_DIR="$SCRIPT_DIR/logs"
UPDATE_LOG="$LOG_DIR/auto_update.log"

# Création du dossier de logs si besoin
[[ ! -d "$LOG_DIR" ]] && mkdir -p "$LOG_DIR"

# Chargement des fonctions nécessaires
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/menu.sh"

# Si le fichier de conf n'existe pas, le créer avec des valeurs par défaut
if [[ ! -f "$CONF" ]]; then
    cat <<EOF > "$CONF"
AUTO_UPDATE_ENABLED=0
AUTO_UPDATE_FREQUENCY="0 3 * * *"
AUTO_UPDATE_TARGET="all"
EOF
    echo "Fichier de configuration auto_update.conf créé avec les valeurs par défaut. Activez l'auto-update via le menu."
    echo "$(date '+%F %T') [AUTO-UPDATE] Fichier de conf créé avec les valeurs par défaut" >> "$UPDATE_LOG"
    exit 0
fi

# Chargement de la configuration utilisateur
source "$CONF"

# Affichage clair de la configuration
echo -e "\e[1;36m--- Configuration de la mise à jour automatique ---\e[0m"
echo -e "  Statut      : \e[1;33m$([[ "$AUTO_UPDATE_ENABLED" == "1" ]] && echo "Activée" || echo "Désactivée")\e[0m"
echo -e "  Fréquence   : \e[1;33m$AUTO_UPDATE_FREQUENCY\e[0m"
echo -e "  Cible       : \e[1;33m$AUTO_UPDATE_TARGET\e[0m"
echo

echo "$(date '+%F %T') [AUTO-UPDATE] Lancement du script (statut: $([[ "$AUTO_UPDATE_ENABLED" == "1" ]] && echo "Activée" || echo "Désactivée"), cible: $AUTO_UPDATE_TARGET)" >> "$UPDATE_LOG"

# Si l'auto-update n'est pas activé, on quitte
if [[ "$AUTO_UPDATE_ENABLED" != "1" ]]; then
    echo "$(date '+%F %T') [AUTO-UPDATE] Auto-update désactivé, arrêt du script" >> "$UPDATE_LOG"
    exit 0
fi

# On se place dans le dossier du projet
cd /home/system/Wireguard-easy-script || exit 1
source ./config_wg.sh

case "$AUTO_UPDATE_TARGET" in
    all)
        echo "$(date '+%F %T') [AUTO-UPDATE] Mise à jour du script et du container" >> "$UPDATE_LOG"
        git pull origin main >> "$UPDATE_LOG" 2>&1
        detect_new_wg_easy_version && [[ -n "$NEW_WG_EASY_VERSION" ]] && {
            echo "$(date '+%F %T') [AUTO-UPDATE] Nouvelle version du container détectée : $NEW_WG_EASY_VERSION" >> "$UPDATE_LOG"
            update_wg_easy_version_only >> "$UPDATE_LOG" 2>&1
        }
        menu_script_update >> "$UPDATE_LOG" 2>&1
        ;;
    container)
        echo "$(date '+%F %T') [AUTO-UPDATE] Mise à jour du container uniquement" >> "$UPDATE_LOG"
        detect_new_wg_easy_version && [[ -n "$NEW_WG_EASY_VERSION" ]] && {
            echo "$(date '+%F %T') [AUTO-UPDATE] Nouvelle version du container détectée : $NEW_WG_EASY_VERSION" >> "$UPDATE_LOG"
            update_wg_easy_version_only >> "$UPDATE_LOG" 2>&1
        }
        ;;
    script)
        echo "$(date '+%F %T') [AUTO-UPDATE] Mise à jour du script uniquement" >> "$UPDATE_LOG"
        git pull origin main >> "$UPDATE_LOG" 2>&1
        menu_script_update >> "$UPDATE_LOG" 2>&1
        ;;
    *)
        echo "$(date '+%F %T') [AUTO-UPDATE] Cible de mise à jour inconnue : $AUTO_UPDATE_TARGET" >> "$UPDATE_LOG"
        exit 1
        ;;
esac

echo "$(date '+%F %T') [AUTO-UPDATE] Fin du script" >> "$UPDATE_LOG"

if [[ $EUID -eq 0 ]]; then
    chown "$SUDO_USER":"$SUDO_USER" "auto_update.sh" 2>/dev/null || chown "$USER":"$USER" "auto_update.sh"
fi
chmod u+rwX "auto_update.sh"