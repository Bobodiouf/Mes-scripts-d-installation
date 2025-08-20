#!/bin/bash

# Script de désinstallation complète de n8n
# Auteur: Assistant Claude
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

echo "=============================================="
echo "   DÉSINSTALLATION COMPLÈTE DE N8N"
echo "=============================================="
echo
log_warning "⚠️  ATTENTION : Cette opération va supprimer :"
echo "   • Le service n8n"
echo "   • L'utilisateur n8n et son répertoire home"
echo "   • Toutes les données n8n (workflows, exécutions, etc.)"
echo "   • La configuration nginx (si présente)"
echo "   • Les certificats SSL auto-signés"
echo "   • n8n installé globalement via npm"
echo

read -p "Êtes-vous sûr de vouloir continuer ? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    log_info "Désinstallation annulée"
    exit 0
fi

echo
log_info "Début de la désinstallation de n8n..."

# 1. Arrêter et désactiver le service n8n
log_info "Arrêt du service n8n..."
if systemctl is-active --quiet n8n 2>/dev/null; then
    systemctl stop n8n
    log_success "Service n8n arrêté"
else
    log_warning "Service n8n déjà arrêté ou inexistant"
fi

if systemctl is-enabled --quiet n8n 2>/dev/null; then
    systemctl disable n8n
    log_success "Service n8n désactivé"
fi

# 2. Supprimer le fichier de service systemd
if [ -f /etc/systemd/system/n8n.service ]; then
    rm -f /etc/systemd/system/n8n.service
    systemctl daemon-reload
    log_success "Fichier de service systemd supprimé"
fi

# 3. Supprimer la configuration nginx
log_info "Suppression de la configuration nginx..."
if [ -f /etc/nginx/sites-enabled/n8n ]; then
    rm -f /etc/nginx/sites-enabled/n8n
    log_success "Lien symbolique nginx supprimé"
fi

if [ -f /etc/nginx/sites-available/n8n ]; then
    rm -f /etc/nginx/sites-available/n8n
    log_success "Configuration nginx supprimée"
fi

# 4. Supprimer les certificats SSL auto-signés
if [ -d /etc/nginx/ssl ]; then
    if [ -f /etc/nginx/ssl/n8n.crt ] || [ -f /etc/nginx/ssl/n8n.key ]; then
        rm -f /etc/nginx/ssl/n8n.*
        log_success "Certificats SSL auto-signés supprimés"
    fi
    
    if [ -f /etc/nginx/ssl/dhparam.pem ]; then
        rm -f /etc/nginx/ssl/dhparam.pem
        log_success "Paramètres Diffie-Hellman supprimés"
    fi
    
    # Supprimer le répertoire s'il est vide
    if [ -z "$(ls -A /etc/nginx/ssl 2>/dev/null)" ]; then
        rmdir /etc/nginx/ssl
        log_success "Répertoire SSL nginx supprimé"
    fi
fi

# 5. Redémarrer nginx si il est actif et qu'on a modifié sa config
if systemctl is-active --quiet nginx 2>/dev/null; then
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        log_success "Configuration nginx rechargée"
    else
        log_warning "Erreur dans la configuration nginx restante"
    fi
fi

# 6. Supprimer l'utilisateur n8n et son répertoire home
log_info "Suppression de l'utilisateur n8n..."
if id "n8n" &>/dev/null; then
    # Forcer l'arrêt des processus de l'utilisateur n8n
    pkill -u n8n 2>/dev/null || true
    sleep 2
    
    # Supprimer l'utilisateur et son répertoire home
    userdel -r n8n 2>/dev/null || {
        log_warning "Impossible de supprimer l'utilisateur n8n automatiquement"
        log_info "Suppression manuelle du répertoire home..."
        rm -rf /home/n8n
    }
    log_success "Utilisateur n8n et répertoire home supprimés"
else
    log_warning "Utilisateur n8n inexistant"
fi

# 7. Désinstaller n8n via npm
log_info "Désinstallation de n8n via npm..."
if npm list -g n8n >/dev/null 2>&1; then
    npm uninstall -g n8n
    log_success "n8n désinstallé via npm"
else
    log_warning "n8n n'était pas installé globalement via npm"
fi

# 8. Nettoyer le cache npm
log_info "Nettoyage du cache npm..."
npm cache clean --force >/dev/null 2>&1
log_success "Cache npm nettoyé"

# 9. Supprimer le script de gestion
if [ -f /usr/local/bin/n8n-manage ]; then
    rm -f /usr/local/bin/n8n-manage
    log_success "Script de gestion n8n-manage supprimé"
fi

# 10. Nettoyer les tâches cron (renouvellement SSL)
log_info "Nettoyage des tâches cron..."
# Supprimer les lignes contenant certbot du crontab root
(crontab -l 2>/dev/null | grep -v "certbot\|n8n" | crontab -) 2>/dev/null || true
log_success "Tâches cron nettoyées"

# 11. Nettoyer les règles de pare-feu (optionnel)
if command -v ufw &> /dev/null; then
    log_info "Nettoyage des règles de pare-feu..."
    read -p "Voulez-vous supprimer les règles de pare-feu pour n8n (ports 5678, 80, 443) ? (y/N): " CLEAN_FIREWALL
    if [[ $CLEAN_FIREWALL =~ ^[Yy]$ ]]; then
        ufw delete allow 5678/tcp 2>/dev/null || true
        ufw delete allow 80/tcp 2>/dev/null || true
        ufw delete allow 443/tcp 2>/dev/null || true
        log_success "Règles de pare-feu supprimées"
    else
        log_info "Règles de pare-feu conservées"
    fi
fi

# 12. Vérification finale
log_info "Vérification finale..."

ISSUES_FOUND=false

# Vérifier si le service existe encore
if systemctl list-unit-files | grep -q "n8n.service"; then
    log_error "Le service n8n existe encore"
    ISSUES_FOUND=true
fi

# Vérifier si l'utilisateur existe encore
if id "n8n" &>/dev/null; then
    log_error "L'utilisateur n8n existe encore"
    ISSUES_FOUND=true
fi

# Vérifier si n8n est encore installé
if command -v n8n &>/dev/null; then
    log_error "La commande n8n est encore disponible"
    ISSUES_FOUND=true
fi

# Vérifier si des fichiers de configuration restent
if [ -d /home/n8n ] || [ -f /etc/nginx/sites-available/n8n ]; then
    log_error "Des fichiers de configuration persistent"
    ISSUES_FOUND=true
fi

# 13. Proposer des actions de nettoyage supplémentaires
echo
log_info "Actions optionnelles de nettoyage :"

read -p "Voulez-vous désinstaller Node.js (attention : peut affecter d'autres applications) ? (y/N): " REMOVE_NODE
if [[ $REMOVE_NODE =~ ^[Yy]$ ]]; then
    apt remove --purge nodejs npm -y
    apt autoremove -y
    log_success "Node.js désinstallé"
fi

read -p "Voulez-vous désinstaller nginx (attention : peut affecter d'autres sites) ? (y/N): " REMOVE_NGINX
if [[ $REMOVE_NGINX =~ ^[Yy]$ ]]; then
    systemctl stop nginx
    apt remove --purge nginx nginx-common -y
    rm -rf /etc/nginx
    apt autoremove -y
    log_success "nginx désinstallé"
fi

# Résumé final
echo
echo "=============================================="
echo "        DÉSINSTALLATION TERMINÉE"
echo "=============================================="
echo

if [ "$ISSUES_FOUND" = false ]; then
    log_success "✅ n8n a été complètement désinstallé !"
    echo
    echo "Éléments supprimés :"
    echo "  ✓ Service systemd n8n"
    echo "  ✓ Utilisateur n8n et données"
    echo "  ✓ Configuration nginx"
    echo "  ✓ Certificats SSL auto-signés"
    echo "  ✓ Installation npm globale"
    echo "  ✓ Scripts de gestion"
    echo "  ✓ Tâches cron"
else
    log_warning "⚠️  Quelques éléments n'ont pas pu être supprimés automatiquement"
    log_info "Vérifiez les erreurs ci-dessus et nettoyez manuellement si nécessaire"
fi

echo
log_info "Votre système est prêt pour une nouvelle installation de n8n"
log_info "Vous pouvez maintenant relancer votre script d'installation"

# Afficher les informations système utiles
echo
log_info "Informations système actuelles :"
echo "  • Node.js: $(command -v node >/dev/null && node --version || echo 'Non installé')"
echo "  • npm: $(command -v npm >/dev/null && npm --version || echo 'Non installé')"
echo "  • nginx: $(command -v nginx >/dev/null && nginx -v 2>&1 || echo 'Non installé')"
echo "  • Utilisateur n8n: $(id n8n 2>/dev/null && echo 'Existe encore' || echo 'Supprimé')"