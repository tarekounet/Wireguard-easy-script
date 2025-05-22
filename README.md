📌 Présentation générale
Ce script Bash permet de gérer un serveur WireGuard à l’aide de Docker Compose, avec plusieurs fonctionnalités :
- Création et modification du fichier docker-compose.yml
- Configuration des ports, de l’adresse publique, et du mot de passe
- Démarrage, arrêt et mise à jour du service WireGuard
- Interface utilisateur en ligne de commande avec des couleurs et emojis

🏗️ Structure principale
Voici les éléments clés :
1️⃣ Définition des constantes
SCRIPT_VERSION="1.0.0"
REMOTE_VERSION=$(curl -s https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/version.txt)
UPDATE_URL="https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/config_wg.sh"


- Définit la version actuelle du script
- Vérifie la dernière version disponible sur GitHub
- Stocke l’URL pour les mises à jour du script

2️⃣ Gestion du dossier de configuration
if [[ ! -d "/mnt/wireguard" ]]; then
    mkdir -p "/mnt/wireguard"
fi
DOCKER_COMPOSE_FILE="/mnt/wireguard/docker-compose.yml"


- Vérifie si le dossier /mnt/wireguard existe, sinon il le crée
- Définit le chemin du fichier docker-compose.yml

3️⃣ Fonction configure_values()
Permet de modifier ou créer la configuration WireGuard.
✅ Gestion des interruptions (Ctrl+C)
trap cancel_config SIGINT


Si l’utilisateur interrompt le script (Ctrl+C), la fonction cancel_config est appelée pour restaurer les modifications et afficher un message.
✅ Vérification et sauvegarde du fichier docker-compose.yml
if [[ -f "$DOCKER_COMPOSE_FILE" ]]; then
    cp "$DOCKER_COMPOSE_FILE" "$DOCKER_COMPOSE_FILE.bak"
fi


Si le fichier existe déjà, il est sauvegardé pour permettre une restauration en cas d’annulation.
✅ Création du fichier docker-compose.yml
Si le fichier n’existe pas, le script crée une configuration WireGuard avec :
- Le conteneur Docker wg-easy
- L’adresse IP publique détectée automatiquement (api.ipify.org)
- Les ports 51820 et 51821
- Des variables pour configurer les statistiques et le tri des clients

4️⃣ Modification des valeurs de configuration
Le script interagit avec l’utilisateur pour ajuster :
- L’adresse publique (WG_HOST)
- Les ports UDP et TCP
- Le mot de passe pour l’interface web
✅ Détection automatique de l’IP publique :
AUTO_WG_HOST=$(curl -s https://api.ipify.org)


L’utilisateur peut choisir de l’utiliser ou d’entrer un domaine personnalisé.
✅ Modification des ports :
read -p "Voulez-vous modifier le port VPN ? (o/N) : " MODIFY_UDP_PORT


L’utilisateur peut ajuster les ports UDP et TCP utilisés par le serveur.
✅ Gestion du mot de passe :
- Demande un mot de passe utilisateur sécurisé
- Génère un hash sécurisé via docker run pour stockage dans docker-compose.yml

5️⃣ Menu interactif
Le script affiche un menu coloré avec des emojis pour choisir une action :
echo -e "\e[1;32m1) \e[0m\e[0;37m🛠️  Modifier la configuration\e[0m"
echo -e "\e[1;32m2) \e[0m\e[0;37m🚀 Lancer le service\e[0m"
echo -e "\e[1;32m3) \e[0m\e[0;37m🛑 Arrêter le service\e[0m"
echo -e "\e[1;32m4) \e[0m\e[0;37m🔄 Redémarrer le service\e[0m"


Il permet à l’utilisateur :
- Démarrer ou arrêter WireGuard
- Modifier la configuration
- Mettre à jour WireGuard et le script lui-même

🧐 Résumé
Ce script facilite la gestion de WireGuard via Docker, tout en offrant une interface intuitive et interactive. Il inclut :
- Sécurité : gestion du mot de passe, backup avant modifications
- Ergonomie : messages colorés et emojis pour une meilleure lisibilité
- Automatisation : détection automatique de l’IP publique et gestion simplifiée de Docker
