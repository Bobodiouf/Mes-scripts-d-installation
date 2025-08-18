#!/bin/bash
set -e
# Couleur verte fluo
GREEN="\e[92m"
RESET="\e[0m"

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

echo "=== Configuration des permissions pour SSL ==="
sudo chmod 600 /etc/ssl/passbolt/passbolt.key
sudo chmod 644 /etc/ssl/passbolt/passbolt.crt

echo "=== Vérification de PHP ==="
if dpkg --get-selections | grep -q "^php"; then
    echo "Suppression de PHP"
    sudo apt remove -y php php-* || true
    sudo apt purge 'php*'
    sudo apt autoremove --purge
else
    echo "PHP n'est pas installé."
fi

echo "=== Vérification de Mariadb ==="
if ! dpkg --get-selections | grep mariadb-server; then
    echo "Installation de MariaDB"
    sudo apt install mariadb-server -y
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
else
    echo "MariaDB est déjà installé."
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
fi

echo "=== Installation de Passbolt depuis le site officiel ==="
curl -LO "https://download.passbolt.com/ce/installer/passbolt-repo-setup.ce.sh"
curl -LO "https://github.com/passbolt/passbolt-dep-scripts/releases/latest/download/passbolt-ce-SHA512SUM.txt"

sha512sum -c passbolt-ce-SHA512SUM.txt && \
sudo bash ./passbolt-repo-setup.ce.sh || \
{ echo "Bad checksum. Aborting"; rm -f passbolt-repo-setup.ce.sh; exit 1; }

sudo apt install passbolt-ce-server -y

echo "=== Configuration de Nginx avec SSL ==="
NGINX_CONF="/etc/nginx/sites-available/nginx-passbolt.conf"

if [ -f "$NGINX_CONF" ]; then
    echo "Le fichier $NGINX_CONF existe déjà, mise à jour de la configuration SSL..."
    sudo sed -i "s|listen 80;|listen 443 ssl;|g" $NGINX_CONF
    sudo sed -i "s|server_name .*;|server_name $DOMAIN_NAME;|g" $NGINX_CONF
    if ! grep -q "ssl_certificate" $NGINX_CONF; then
        sudo sed -i "/server_name/a \\    ssl_certificate $SSL_DIR/passbolt.crt;\n    ssl_certificate_key $SSL_DIR/passbolt.key;" $NGINX_CONF
    fi
    sudo ln -sf /etc/nginx/sites-available/nginx-passbolt.conf /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
else
    echo "Création du fichier $NGINX_CONF avec configuration SSL..."
    sudo tee $NGINX_CONF > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN_NAME;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN_NAME;

    ssl_certificate $SSL_DIR/passbolt.crt;
    ssl_certificate_key $SSL_DIR/passbolt.key;

    root /usr/share/php/passbolt/webroot;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOL
sudo ln -sf /etc/nginx/sites-available/nginx-passbolt.conf /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
fi
echo "=== Redémarrage de Nginx ==="
sudo systemctl restart nginx

# © Ismael MOULOUNGUI - Tous droits réservés
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


echo "=== Installation terminée ==="
echo "Accédez à Passbolt via : https://$DOMAIN_NAME"
echo "N'oubliez pas de configurer Passbolt en suivant les instructions sur l'interface web."