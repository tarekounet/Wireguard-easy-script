# 📦 Wireguard Easy Script

### [0.31.0] - 2026-02-16

#### ✅ Ajouté
- upgrade wg-easy 15.1.0 => 15.2.2

### [0.30.1] - 2025-10-08


#### 🐛 Corrigé
- génération auto du code

### [0.30.0] - 2025-10-08


#### 🔄 Modifié
- limitation du mot de passe généré a 12 caractères
- choix entre mot de passe manuel ou auto

### [0.29.0] - 2025-10-08


#### 🔄 Modifié
- retour menu si annulation de la création d'un utilisateur
- affichage du mot de passe aléatoire généré

### [0.28.2] - 2025-10-08


#### 🐛 Corrigé
- corection lancement

### [0.28.1] - 2025-10-07


#### 🐛 Corrigé
- lancement du script admin

### [0.28.0] - 2025-10-07


#### 🔄 Modifié
- modif RAZ

### [0.27.0] - 2025-10-07


#### 🔄 Modifié
- modification du raz avec volume + docker-compose

### [0.26.3] - 2025-10-07


#### 🐛 Corrigé
- test

### [0.26.2] - 2025-10-06


#### 🐛 Corrigé
- script admin

### [0.26.1] - 2025-10-06


#### 🐛 Corrigé
- RAZ

### [0.26.0] - 2025-10-06


#### 🔄 Modifié
- modification de la création d'un utilisateur
- changement du RAZ de wireguard

#### 🐛 Corrigé
- insescure en true dans le tamplate

### [0.25.2] - 2025-10-06


#### 🐛 Corrigé
- template docker compose

### [0.25.1] - 2025-10-06


#### 🐛 Corrigé
- docker correctif

### [0.25.0] - 2025-10-06


#### 🔄 Modifié
- modif du fichier docker compose

### [0.24.3] - 2025-08-19


#### 🐛 Corrigé
- correction docker-compose

### [0.24.2] - 2025-08-19


#### 🐛 Corrigé
- utilisateur

### [0.24.1] - 2025-08-19


#### 🐛 Corrigé
- création utilisateur

### [0.24.0] - 2025-08-19


#### 🔄 Modifié
- si pas d'utilisateur alors proposer d'en créer un

### [0.23.2] - 2025-08-16


#### 🐛 Corrigé
- fermeture de session local

### [0.23.1] - 2025-08-16


#### 🐛 Corrigé
- correction des traduction
- problème d'arrêt de la session ssh

### [0.23.0] - 2025-08-16


#### 🔄 Modifié
- modification de d'etape 3 pour la création d'un utilisateur

### [0.22.0] - 2025-08-16

#### ✅ Ajouté
- Détection d'une instance Docker : si oui, arrêter le processus avant de supprimer l'utilisateur

#### 🔄 Modifié
- modification de la phrase pour supprimer RAZ docker-wireguard
- le menu RAZ n'affichera que les profils avec docker configuré
- modif sur le récapitulatif quand on crée un utilisateur on pourra changer le nom avant de valider

#### 🐛 Corrigé
- correction du menu GESTION ALIMENTATION

### [0.21.0] - 2025-08-14


#### 🔄 Modifié
- modification visuel du menu RAZ docker

#### 🐛 Corrigé
- creation d'un utilisateur menu pour créer absent
- problème de correspondense pour le mot de passe

### [0.20.7] - 2025-08-14


#### 🐛 Corrigé
- affichage des tâche programmé

### [0.20.6] - 2025-08-14


#### 🐛 Corrigé
- correction du sript power.sh

### [0.20.5] - 2025-08-14


#### 🐛 Corrigé
- test mise a jour

### [0.20.4] - 2025-08-14


#### 🐛 Corrigé
- refonte mise a jour auto

### [0.20.3] - 2025-08-14


#### 🐛 Corrigé
- correction de la mise à jour auto 

### [0.20.2] - 2025-08-14


#### 🐛 Corrigé
- correction mise a jour du script admin

### [0.20.1] - 2025-08-14


#### 🐛 Corrigé
- script

### [0.20.0] - 2025-08-14


#### 🔄 Modifié
- nettoyage du script admin
- Suppression des fonctions en doublon

### [0.19.0] - 2025-08-14


#### 🔄 Modifié
- ignore la mise a jour si pas internet

### [0.18.4] - 2025-08-13


#### 🐛 Corrigé
- simplification de mise a jour 

### [0.18.3] - 2025-08-13


#### 🐛 Corrigé
- correction de l'affichage de mise a jour plus simple

### [0.18.2] - 2025-08-13


#### 🐛 Corrigé
- bug d'affichage du nombre de mise a jour system
- Numéro de version du script erroné.

### [0.18.1] - 2025-08-13


#### 🐛 Corrigé
- mise a jour auto 

### [0.18.0] - 2025-08-13


#### 🔄 Modifié
- restructure le menu admin

### [0.17.0] - 2025-08-12


#### 🔄 Modifié
- modif de du menu gestion utilisateur

### [0.16.0] - 2025-08-11


#### 🔄 Modifié
- suppression de l'upgrade en debian 13

### [0.15.3] - 2025-08-11


#### 🐛 Corrigé
- impossible de lancer le script admin si il n'y a pas internet.

### [0.15.2] - 2025-08-07


#### 🐛 Corrigé
- correction le la remonté d'info version docker

### [0.15.1] - 2025-08-07


#### 🐛 Corrigé
- remonté d'information de la version du container

### [0.15.0] - 2025-08-07


#### 🔄 Modifié
- modification des couleur du menu
- optimisation du scrit
- suppression du fichier de conf et du mot de passe technique

### [0.14.2] - 2025-08-07


#### 🐛 Corrigé
- Dans le script admin correction de l'arrêt service SSH au lieu de fermer juste la session.

### [0.14.1] – 2025-08-06


#### 🐛 Corrigé
- correction pour l'exécution
- upgrade distri

### [0.14.0] – 2025-08-06


#### 🔄 Modifié
- modification de la configuration du docker
- ajout de l'afficher de l'url pour ce conneter sur l'interface
- modification des infos du script dans le menu
- déplacement de la version du container dans > etat du service wireguad

#### 🐛 Corrigé
- bug pour la mise a jour du script admin

### [0.13.0] – 2025-08-06


#### 🔄 Modifié
- armonisation de la gestion des versions entre le script principale et admin

### [0.12.0] – 2025-08-06


#### 🔄 Modifié
- Optimisation général du script et des modules
- suppresion des logs

#### 🐛 Corrigé
- erreur de permision

### [0.11.2] – 2025-08-05


#### 🐛 Corrigé
- docker permission

### [0.11.1] – 2025-08-05


#### 🐛 Corrigé
- Erreur pendant le processus de mise à jour.

### [0.11.0] – 2025-08-05

#### ✅ Ajouté
- ajout des logs pour les erreur

#### 🐛 Corrigé
- la remonté de l'etat du container déjà installé

### [0.10.0] – 2025-08-05

#### ✅ Ajouté
- test
- test

#### 🔄 Modifié
- test

#### 🐛 Corrigé
- test

### [0.9.0] – 2025-08-05

#### ✅ Ajouté
- Refonte visuelle du script principal
- Déplacement de certaines fonctions vers le script admin

#### 🔄 Modifié
- Système de mise à jour à chaque lancement
- Structure du menu admin

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
