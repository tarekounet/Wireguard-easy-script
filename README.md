# Wireguard Easy Script - Documentation

## 📋 Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Scripts principaux](#scripts-principaux)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Fonctionnalités](#fonctionnalités)
- [Configuration](#configuration)
- [Dépannage](#dépannage)
- [Contribution](#contribution)

## 🎯 Vue d'ensemble

**Wireguard Easy Script** est une suite d'outils d'administration pour simplifier la gestion de serveurs WireGuard via une interface en ligne de commande intuitive. Le projet comprend deux scripts principaux complémentaires :

- **`admin_menu.sh`** : Menu d'administration technique avancé
- **`config_wg.sh`** : Configuration et initialisation du système WireGuard

## 🔧 Scripts principaux

### 📊 admin_menu.sh

Menu d'administration technique avancé pour la gestion complète de l'environnement WireGuard.

**Fonctionnalités principales :**
- 🔐 Gestion des utilisateurs et accès
- 🐳 Administration Docker et conteneurs
- 🛡️ Monitoring et diagnostics système
- 🔄 Mise à jour automatique
- 🧹 Maintenance et nettoyage système
- 📈 Surveillance des performances

**Prérequis :**
- Droits root/sudo
- Docker installé (installation automatique si absent)
- Connexion internet pour les mises à jour

### ⚙️ config_wg.sh

Script de configuration et d'initialisation pour l'environnement WireGuard.

**Fonctionnalités principales :**
- 📥 Téléchargement et mise à jour des modules
- 🔄 Gestion des versions (script + WG-Easy)
- 📋 Configuration automatique des chemins
- 🔍 Détection automatique de l'environnement Docker
- 📝 Gestion du changelog et versioning

## 🚀 Installation

### Installation automatique (recommandée)

Le script principal **se configure automatiquement lors de la création d'un utilisateur WireGuard**. Aucune installation manuelle n'est requise pour l'utilisation standard.

```bash
# Le script s'installe et se configure automatiquement
# lors de la première utilisation ou création d'utilisateur
```

### Installation manuelle du menu d'administration

Pour accéder au **menu d'administration avancé**, installation manuelle uniquement :

```bash
# Télécharger le menu d'administration
wget https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/admin_menu.sh

# Permissions d'exécution
chmod +x admin_menu.sh

# Lancer le menu d'administration (nécessite sudo)
sudo ./admin_menu.sh
```

## Installation manuelle

Téléchargez le script principal et le dossier de modules :

```bash
wget https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/admin_menu.sh
mkdir -p lib_admin
for f in ssh.sh user_management.sh power.sh user.sh network.sh maintenance.sh docker.sh utils.sh; do \
  wget https://raw.githubusercontent.com/tarekounet/Wireguard-easy-script/main/lib_admin/$f -O lib_admin/$f; \
done
```

### Installation complète depuis le repository

```bash
# Cloner le repository complet (développeurs/contributeurs)
git clone https://github.com/tarekounet/Wireguard-easy-script.git
cd Wireguard-easy-script

# Rendre les scripts exécutables
chmod +x admin_menu.sh config_wg.sh

# Lancer l'administration
sudo ./admin_menu.sh
```

## 📚 Utilisation

### Lancement du menu d'administration

```bash
sudo ./admin_menu.sh
```

**Menus disponibles :**
1. **👤 Gestion des utilisateurs** - Création, suppression, modification des accès
2. **🐳 Administration Docker** - Gestion des conteneurs WireGuard
3. **🛡️ Sécurité** - Configuration firewall et certificats
4. **📊 Monitoring** - Surveillance système et réseau
5. **🧹 Maintenance** - Nettoyage et optimisation
6. **🔄 Mise à jour** - Updates automatiques et manuelles

### Configuration initiale

```bash
# Le script config_wg.sh est appelé automatiquement
# Ou lancé manuellement pour la configuration
./config_wg.sh
```

## ⚡ Fonctionnalités

### 🔄 Mises à jour automatiques

- **Auto-update** : Vérification automatique des nouvelles versions
- **Modules** : Mise à jour des bibliothèques depuis GitHub
- **WG-Easy** : Surveillance des versions du conteneur WireGuard
- **Rollback** : Sauvegarde automatique avant mise à jour

### 🎨 Interface utilisateur

- **Couleurs** : Interface colorée pour une meilleure lisibilité
- **Navigation** : Menus intuitifs avec navigation par touches
- **Validation** : Contrôles de saisie et confirmations
- **Messages** : Feedback détaillé des opérations

### 🛡️ Sécurité

- **Permissions** : Vérification des droits root
- **Validation** : Contrôle des entrées utilisateur
- **Backup** : Sauvegarde automatique des configurations
- **Logs** : Journalisation des actions administratives

## 📁 Structure du projet

```
Wireguard-easy-script/
├── admin_menu.sh           # Menu principal d'administration
├── config_wg.sh           # Configuration et initialisation
├── lib/                   # Modules et bibliothèques
│   ├── utils.sh          # Fonctions utilitaires
│   ├── docker.sh         # Gestion Docker
│   └── menu.sh           # Interface utilisateur
├── version.txt           # Version actuelle
├── WG_EASY_VERSION      # Version WG-Easy
├── CHANGELOG.md         # Historique des modifications
└── README.md           # Documentation
```

## ⚙️ Configuration

### Variables d'environnement

Le script `config_wg.sh` configure automatiquement :

```bash
GITHUB_USER="tarekounet"
GITHUB_REPO="Wireguard-easy-script"
BRANCH="main"
USER_HOME="$HOME"
DOCKER_WG_DIR="$HOME/docker-wireguard"
```

### Chemins de recherche Docker

Le script recherche automatiquement dans :
- `$HOME/docker-wireguard`
- `./docker-wireguard`
- `../docker-wireguard`
- `$HOME/wireguard-script-manager/docker-wireguard`

### Fichiers de configuration

- **docker-compose.yml** : Configuration Docker WireGuard
- **version.txt** : Version du script
- **WG_EASY_VERSION** : Version du conteneur WG-Easy

## 🔧 Dépannage

### Problèmes courants

**Erreur de permissions :**
```bash
# Solution
sudo ./admin_menu.sh
```

**Docker non installé :**
```bash
# Installation automatique via le script ou manuelle
curl -fsSL https://get.docker.com | sh
```

**Modules manquants :**
```bash
# Mise à jour forcée des modules
./config_wg.sh
```

**Problème de connexion GitHub :**
```bash
# Vérifier la connectivité
curl -I https://github.com
```

### Logs et diagnostic

```bash
# Vérifier les logs Docker
docker logs wg-easy

# Status des conteneurs
docker ps -a

# Espace disque
df -h
```

## 🤝 Contribution

### Comment contribuer

1. **Fork** le repository
2. **Clone** votre fork
3. **Créer** une branche pour votre fonctionnalité
4. **Commiter** vos changements
5. **Push** vers votre fork
6. **Créer** une Pull Request

### Standards de code

- **Bash** : Respect des bonnes pratiques
- **Commentaires** : Code documenté en français
- **Variables** : Nommage en MAJUSCULES pour les constantes
- **Fonctions** : Nommage en snake_case
- **Tests** : Validation avant soumission

### Issues et support

- **GitHub Issues** : Rapporter les bugs
- **Discussions** : Questions et suggestions
- **Wiki** : Documentation avancée

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 👥 Auteurs

- **Tarek.E** - Développeur principal
- **Contributeurs** - Voir [CONTRIBUTORS.md](CONTRIBUTORS.md)

## 🔗 Liens utiles

- [Repository GitHub](https://github.com/tarekounet/Wireguard-easy-script)
- [WG-Easy Documentation](https://github.com/wg-easy/wg-easy)
- [WireGuard Official](https://www.wireguard.com/)
- [Docker Documentation](https://docs.docker.com/)

---

## 📊 Statistiques du projet

<!-- Badge dynamique : affiche la dernière release (ou tag) publiée sur GitHub -->
![Version](https://img.shields.io/github/v/release/tarekounet/Wireguard-easy-script?label=version&color=blue&sort=semver)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey)
![Shell](https://img.shields.io/badge/shell-Bash-yellow)

**Dernière mise à jour :** Août 2025
