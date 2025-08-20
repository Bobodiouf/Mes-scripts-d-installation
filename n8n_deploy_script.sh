#!/bin/bash

# Script de déploiement n8n sur Debian 12 avec MariaDB
# Auteur: Ismael Mouloungui && Assistant Claude
# Version: 1.0

set -e  # Arrêter le script en cas d'erreur

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Demander l'URL publique
read -p "URL publique de n8n (ex: https://n8n.mondomaine.com ou http://IP:5678): " WEBHOOK_URL

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
N8N_SECURE_COOKIE=false
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

# 10. Configuration du pare-feu (si ufw est installé)
if command -v ufw &> /dev/null; then
    log_info "Configuration du pare-feu..."
    ufw allow $N8N_PORT/tcp
    log_success "Port $N8N_PORT autorisé dans le pare-feu"
else
    log_warning "ufw non installé, configuration du pare-feu ignorée"
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
sleep 2
if curl -s -o /dev/null -w "%{http_code}" http://localhost:$N8N_PORT | grep -q "200\|401"; then
    log_success "n8n répond correctement sur le port $N8N_PORT"
else
    log_warning "n8n ne semble pas répondre correctement, vérifiez les logs"
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
        echo "n8n redémarré"
        ;;
    status)
        systemctl status n8n
        ;;
    logs)
        journalctl -u n8n -f
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
        echo "Usage: n8n-manage {start|stop|restart|status|logs|update|backup}"
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
echo "- Script de gestion: n8n-manage {start|stop|restart|status|logs|update|backup}"
echo
echo "Fichiers importants:"
echo "- Configuration: $N8N_HOME/.n8n/.env"
echo "- Logs: $N8N_HOME/.n8n/logs/n8n.log"
echo "- Service: /etc/systemd/system/n8n.service"
echo
log_info "Pour accéder à l'interface, ouvrez votre navigateur sur: $WEBHOOK_URL"

# Afficher le statut final
echo
log_info "Statut actuel du service:"
systemctl status n8n --no-pager -l