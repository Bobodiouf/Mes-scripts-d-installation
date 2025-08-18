#!/bin/bash

# Script de purge complète d'un package Debian/Ubuntu
# Auteur : Ismael & GPT
# Date : $(date +"%Y-%m-%d")
# Couleur verte fluo
GREEN="\e[92m"
RESET="\e[0m"

echo "================================================"
echo "   Script de suppression complète d'un package  "
echo "================================================"

# 1. Demande du package
read -rp "Nom exact du package à supprimer : " PACKAGE

# Vérification si le package existe
if ! dpkg -l | grep -qw "$PACKAGE"; then
    echo "Le package '$PACKAGE' n'est pas installé."
    exit 1
fi

# 2. Purge standard du package
read -rp "Voulez-vous purger le package (y/n) ? " PURGE
if [[ "$PURGE" =~ ^[Yy]$ ]]; then
    echo "Suppression complète du package..."
    sudo apt-get purge --auto-remove "$PACKAGE" -y
else
    echo "Suppression simple du package..."
    sudo apt-get remove --auto-remove "$PACKAGE" -y
fi

# 3. Recherche et suppression des fichiers résiduels
read -rp "Voulez-vous supprimer les fichiers résiduels (/etc, /var/lib, /var/log) ? (y/n) : " RESIDUS
if [[ "$RESIDUS" =~ ^[Yy]$ ]]; then
    echo "Recherche et suppression des fichiers liés à $PACKAGE..."
    sudo find /etc/ /var/lib/ /var/log/ -iname "*$PACKAGE*" -exec rm -rvf {} +
fi

# 4. Suppression des dépendances inutiles
echo "Nettoyage des dépendances inutilisées..."
sudo apt-get autoremove -y
sudo apt-get autoclean

# 5. Phase de test
read -rp "Voulez-vous vérifier si le package est bien supprimé ? (y/n) : " TEST
if [[ "$TEST" =~ ^[Yy]$ ]]; then
    if dpkg -l | grep -qw "$PACKAGE"; then
        echo "Le package '$PACKAGE' est encore présent sur le système."
        read -rp "Voulez-vous relancer une purge complète ? (y/n) : " RELANCE
        if [[ "$RELANCE" =~ ^[Yy]$ ]]; then
            sudo apt-get purge --auto-remove "$PACKAGE" -y
        else
            echo "Purge supplémentaire annulée."
        fi
    else
        echo "Le package '$PACKAGE' a bien été supprimé."
    fi
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


echo "Suppression complète de $PACKAGE terminée."
