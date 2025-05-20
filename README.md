# Wireguard-easy-script

## 📝 **Présentation générale**
Ce script Bash permet de gérer facilement l’installation, la configuration, la mise à jour et la gestion du service **Wireguard** via Docker Compose.  
Il propose un menu interactif en couleur, gère la création et la modification du fichier `docker-compose.yml`, et offre des options avancées comme la réinitialisation ou la mise à jour automatique du script.

---

## 🏁 **Initialisation**
- **Détection de la version locale et distante**  
  ```bash
  SCRIPT_VERSION="1.0.1"
  REMOTE_VERSION=$(curl -s https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/version.txt)
  ```
  🔎 Vérifie si une nouvelle version du script est disponible sur GitHub.

- **Définition du chemin de configuration**  
  ```bash
  if [[ ! -d "/mnt/wireguard" ]]; then
      mkdir -p "/mnt/wireguard"
  fi
  DOCKER_COMPOSE_FILE="/mnt/wireguard/docker-compose.yml"
  ```
  📁 Crée le dossier de configuration si besoin.

---

## ⚙️ **Fonction principale : `configure_values`**
- **Gestion de l’annulation**  
  ⛔️ Permet d’annuler la configuration à tout moment (Ctrl+C ou Échap), restaure l’état précédent si besoin.

- **Sauvegarde et création du fichier de configuration**  
  💾 Sauvegarde le fichier existant, ou crée un nouveau fichier `docker-compose.yml` avec les paramètres par défaut si absent.

- **Modification interactive des paramètres**  
  - 🌐 **Adresse publique** : Détection automatique de l’IP publique, possibilité de la modifier.
  - 🔌 **Ports** : Modification des ports UDP (VPN) et TCP (interface web).
  - 🔒 **Mot de passe** : Saisie et confirmation du mot de passe d’administration, hashé via le conteneur Docker.

- **Application des modifications**  
  🛠️ Utilise `sed` pour remplacer les valeurs dans le fichier `docker-compose.yml`.

- **Nettoyage**  
  🧹 Supprime la sauvegarde après modification réussie.

---

## 🖥️ **Menu principal interactif**
- **Affichage dynamique**  
  - 🎉 Message d’accueil, version du script, état du conteneur Wireguard (en cours, arrêté, créé, erreur…)
  - 📄 Affiche les informations actuelles de la configuration (adresse IP, ports, mot de passe défini ou non).

- **Choix utilisateur**  
  Propose différentes actions selon la présence du fichier de configuration :
  1. 🛠️ Modifier la configuration
  2. 🚀 Lancer le service
  3. 🛑 Arrêter le service
  4. 🔄 Redémarrer le service
  5. ⬆️ Mettre à jour Wireguard (image Docker)
  6. ♻️ Réinitialiser (avec mot de passe technique)
  7. ❌ Quitter le script
  8. ⬆️ Mettre à jour le script lui-même

---

## 🔄 **Gestion des actions**
- **Modification** : Relance la fonction de configuration.
- **Démarrage/Arrêt/Redémarrage** : Utilise `docker compose` pour gérer le conteneur.
- **Mise à jour** : Met à jour l’image Docker et relance le service.
- **Réinitialisation** : Demande un mot de passe technique, supprime la config et le conteneur.
- **Mise à jour du script** : Télécharge la dernière version depuis GitHub et remplace le script courant.

---

## 🛡️ **Sécurité**
- **Mot de passe technique** pour la réinitialisation (hashé SHA-512).
- **Gestion des erreurs et annulation** à chaque étape critique.

---

## 🧑‍💻 **Expérience utilisateur**
- **Interface colorée et claire** avec des icônes pour chaque action.
- **Messages explicites** pour guider l’utilisateur à chaque étape.
- **Pause** après chaque action pour permettre la lecture des messages.

---

### Résumé visuel

| Icône | Fonction                                 |
|-------|------------------------------------------|
| 📝    | Présentation générale                    |
| 🏁    | Initialisation                           |
| ⚙️    | Configuration interactive                |
| 🖥️    | Menu principal                           |
| 🚀    | Lancer le service                        |
| 🛑    | Arrêter le service                       |
| 🔄    | Redémarrer le service                    |
| ⬆️    | Mettre à jour Wireguard ou le script     |
| ♻️    | Réinitialiser                            |
| ❌    | Quitter                                  |
| 🔒    | Gestion du mot de passe                  |
| 🛡️    | Sécurité et annulation                   |

---

N’hésite pas à demander une explication détaillée d’une section précise ou un schéma !
## Utilisation
Exemple de commandes ou d’utilisation.

## Contribuer
Tarekounet

## Licence
GPL-3.0 license