# Passbolt Container Configuration avec Gmail SMTP, Self-Signed Cert, et NTP

Voici une configuration complète pour votre installation Passbolt avec Docker :

## 1. Fichier Docker Compose (`docker-compose.yml`)

```yaml
version: '3.8'

services:
    passbolt_app:
        image: passbolt/passbolt:latest
        container_name: passbolt_app
        restart: unless-stopped
        environment:
            # Configuration de la base de données
            DATASOURCES_DEFAULT_HOST: passbolt_db
            DATASOURCES_DEFAULT_USERNAME: passbolt
            DATASOURCES_DEFAULT_PASSWORD: votre_mot_de_passe_db
            DATASOURCES_DEFAULT_DATABASE: passbolt
            
            # Configuration SMTP Gmail
            EMAIL_TRANSPORT_DEFAULT_CLASS: Smtp
            EMAIL_TRANSPORT_DEFAULT_HOST: smtp.gmail.com
            EMAIL_TRANSPORT_DEFAULT_PORT: 587
            EMAIL_TRANSPORT_DEFAULT_USERNAME: votre_email@gmail.com
            EMAIL_TRANSPORT_DEFAULT_PASSWORD: votre_mot_de_passe_app
            EMAIL_TRANSPORT_DEFAULT_TLS: true
            EMAIL_DEFAULT_FROM: Passbolt <votre_email@gmail.com>
            EMAIL_DEFAULT_FROM_NAME: Passbolt
            
            # Configuration de l'application
            APP_FULL_BASE_URL: https://passbolt.votre-domaine.com
            
            # Configuration SSL (auto-signé)
            PASSBOLT_SSL_FORCE: true
            PASSBOLT_SSL_SETUP: true
            
            # Configuration NTP
            NTP_SERVER: pool.ntp.org
            
        volumes:
            - gpg_data:/etc/passbolt/gpg
            - jwt_data:/etc/passbolt/jwt
            - ssl_data:/etc/ssl/certs/passbolt
            - ./config/passbolt.php:/etc/passbolt/passbolt.php
        networks:
            - passbolt_network
        depends_on:
            - passbolt_db
        extra_hosts:
            - "host.docker.internal:host-gateway"
        dns:
            - 8.8.8.8
            - 1.1.1.1

    passbolt_db:
        image: mariadb:10.11
        container_name: passbolt_db
        restart: unless-stopped
        environment:
            MYSQL_ROOT_PASSWORD: votre_mot_de_passe_root_db
            MYSQL_DATABASE: passbolt
            MYSQL_USER: passbolt
            MYSQL_PASSWORD: votre_mot_de_passe_db
        volumes:
            - db_data:/var/lib/mysql
        networks:
            - passbolt_network
        command: 
            - --default-time-zone=+00:00
            - --log-bin-trust-function-creators=1

    nginx:
        image: nginx:alpine
        container_name: passbolt_nginx
        restart: unless-stopped
        ports:
            - "443:443"
            - "80:80"
        volumes:
            - ./nginx.conf:/etc/nginx/nginx.conf
            - ssl_data:/etc/ssl/certs/passbolt:ro
            - ./html:/usr/share/nginx/html:ro
        networks:
            - passbolt_network
        depends_on:
            - passbolt_app

volumes:
    gpg_data:
    jwt_data:
    db_data:
    ssl_data:

networks:
    passbolt_network:
        driver: bridge
```

## 2. Configuration Nginx (`nginx.conf`)

```nginx
events {
        worker_connections 1024;
}

http {
        upstream passbolt {
                server passbolt_app:80;
        }

        server {
                listen 80;
                server_name passbolt.votre-domaine.com;
                return 301 https://$server_name$request_uri;
        }

        server {
                listen 443 ssl http2;
                server_name passbolt.votre-domaine.com;

                ssl_certificate /etc/ssl/certs/passbolt/certificate.crt;
                ssl_certificate_key /etc/ssl/certs/passbolt/private.key;
                
                ssl_protocols TLSv1.2 TLSv1.3;
                ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
                ssl_prefer_server_ciphers off;

                location / {
                        proxy_pass http://passbolt;
                        proxy_set_header Host $host;
                        proxy_set_header X-Real-IP $remote_addr;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto $scheme;
                }
        }
}
```

## 3. Générer un certificat auto-signé

Créez un script `generate_ssl.sh` :

```bash
#!/bin/bash
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ssl/private.key \
    -out ssl/certificate.crt \
    -subj "/C=FR/ST=Paris/L=Paris/O=VotreEntreprise/CN=passbolt.votre-domaine.com"
```

## 4. Configuration Passbolt (`config/passbolt.php`)

```php
<?php
return [
        'App' => [
                'fullBaseUrl' => 'https://passbolt.votre-domaine.com'
        ],
        'Email' => [
                'default' => [
                        'transport' => 'Smtp',
                        'host' => 'smtp.gmail.com',
                        'port' => 587,
                        'timeout' => 30,
                        'username' => 'votre_email@gmail.com',
                        'password' => 'votre_mot_de_passe_app',
                        'client' => null,
                        'tls' => true,
                        'url' => null,
                ],
        ],
        'Passbolt' => [
                'ssl' => [
                        'force' => true,
                        'setup' => true
                ],
                'email' => [
                        'validate' => [
                                'domain' => false
                        ]
                ]
        ]
];
```

## 5. Script d'installation (`setup.sh`)

```bash
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
    --db-admin-password votre_mot_de_passe_root_db \
    --db-user passbolt \
    --db-pass votre_mot_de_passe_db \
    --url https://passbolt.votre-domaine.com \
    --admin-first-name Admin \
    --admin-last-name User \
    --admin-email votre_email@gmail.com \
    --admin-username admin \
    --force" -s /bin/sh www-data

# Tester la configuration email
docker exec -it passbolt_app su -m -c "bin/cake passbolt send_test_email --recipient=votre_email@gmail.com" -s /bin/sh www-data
```

## 6. Variables d'environnement (`.env`)

```env
# Base de données
DB_ROOT_PASSWORD=mot_de_passe_root_db_securise
DB_PASSWORD=mot_de_passe_db_securise

# Gmail
GMAIL_EMAIL=votre_email@gmail.com
GMAIL_APP_PASSWORD=mot_de_passe_app

# Domaine
DOMAIN=passbolt.votre-domaine.com

# NTP
NTP_SERVER=pool.ntp.org
```

## 7. Notes importantes :

1. **Mot de passe d'application Gmail** : Générez-le sur https://myaccount.google.com/apppasswords
2. **Synchronisation NTP** : Le conteneur utilise l'heure de l'hôte par défaut, mais le serveur NTP est configuré pour la synchronisation interne
3. **Certificat auto-signé** : Le navigateur affichera un avertissement de sécurité - utilisez Let's Encrypt en production
4. **Domaine** : Remplacez `passbolt.votre-domaine.com` par votre vrai domaine
5. **Mots de passe de base de données** : Utilisez des mots de passe forts et uniques

## 8. Commandes de démarrage :

```bash
# Rendre les scripts exécutables
chmod +x generate_ssl.sh setup.sh

# Lancer l'installation
./setup.sh

# Ou démarrer manuellement
docker-compose up -d
```

Cette configuration fournit une installation Passbolt complète avec SMTP Gmail, certificats auto-signés, synchronisation NTP et réseau Docker adapté.