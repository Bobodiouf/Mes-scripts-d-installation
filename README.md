# I.	Déploiement de PassBolt

Dans le cadre de notre étude, et pour déployer PassBolt sur un Debian, quelques éléments prérequis sont nécessaires :
-	Un serveur Debian 12 minimal.
-	Un nom de domaine/d'hôte pointant vers le serveur, ou au moins pouvant atteindre le serveur via une adresse IP statique.
-	Un serveur SMTP fonctionnel pour les notifications par e-mail
-	Un service NTP fonctionnel pour éviter les problèmes d'authentification GPG
-	La configuration serveur recommandée est : 2 cœurs et 2 Go de RAM.

## 1.	Phases du déploiement 
a.	Préparation du système et configuration réseau de base
Avant toute installation ou déploiement de solution logicielle, il est essentiel de disposer d’un environnement système propre, stable et correctement configuré. Cette étape vise à préparer le serveur hôte en assurant la mise à jour du système d’exploitation, la définition des paramètres réseau de base (nom d’hôte, adresse IP statique, passerelle, DNS), ainsi que l’ouverture éventuelle des ports nécessaires au bon fonctionnement des services à venir.

Télécharger ufw pour configurer les port SSH (22) pour l’administration à distance, HTTP (80) et HTTPS (443) pour l’accès web. En cas d’absence de SSH sur votre serveur, la première ligne installe les packages ufw et openSSH (facultative) pour un accès à distance.

## b.	Installation d’un certificat SSL auto-signée 

Puis Accorder les droits d’exécution et d’écriture pour l’utilisateur aux fichiers :

## c.	Installation de NGINX et MariaDB
Si votre serveur n’a pas de serveur web installer le package Debian de Passbolt installera un serveur web nginx et une base de données mariadb qui sera configurer pour Passbolt. Si vous préférer installer vous-même votre serveur nginx et mariadb vous pouvez le faire en utilisant les commandes suivantes :

## d.	Configuration du référentiel de package
Avant de télécharger Passbolt CE et de l'installer, Passbolt fournit un référentiel de packages que qu’il est important de configurer pour faciliter les tâches d'installation et de mise à jour.

Ces lignes permettent de : 
-	Téléchargez notre script d’installation des dépendances ;
-	Téléchargez notre SHA512SUM pour le script d'installation et 
-	Assurez-vous que le script est valide et exécutez-le.

2.	Installation de PassBolt
Après avoir installé toutes les dépendances et côcher tous les prérequis nécessaires pour l’installation et la configuration de Passbolt, vous devrez avoir sur votre écran ceci :
 

C’est la confirmation que le script a bien été exécuter et Passbolt est près à être installé sur le système. Si des messages d’erreur apparait à ce niveau. Il suffit de suivre les recommandations dictées sur les logs d’erreurs pour corriger le problème.
A présent il faut lancer la commande ci-dessous pour configurer Mariadb et Nginx afin d’achever la configuration du Passbolt en ligne de commande. La prochaine étape se fera sur l’interface web de Passbolt.

## e.	Configuration de Mariadb
Lors de l’execution du script d’installation de Passbolt, le paquet Debian passbolt installera le serveur mariadb localement. Cette étape permettra de créer une base de données mariadb vide pour passbolt. 
Figure 1: Image de configuration de Mariadb

Le processus de configuration demandera les identifiants de l'administrateur mariadb pour créer une nouvelle base de données. Par défaut, dans la plupart des installations, le nom d'utilisateur administrateur est « root » et le mot de passe est vide.
Nous devons maintenant créer un utilisateur mariadb avec des autorisations réduites pour que Passbolt puisse se connecter. Ces valeurs seront également demandées ultérieurement par l'outil de configuration Web de Passbolt ; Il est donc nécessaire de les garder à l'esprit.
Enfin, nous devons créer une base de données que passbolt pourra utiliser, pour cela nous devons la nommer.
	
## f.	Configurer nginx pour servir HTTPS
Selon les besoins, il existe deux options différentes pour configurer nginx et SSL à l'aide du package Debian et un troisième si vous ne souhaitez pas configurer aussitôt le certificat :
-	Auto (Avec Let’s Encrypt)
-	Manuel (Utilisation de certificats SSL fournie par l’utilisateur)
-	None (Dans le cas où vous n’avez pas de certificat SSL et que vous souhaitez le configurer plus tard).
 
Figure 2: Image de configuration de Nginx
Voilà c’est fait. On peut à présent nous connecter sur l’interface graphique à travers l’adresse IP ou les FQDN pour pouvoir configurer l’outils et les paramètres de base.
  
## 3.	Configuration de Passbolt
Avant d'utiliser l'application, il faut la configurer. Accédons à l'adresse IP ou au nom d'hôte de passbolt. On accédera alors à la page de démarrage.
 
## a.	Healthcheck : Le bilan de santé
La première page de l'assistant vous indiquera si votre environnement est prêt pour Passbolt. Résolvez les problèmes éventuels et cliquez sur « Démarrer la configuration » lorsque vous êtes prêt. 
Figure 4: Image Assistant de configuration de Passbolt web
b.	La Base de données
Cette étape consiste à indiquer à Passbolt la base de données à utiliser. Saisissez le nom d'hôte, le numéro de port, le nom de la base de données, le nom d'utilisateur et le mot de passe.
 
Figure 5: Image Assistant - Base de données
c.	La Clé GPG
Dans cette section, vous pouvez générer ou importer une paire de clés GPG. Cette paire de clés sera utilisée par l'API Passbolt pour s'authentifier lors du processus de connexion. Générez une clé si vous n'en avez pas.
 
Figure 6: Image Assistant - La clé GPG


Pour créer une nouvelle clé GnuPG sans mot de passe, possible en exécutant le script bash :

Il ne faut pas hésiter à remplacer Name-Real: et Name-Email: par les vôtres.
Pour afficher la nouvelle clé :

## d.	Serveur de messagerie (SMTP)
À ce stade, l'assistant vous demandera de saisir les détails de votre serveur SMTP.
 
## Figure 7: Image Assistant - Serveur SMTP

On peut également vérifier que la configuration est correcte en utilisant la fonction d'e-mail de test à droite de votre écran. Saisir l'adresse e-mail à laquelle on souhaite que l'assistant nous envoie un e-mail de test, puis cliquer sur « Envoyer un e-mail de test ».

## e.	Les préférences 
L'assistant demandera ensuite quelles préférences souhaitées pour l’instance de Passbolt. Les valeurs par défaut recommandées sont pré-renseignées, mais on peut toujours les modifier.
Les prochaines étapes sont : 
-	La Première création d’utilisateur
-	L’Installation
-	Le Processus de configuration HTTPS
-	Le Téléchargement du plugin
-	La Création de la nouvelle clé et pour finir
-	Télécharger le kit de récupération et
-	Définir votre jeton de sécurité
Et voilà ;	
Figure 8: Image Assistant -Installation de l'extension sur firefox
 
Figure 9: Extension Firefox

# Utilisation du script

Sauvegarde le script dans un fichier, par exemple install-n8n.sh
Rends-le exécutable : chmod +x install-n8n.sh
Lance l'installation : sudo ./install-n8n.sh

Le script va te demander :

Les informations de connexion à ta base MariaDB
Un nom d'utilisateur et mot de passe pour l'interface n8n
L'URL publique de ton instance

Fonctionnalités du script

Installation complète automatisée
Configuration sécurisée avec authentification
Service systemd pour démarrage automatique
Script de gestion (n8n-manage) avec commandes utiles :

n8n-manage start/stop/restart
n8n-manage status/logs
n8n-manage update (met à jour n8n)
n8n-manage backup (sauvegarde la config)

Après installation
Le script créera automatiquement les tables nécessaires dans ta base MariaDB au premier démarrage. Tu peux vérifier que tout fonctionne avec :
bashsystemctl status n8n
journalctl -u n8n -f  # logs en temps réel
 










 
