# 📦 Wireguard Easy Script

### [0.10.0] – 2025-08-05

#### ✅ Ajouté
- test
- test

#### 🔄 Modifié
- test

#### 🐛 Corrigé
- test

## 📌 Présentation générale

Ce script Bash permet de gérer un serveur WireGuard avec Docker Compose, facilement et en toute sécurité.  
Il propose une interface en ligne de commande colorée, des sauvegardes automatiques, la gestion du mot de passe technique, et la mise à jour automatique du script et de ses modules.

---

### [0.9.0] – 2025-08-05

#### ✅ Ajouté
- Refonte visuelle du script principal
- Déplacement de certaines fonctions vers le script admin

#### 🔄 Modifié
- Système de mise à jour à chaque lancement
- Structure du menu admin

---

### [0.5.0] – 2025-06-15

#### ✅ Ajouté
- Nouveau script principal `config_wg.sh` avec auto-bootstrap
- Modules séparés dans `lib/` : `utils.sh`, `conf.sh`, `docker.sh`, `menu.sh`, `debian_tools.sh`

---

### [0.4.1] – 2025-05-31

#### ✅ Ajouté
- Modification des valeurs réseau : IP, masque, passerelle, DNS
- Extinction et redémarrage de la VM (mot de passe requis)
- Demande du mot de passe technique au premier lancement

#### 🔄 Modifié
- Détection DHCP/Static pour proposer le changement de mode
- Optimisation des performances

---

### [0.3.1] – 2025-05-31

#### ✅ Ajouté
- Switch entre version stable et beta
- Passage vers beta uniquement si version supérieure
- Retour automatique vers stable si nécessaire
- Fichier de configuration pour mémoriser les infos essentielles

#### 🔄 Modifié
- Refonte visuelle du script
- Optimisation des performances

#### 🐛 Corrigé
- Affichage du fichier changelog
- Erreurs liées au changement de canal
- Amélioration des infos de mise à jour

---

### [0.2.0] – 2025-05-30

#### ✅ Ajouté
- Menu VM Debian : disque, moniteur système (btop), terminal
- Implémentation du changelog dans le script

#### 🔄 Modifié
- Visuel du script
- Menu VM
- Restructuration générale

---

### [0.1.1] – 2025-05-29

#### ✅ Ajouté
- Menu VM Debian : IP, hostname, port SSH, mise à jour OS

#### 🐛 Corrigé
- Bug du double `$` dans la création du mot de passe Docker

---

### [0.1.0] – 2025-05-19

#### ✅ Ajouté
- Première version du projet
- Fonctionnalités de base

## 📌 Présentation générale

Ce script Bash permet de gérer un serveur WireGuard avec Docker Compose, facilement et en toute sécurité.  
Il propose une interface en ligne de commande colorée, des sauvegardes automatiques, la gestion du mot de passe technique, et la mise à jour automatique du script et de ses modules.
---