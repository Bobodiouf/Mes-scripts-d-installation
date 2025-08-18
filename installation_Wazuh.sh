#!/bin/bash
# Couleur verte fluo
GREEN="\e[92m"
RESET="\e[0m"

# Vérification des droits
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté par un utilisateur avec les droits root."
    exit 1
fi

echo "===== Mise à jour du système ====="
apt update -y && apt dist-upgrade -y

echo "===== Installation des dépendances ====="
apt install -y curl gnupg apt-transport-https

echo "===== Téléchargement du script Wazuh ====="
curl -sO https://packages.wazuh.com/4.9/wazuh-install.sh

echo "===== Installation Wazuh All-in-One ====="
if ! dpkg --get-selections | grep wazuh-* filebeat filebeat-*; then
    echo "Installation de Wazuh..."
    chmod +x wazuh-install.sh
    ./wazuh-install.sh -a -o
else
    bash ./wazuh-install.sh -a
fi

echo "===== Vérification des services ====="
systemctl status wazuh-dashboard.service wazuh-manager.service wazuh-indexer --no-pager

# Texte de la bannière ASCII
banner=$(cat <<'EOF'

██╗░░░░░███╗░░░███╗██╗  ░██████╗███████╗██████╗░██╗░░░██╗██╗░█████╗░███████╗
██║░░░░░████╗░████║██║  ██╔════╝██╔════╝██╔══██╗██║░░░██║██║██╔══██╗██╔════╝
██║░░░░░██╔████╔██║██║  ╚█████╗░█████╗░░██████╔╝╚██╗░██╔╝██║██║░░╚═╝█████╗░░
██║░░░░░██║╚██╔╝██║██║  ░╚═══██╗██╔══╝░░██╔══██╗░╚████╔╝░██║██║░░██╗██╔══╝░░
███████╗██║░╚═╝░██║██║  ██████╔╝███████╗██║░░██║░░╚██╔╝░░██║╚█████╔╝███████╗
╚══════╝╚═╝░░░░░╚═╝╚═╝  ╚═════╝░╚══════╝╚═╝░░╚═╝░░░╚═╝░░░╚═╝░╚════╝░╚══════╝
EOF
)

# Effet machine à écrire
for (( i=0; i<${#banner}; i++ )); do
    echo -ne "${GREEN}${banner:$i:1}${RESET}"
    sleep 0.002  # Vitesse (0.002 = rapide, 0.05 = lent)
done

echo -e "\n${GREEN}---------------------------------------------------------------${RESET}"
echo -e "${GREEN}        LMI SERVICE - Administration & Sécurité IT${RESET}"
echo -e "${GREEN}---------------------------------------------------------------${RESET}"

echo "===== Informations d'accès ====="
IP=$(hostname -I | awk '{print $1}')
echo "Wazuh Dashboard disponible à : https://$IP/app"
