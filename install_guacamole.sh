#!/bin/bash

# Nom		: Installation de Guacamole 1.4.0
# Description	: Script d'installation en local
# Version	: 0.1
# Auteur	: Lyronn
# Date		: 03/04/2022
# Changelog	: 03/04/2022-Creation du script, hash
# Changelog	: 04/04/2022-Vérification gpg

# Affiche les commandes réalisées
set -x

# Arrête le script dès qu'un erreur survient
set -e

function download_tools()
{
	apt install vim curl git gnupg -y

}

function download_check_hash()
{
	# Téléchargement le tar gz de guacamole-server
	# -O conserve le même nom que le fichier téléchargé
	curl -O https://downloads.apache.org/guacamole/1.4.0/source/guacamole-server-1.4.0.tar.gz

	# Téléchargement de la signature gpg
	curl -O https://downloads.apache.org/guacamole/1.4.0/source/guacamole-server-1.4.0.tar.gz.asc

	# Téléchargement de la signature sha256
	curl -O https://downloads.apache.org/guacamole/1.4.0/source/guacamole-server-1.4.0.tar.gz.sha256

	# Téléchargement des clés gpg
	curl -O https://downloads.apache.org/guacamole/KEYS

	# Vérification du hash
	sha256sum -c ~/guacamole-server-1.4.0.tar.gz.sha256

	# Importation des clés gpp
	gpg --import KEYS
	
	# Vérification de la signature gpg
	gpg --verify guacamole-server-1.4.0.tar.gz.asc guacamole-server-1.4.0.tar.gz

	# Tentative de gestion d'erreur pour le hash
	#SHACHECK=$(sha256sum -c ~/guacamole-server-1.4.0.tar.gz.sha256)

	#while ! $SHACHECK | grep 'OK'
	#do
	#	rm ~/guacamole-server-1.4.0.tar.gz
	#	curl -O https://downloads.apache.org/guacamole/1.4.0/source/guacamole-server-1.4.0.tar.gz
	#done

}

clear
