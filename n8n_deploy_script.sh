#!/bin/bash

# Script de déploiement n8n sur Debian 12 avec MariaDB
# Auteur: Assistant Claude
# Version: 1.0

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET="\e[0m"
NC='\033[0m' # No Color

# Fonction pour afficher les messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
   log_error "Ce script doit être exécuté en tant que root (sudo)"
   exit 1
fi

# Configuration par défaut (à modifier selon tes besoins)
N8N_USER="n8n"
N8N_PORT="5678"
N8N_HOST="0.0.0.0"
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="n8n"
DB_USER="admin"

# Demander les informations de base de données
echo "=== Configuration de la base de données ==="
read -p "Nom de la base de données MariaDB [n8n]: " input_db_name
DB_NAME=${input_db_name:-$DB_NAME}

read -p "Utilisateur de la base de données [admin]: " input_db_user
DB_USER=${input_db_user:-$DB_USER}

read -s -p "Mot de passe de la base de données: " DB_PASSWORD
echo

read -p "Host de la base de données [localhost]: " input_db_host
DB_HOST=${input_db_host:-$DB_HOST}

# Demander les informations d'authentification n8n
echo -e "\n=== Configuration de l'authentification n8n ==="
read -p "Nom d'utilisateur pour l'interface n8n [admin]: " N8N_AUTH_USER
N8N_AUTH_USER=${N8N_AUTH_USER:-admin}

read -s -p "Mot de passe pour l'interface n8n: " N8N_AUTH_PASSWORD
echo

# Demander l'URL publique et la configuration SSL
echo -e "\n=== Configuration SSL et domaine ==="
read -p "Voulez-vous configurer SSL ? (y/n) [y]: " SETUP_SSL
SETUP_SSL=${SETUP_SSL:-y}

if [[ $SETUP_SSL == "y" ]]; then
    echo "Types de certificat SSL disponibles :"
    echo "1) Certificat auto-signé (recommandé pour test/interne)"
    echo "2) Let's Encrypt (domaine public requis)"
    read -p "Choisissez le type de certificat (1/2) [1]: " SSL_TYPE
    SSL_TYPE=${SSL_TYPE:-1}
    
    if [[ $SSL_TYPE == "2" ]]; then
        read -p "Nom de domaine pour n8n (ex: n8n.mondomaine.com): " DOMAIN_NAME
        while [[ -z "$DOMAIN_NAME" ]]; do
            log_error "Le nom de domaine est requis pour Let's Encrypt"
            read -p "Nom de domaine pour n8n (ex: n8n.mondomaine.com): " DOMAIN_NAME
        done
        read -p "Email pour Let's Encrypt [admin@$DOMAIN_NAME]: " LETSENCRYPT_EMAIL
        LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-admin@$DOMAIN_NAME}
    else
        read -p "Nom de domaine/IP pour le certificat (ex: n8n.local ou IP) [n8n.local]: " DOMAIN_NAME
        DOMAIN_NAME=${DOMAIN_NAME:-n8n.local}
    fi
    WEBHOOK_URL="https://$DOMAIN_NAME"
else
    read -p "URL publique de n8n (ex: http://IP:5678): " WEBHOOK_URL
fi

log_info "Début de l'installation de n8n..."

# 1. Mise à jour du système
log_info "Mise à jour du système..."
apt update && apt upgrade -y
log_success "Système mis à jour"

# 2. Installation de Node.js 20
log_info "Installation de Node.js 20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
log_success "Node.js installé: $(node --version)"

# 3. Création de l'utilisateur n8n
log_info "Création de l'utilisateur $N8N_USER..."
if id "$N8N_USER" &>/dev/null; then
    log_warning "L'utilisateur $N8N_USER existe déjà"
else
    useradd -m -s /bin/bash $N8N_USER
    log_success "Utilisateur $N8N_USER créé"
fi

# 4. Installation de n8n
log_info "Installation de n8n..."
npm install n8n -g
log_success "n8n installé globalement"

# 5. Création du répertoire de configuration
log_info "Configuration de n8n..."
N8N_HOME="/home/$N8N_USER"
sudo -u $N8N_USER mkdir -p $N8N_HOME/.n8n

# 6. Création du fichier de configuration
log_info "Création du fichier de configuration..."
cat > $N8N_HOME/.n8n/.env << EOF
# Configuration générale
N8N_HOST=$N8N_HOST
N8N_PORT=$N8N_PORT
N8N_PROTOCOL=http
WEBHOOK_URL=$WEBHOOK_URL

# Authentification
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$N8N_AUTH_USER
N8N_BASIC_AUTH_PASSWORD=$N8N_AUTH_PASSWORD

# Configuration de la base de données MariaDB
DB_TYPE=mariadb
DB_MARIADB_HOST=$DB_HOST
DB_MARIADB_PORT=$DB_PORT
DB_MARIADB_DATABASE=$DB_NAME
DB_MARIADB_USER=$DB_USER
DB_MARIADB_PASSWORD=$DB_PASSWORD

# Paramètres additionnels
NODE_ENV=production
N8N_LOG_LEVEL=info
N8N_LOG_OUTPUT=file
N8N_LOG_FILE_LOCATION=$N8N_HOME/.n8n/logs/n8n.log

# Sécurité
N8N_SECURE_COOKIE=$([ "$SETUP_SSL" == "y" ] && echo "true" || echo "false")
N8N_BLOCK_ENV_ACCESS_IN_NODE=true

# Performance
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168
EOF

chown -R $N8N_USER:$N8N_USER $N8N_HOME/.n8n
log_success "Fichier de configuration créé"

# 7. Création du répertoire de logs
sudo -u $N8N_USER mkdir -p $N8N_HOME/.n8n/logs

# 8. Test de connexion à la base de données
log_info "Test de connexion à la base de données..."
if command -v mariadb &> /dev/null; then
    if mariadb -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "USE $DB_NAME;" 2>/dev/null; then
        log_success "Connexion à la base de données réussie"
    else
        log_error "Impossible de se connecter à la base de données"
        log_error "Vérifiez vos paramètres de connexion"
        exit 1
    fi
else
    log_warning "Client MariaDB non installé, impossible de tester la connexion"
fi

# 9. Création du service systemd
log_info "Création du service systemd..."
cat > /etc/systemd/system/n8n.service << EOF
[Unit]
Description=n8n workflow automation
After=network.target mariadb.service
Wants=mariadb.service

[Service]
Type=simple
User=$N8N_USER
Group=$N8N_USER
ExecStart=/usr/bin/n8n start
Restart=always
RestartSec=10
Environment=PATH=/usr/bin:/usr/local/bin
EnvironmentFile=$N8N_HOME/.n8n/.env
WorkingDirectory=$N8N_HOME
StandardOutput=journal
StandardError=journal
SyslogIdentifier=n8n

# Sécurité
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$N8N_HOME
PrivateTmp=true
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=true
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable n8n
log_success "Service systemd créé et activé"

# 10. Configuration SSL avec nginx et Let's Encrypt (si demandé)
if [[ $SETUP_SSL == "y" ]]; then
    log_info "Installation et configuration de nginx avec SSL..."
    
    # Installation nginx et certbot
    apt install -y nginx certbot python3-certbot-nginx
    
    # Configuration nginx pour n8n
    cat > /etc/nginx/sites-available/n8n << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    # Redirection forcée vers HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    # Configuration SSL (sera complétée par certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    
    # Configuration SSL moderne
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Sécurité headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Configuration pour n8n
    client_max_body_size 50M;
    
    location / {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts pour les workflows longs
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 300s;
        
        # Buffers
        proxy_buffering off;
        proxy_buffer_size 4k;
    }
    
    # Gestion des webhooks
    location ~* ^/webhook/ {
        proxy_pass http://127.0.0.1:$N8N_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
    
    # Activer le site
    ln -sf /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Tester la configuration nginx
    if nginx -t; then
        log_success "Configuration nginx validée"
    else
        log_error "Erreur dans la configuration nginx"
        exit 1
    fi
    
    # Démarrer nginx
    systemctl enable nginx
    systemctl start nginx
    
    # Obtenir le certificat SSL
    log_info "Obtention du certificat SSL avec Let's Encrypt..."
    log_warning "Assurez-vous que votre domaine $DOMAIN_NAME pointe vers cette IP !"
    
    # Configuration automatique avec certbot
    certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email $LETSENCRYPT_EMAIL --redirect
    
    if [ $? -eq 0 ]; then
        log_success "Certificat SSL installé avec succès"
        
        # Configuration du renouvellement automatique
        echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
        log_success "Renouvellement automatique configuré"
        
        # Mise à jour de la configuration n8n pour HTTPS
        sed -i 's/N8N_PROTOCOL=http/N8N_PROTOCOL=https/' $N8N_HOME/.n8n/.env
        
    else
        log_error "Erreur lors de l'obtention du certificat SSL"
        log_warning "Vous pouvez réessayer manuellement avec: certbot --nginx -d $DOMAIN_NAME"
    fi
    
    # Configuration du pare-feu pour HTTPS
    if command -v ufw &> /dev/null; then
        ufw allow 80/tcp
        ufw allow 443/tcp
        log_success "Ports HTTP/HTTPS autorisés dans le pare-feu"
    fi
    
else
    # Configuration du pare-feu standard
    if command -v ufw &> /dev/null; then
        log_info "Configuration du pare-feu..."
        ufw allow $N8N_PORT/tcp
        log_success "Port $N8N_PORT autorisé dans le pare-feu"
    else
        log_warning "ufw non installé, configuration du pare-feu ignorée"
    fi
fi

# 11. Démarrage du service
log_info "Démarrage du service n8n..."
systemctl start n8n

# Attendre que le service démarre
sleep 5

if systemctl is-active --quiet n8n; then
    log_success "Service n8n démarré avec succès"
else
    log_error "Erreur lors du démarrage du service n8n"
    log_info "Vérification du statut du service:"
    systemctl status n8n --no-pager
    log_info "Logs du service:"
    journalctl -u n8n --no-pager -n 20
    exit 1
fi

# 12. Vérification de la connectivité
log_info "Vérification de la connectivité..."
sleep 3

if [[ $SETUP_SSL == "y" ]]; then
    # Test HTTPS
    if curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN_NAME | grep -q "200\|401"; then
        log_success "n8n répond correctement sur HTTPS"
    else
        log_warning "n8n ne répond pas correctement sur HTTPS, vérifiez les logs"
        # Test fallback sur HTTP local
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:$N8N_PORT | grep -q "200\|401"; then
            log_info "n8n fonctionne en local, problème probablement lié à nginx/SSL"
        fi
    fi
else
    # Test HTTP standard
    if curl -s -o /dev/null -w "%{http_code}" http://localhost:$N8N_PORT | grep -q "200\|401"; then
        log_success "n8n répond correctement sur le port $N8N_PORT"
    else
        log_warning "n8n ne semble pas répondre correctement, vérifiez les logs"
    fi
fi

# 13. Création d'un script de gestion
log_info "Création du script de gestion..."
cat > /usr/local/bin/n8n-manage << 'EOF'
#!/bin/bash

case $1 in
    start)
        systemctl start n8n
        echo "n8n démarré"
        ;;
    stop)
        systemctl stop n8n
        echo "n8n arrêté"
        ;;
    restart)
        systemctl restart n8n
        if systemctl is-active --quiet nginx; then
            systemctl reload nginx
        fi
        echo "n8n redémarré"
        ;;
    status)
        echo "=== Statut n8n ==="
        systemctl status n8n --no-pager
        if systemctl is-active --quiet nginx; then
            echo -e "\n=== Statut nginx ==="
            systemctl status nginx --no-pager
        fi
        ;;
    logs)
        journalctl -u n8n -f
        ;;
    nginx-logs)
        if systemctl is-active --quiet nginx; then
            tail -f /var/log/nginx/access.log /var/log/nginx/error.log
        else
            echo "nginx n'est pas actif"
        fi
        ;;
    ssl-renew)
        if [[ -f /etc/nginx/ssl/n8n.crt ]]; then
            echo "Régénération du certificat auto-signé..."
            # Sauvegarde de l'ancien certificat
            cp /etc/nginx/ssl/n8n.crt /etc/nginx/ssl/n8n.crt.backup
            cp /etc/nginx/ssl/n8n.key /etc/nginx/ssl/n8n.key.backup
            
            # Régénération (valide 1 an de plus)
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /etc/nginx/ssl/n8n.key \
                -out /etc/nginx/ssl/n8n.crt \
                -subj "/C=FR/ST=France/L=Paris/O=n8n/OU=IT/CN=n8n.local"
            
            chmod 600 /etc/nginx/ssl/n8n.key
            chmod 644 /etc/nginx/ssl/n8n.crt
            systemctl reload nginx
            echo "Certificat auto-signé régénéré"
        elif command -v certbot &> /dev/null; then
            certbot renew
            systemctl reload nginx
            echo "Certificat Let's Encrypt renouvelé"
        else
            echo "Aucun certificat à renouveler"
        fi
        ;;
    ssl-status)
        if [[ -f /etc/nginx/ssl/n8n.crt ]]; then
            echo "=== Certificat auto-signé ==="
            openssl x509 -in /etc/nginx/ssl/n8n.crt -text -noout | grep -E "(Subject:|Not After:|DNS:|IP Address:)"
        elif command -v certbot &> /dev/null; then
            echo "=== Certificats Let's Encrypt ==="
            certbot certificates
        else
            echo "Aucun certificat SSL trouvé"
        fi
        ;;
    ssl-info)
        if [[ -f /etc/nginx/ssl/n8n.crt ]]; then
            echo "=== Informations complètes du certificat auto-signé ==="
            openssl x509 -in /etc/nginx/ssl/n8n.crt -text -noout
        else
            echo "Certificat auto-signé non trouvé"
        fi
        ;;
    update)
        npm update n8n -g
        systemctl restart n8n
        echo "n8n mis à jour et redémarré"
        ;;
    backup)
        timestamp=$(date +%Y%m%d_%H%M%S)
        sudo -u n8n cp -r /home/n8n/.n8n "/home/n8n/backup_n8n_$timestamp"
        echo "Sauvegarde créée: /home/n8n/backup_n8n_$timestamp"
        ;;
    *)
        echo "Usage: n8n-manage {start|stop|restart|status|logs|nginx-logs|ssl-renew|ssl-status|ssl-info|update|backup}"
        exit 1
        ;;
esac
EOF

chmod +x /usr/local/bin/n8n-manage
log_success "Script de gestion créé (/usr/local/bin/n8n-manage)"

# Résumé final
echo
echo "======================================"
echo "   INSTALLATION TERMINÉE AVEC SUCCÈS   "
echo "======================================"
echo
log_success "n8n est maintenant installé et configuré !"
echo
echo "Informations de connexion:"
echo "- URL: $WEBHOOK_URL"
echo "- Utilisateur: $N8N_AUTH_USER"
echo "- Mot de passe: [celui que vous avez défini]"
echo
echo "Commandes utiles:"
echo "- Statut du service: systemctl status n8n"
echo "- Logs en temps réel: journalctl -u n8n -f"
echo "- Redémarrer: systemctl restart n8n"
echo "- Script de gestion: n8n-manage {start|stop|restart|status|logs|nginx-logs|ssl-renew|ssl-status|ssl-info|update|backup}"
echo
echo "Fichiers importants:"
echo "- Configuration: $N8N_HOME/.n8n/.env"
echo "- Logs: $N8N_HOME/.n8n/logs/n8n.log"
echo "- Service: /etc/systemd/system/n8n.service"
if [[ $SETUP_SSL == "y" ]]; then
    echo "- Configuration nginx: /etc/nginx/sites-available/n8n"
    if [[ $SSL_TYPE == "1" ]]; then
        echo "- Certificat SSL auto-signé: /etc/nginx/ssl/n8n.crt"
        echo "- Clé privée SSL: /etc/nginx/ssl/n8n.key"
    else
        echo "- Certificat SSL Let's Encrypt: /etc/letsencrypt/live/$DOMAIN_NAME/"
    fi
fi
echo
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

log_info "Pour accéder à l'interface, ouvrez votre navigateur sur: $WEBHOOK_URL"
if [[ $SETUP_SSL == "y" && $SSL_TYPE == "1" ]]; then
    echo
    log_warning "🔒 CERTIFICAT AUTO-SIGNÉ DÉTECTÉ"
    log_info "Votre navigateur affichera un avertissement de sécurité"
    log_info "Actions à effectuer dans votre navigateur :"
    echo "   • Chrome/Edge : Cliquez sur 'Paramètres avancés' puis 'Continuer vers $DOMAIN_NAME'"
    echo "   • Firefox : Cliquez sur 'Paramètres avancés' puis 'Accepter le risque'"
    echo "   • Safari : Cliquez sur 'Afficher les détails' puis 'Visiter ce site web'"
    echo
    log_info "💡 Pour éviter cet avertissement, ajoutez $DOMAIN_NAME à votre fichier hosts :"
    echo "   sudo echo '$(hostname -I | awk '{print $1}') $DOMAIN_NAME' >> /etc/hosts"
fi

# Afficher le statut final
echo
log_info "Statut actuel du service:"
systemctl status n8n --no-pager -l