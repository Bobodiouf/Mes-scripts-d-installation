#!/bin/bash

# Générer les certificats SSL
chmod +x generate_ssl.sh
./generate_ssl.sh

# Créer les dossiers nécessaires
mkdir -p config html

# Démarrer les conteneurs
docker-compose up -d

# Attendre que les conteneurs soient prêts
sleep 30

# Installer Passbolt
docker exec -it passbolt_app su -m -c "/usr/local/bin/install -y \
    --data /var/www/passbolt \
    --db-host passbolt_db \
    --db-name passbolt \
    --db-admin-user root \
    --db-admin-password Passer \
    --db-user passbolt \
    --db-pass Passer \
    --url https://passbolt.local \
    --admin-first-name Admin \
    --admin-last-name User \
    --admin-email ismael.mouloungui@groupebatimat.com \
    --admin-username admin \
    --force" -s /bin/sh www-data

# Tester la configuration email
docker exec -it passbolt_app su -m -c "bin/cake passbolt send_test_email --recipient=ismael.mouloungui@groupebatimat.com" -s /bin/sh www-data