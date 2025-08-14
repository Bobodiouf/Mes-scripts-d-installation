#!/bin/bash
set -e

# 1. Détection automatique de la dernière version GLPI
echo "Détection de la dernière version stable de GLPI..."
LATEST=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest \
  | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

echo "→ Version détectée : $LATEST"

# 2. Informations utilisateur
read -rp "Nom ou IP du serveur GLPI (ex: glpi.local ou 10.3.30.107) : " SERVER_NAME
read -rp "Nom de la base de données (ex: glpidb) : " DB_NAME
read -rp "Nom utilisateur MariaDB (ex: glpiuser) : " DB_USER
read -rp "Mot de passe utilisateur MariaDB : " DB_PASS

# 3. Installation des dépendances
echo "Installation de nginx, MariaDB, PHP et modules..."
sudo apt update && sudo apt install -y nginx mariadb-server php-fpm php-mysql php-gd php-xml php-mbstring php-curl php-intl php-zip wget unzip

# 4. Sécurisation de MariaDB
sudo mysql_secure_installation <<EOF

y
n
y
y
y
y
EOF

# 5. Création de la base et de l'utilisateur
sudo mysql -u root <<EOF
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# 6. Téléchargement et installation de GLPI
GLPI_URL="https://github.com/glpi-project/glpi/releases/download/$LATEST/glpi-$LATEST.tgz"
cd /tmp
wget "$GLPI_URL"
sudo mkdir -p /var/www/html/glpi
sudo tar -xzf "glpi-$LATEST.tgz" -C /var/www/html/glpi --strip-components=1

# 7. Permissions
sudo chown -R www-data:www-data /var/www/html/glpi
sudo find /var/www/html/glpi -type d -exec chmod 755 {} \;
sudo find /var/www/html/glpi -type f -exec chmod 644 {} \;

# 8. Configuration de nginx
sudo tee /etc/nginx/sites-available/glpi.conf > /dev/null <<EOF
server {
    listen 80;
    server_name $SERVER_NAME;

    root /var/www/html/glpi;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)\$ {
        expires max;
        log_not_found off;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/glpi.conf /etc/nginx/sites-enabled/glpi.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl reload nginx
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

echo "Installation terminée. Accédez à http://$SERVER_NAME pour finaliser l’installation."
