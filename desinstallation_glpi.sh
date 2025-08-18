#!/bin/bash
set -e
# Couleur verte fluo
GREEN="\e[92m"
RESET="\e[0m"

echo "Script de désinstallation complète de GLPI"

# Demande à l'utilisateur où est installé GLPI
read -rp "Chemin complet du dossier GLPI (ex: /var/www/html/glpi) : " GLPI_PATH

if [ ! -d "$GLPI_PATH" ]; then
  echo "Le dossier '$GLPI_PATH' n'existe pas. Vérifie le chemin."
  exit 1
fi

# Supprimer les fichiers GLPI
read -rp "Supprimer les fichiers GLPI dans $GLPI_PATH ? (y/n) : " DEL_FILES
if [[ "$DEL_FILES" =~ ^[Yy]$ ]]; then
  sudo rm -rf "$GLPI_PATH"
  echo "Fichiers GLPI supprimés."
else
  echo "Fichiers GLPI non supprimés."
fi

# Base de données MariaDB
read -rp "Nom de la base de données GLPI à supprimer : " DB_NAME
read -rp "Nom utilisateur MariaDB de GLPI à supprimer : " DB_USER

read -rp "Supprimer la base de données et l'utilisateur MariaDB ? (y/n) : " DEL_DB
if [[ "$DEL_DB" =~ ^[Yy]$ ]]; then
  sudo mysql -u root -p -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; DROP USER IF EXISTS '$DB_USER'@'%'; FLUSH PRIVILEGES;"
  echo "Base et utilisateur MariaDB supprimés."
else
  echo "Base et utilisateur MariaDB non supprimés."
fi

# Configuration serveur web
read -rp "Ton serveur web est-il nginx ou apache ? (nginx/apache) : " WEB_SERVER

if [[ "$WEB_SERVER" == "nginx" ]]; then
  read -rp "Nom du fichier de configuration nginx à supprimer (ex: glpi.conf) : " NG_CONF
  read -rp "Supprimer la config nginx /etc/nginx/sites-available/$NG_CONF et sites-enabled/$NG_CONF ? (y/n) : " DEL_NGINX
  if [[ "$DEL_NGINX" =~ ^[Yy]$ ]]; then
    sudo rm -f "/etc/nginx/sites-available/$NG_CONF" "/etc/nginx/sites-enabled/$NG_CONF"
    sudo systemctl reload nginx
    echo "Configuration nginx supprimée et rechargée."
  else
    echo "Configuration nginx non supprimée."
  fi

elif [[ "$WEB_SERVER" == "apache" ]]; then
  read -rp "Nom du fichier de configuration apache à supprimer (ex: glpi.conf) : " AP_CONF
  read -rp "Désactiver et supprimer la config apache /etc/apache2/sites-available/$AP_CONF ? (y/n) : " DEL_APACHE
  if [[ "$DEL_APACHE" =~ ^[Yy]$ ]]; then
    sudo a2dissite "$AP_CONF"
    sudo rm -f "/etc/apache2/sites-available/$AP_CONF"
    sudo systemctl reload apache2
    echo "Configuration apache désactivée, supprimée et rechargée."
  else
    echo "Configuration apache non supprimée."
  fi
else
  echo "Serveur web inconnu. Ignorer la suppression config serveur."
fi

# Suppression optionnelle des paquets liés
read -rp "Voulez-vous supprimer PHP, MariaDB, Nginx et leurs dépendances ? (y/n) : " DEL_PKGS
if [[ "$DEL_PKGS" =~ ^[Yy]$ ]]; then
  sudo apt remove --purge -y php* mariadb-server nginx apache2
  sudo apt autoremove --purge -y
  echo "Paquets PHP, MariaDB, Nginx, Apache supprimés."
else
  echo "Paquets non supprimés."
fi
sudo clear

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

echo "Désinstallation GLPI terminée."
