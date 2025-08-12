#!/bin/bash
set -e

echo "=== Mise à jour du système ==="
sudo apt update -y
sudo apt dist-upgrade -y

echo "=== Installation des outils nécessaires pour SSL ==="
sudo apt install openssl -y

# Récupération automatique du domaine/FQDN
DOMAIN_NAME=$(hostname -f)
SSL_DIR="/etc/ssl/passbolt"
DAYS_VALID=365

echo "=== Création du répertoire pour SSL ==="
sudo mkdir -p $SSL_DIR

echo "=== Génération du certificat auto-signé ==="
sudo openssl req -x509 -nodes -days $DAYS_VALID -newkey rsa:2048 \
  -keyout $SSL_DIR/passbolt.key \
  -out $SSL_DIR/passbolt.crt \
  -subj "/C=SN/ST=Dakar/L=Dakar/O=Organisation/OU=IT Department/CN=$DOMAIN_NAME"

echo "Certificat créé :"
echo "  Clé privée : $SSL_DIR/passbolt.key"
echo "  Certificat : $SSL_DIR/passbolt.crt"

echo "=== Vérification de PHP ==="
if ! dpkg --get-selections | grep php; then
    echo "Suppression de PHP"
    sudo apt remove -y php php-* || true
    sudo apt purge 'php*'
    sudo apt autoremove --purge
else
    echo "PHP est déjà installé."
fi

echo "=== Installation de Passbolt depuis le site officiel ==="
curl -LO "https://download.passbolt.com/ce/installer/passbolt-repo-setup.ce.sh"
curl -LO "https://github.com/passbolt/passbolt-dep-scripts/releases/latest/download/passbolt-ce-SHA512SUM.txt"

sha512sum -c passbolt-ce-SHA512SUM.txt && \
sudo bash ./passbolt-repo-setup.ce.sh || \
{ echo "Bad checksum. Aborting"; rm -f passbolt-repo-setup.ce.sh; exit 1; }

sudo apt install passbolt-ce-server -y

echo "=== Configuration automatique de Nginx avec SSL ==="
NGINX_CONF="/etc/nginx/sites-available/passbolt.conf"

if [ -f "$NGINX_CONF" ]; then
    sudo sed -i "s|listen 80;|listen 443 ssl;|g" $NGINX_CONF
    sudo sed -i "/server_name/a \\    ssl_certificate $SSL_DIR/passbolt.crt;\n    ssl_certificate_key $SSL_DIR/passbolt.key;" $NGINX_CONF
    sudo sed -i "s|server_name .*;|server_name $DOMAIN_NAME;|g" $NGINX_CONF
else
    echo "Le fichier $NGINX_CONF n'existe pas encore. Pense à appliquer la config SSL manuellement."
fi

echo "=== Redémarrage de Nginx ==="
sudo systemctl restart nginx

echo "=== Installation terminée ==="
echo "Accédez à Passbolt via : https://$DOMAIN_NAME"
echo "N'oubliez pas de configurer Passbolt en suivant les instructions sur l'interface web."