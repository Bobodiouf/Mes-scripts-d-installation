#!/bin/bash

# Vérification des droits
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ Ce script doit être exécuté par un utilisateur avec les droits root."
    exit 1
fi

echo "===== Mise à jour du système ====="
apt update -y && apt dist-upgrade -y

echo "===== Installation des dépendances ====="
apt install -y curl gnupg apt-transport-https

echo "===== Téléchargement du script Wazuh ====="
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh

echo "===== Installation Wazuh All-in-One ====="
bash ./wazuh-install.sh -a

echo "===== Vérification des services ====="
systemctl status wazuh-dashboard.service wazuh-manager.service wazuh-indexer --no-pager
sudo clear

echo "#########################################################################################################"
echo "#                                                                                                       #"
echo "#   _       __     __ _______ ________ _______________ _____         ___  _____   .-------\ ______      #"
echo "#  | |     |  \   /  |__  ___|     ___|  ____|_   ___ \\\__  \       /  _|_  ___| /  ------//  ____||    #"
echo "#  | |     | |\\\_//| |  | |  '.___ '.   |_____ | |   | || \  \     /  /   | |   |  |       -  |_____    #"
echo "#  | |     | | \_/ | |  | | ______)  ||  ____//| |___/ //  \  \   /  /    | |   |  |        |  ____//   #"
echo "#  | |____ | |   	 | |__| |/   ______|| |_____ | |___ \\\_  _\  \_// /_  __| |__ |  |       _| |         #"
echo "#  \\\_____/|_|  	 |_\\\_______\______/________//_|   |___|\\\________//\\\_______| \\\ \_____| ------- \\\  #"
echo "#   --------------------------------------------------------------------------------------//________//  #"
echo "#                                 LMI SERVICE - Auteur : ISMAEL MOULOUNGUI                              #"
echo "#########################################################################################################"

echo "===== Informations d'accès ====="
IP=$(hostname -I | awk '{print $1}')
echo "Wazuh Dashboard disponible à : https://$IP:5601"
