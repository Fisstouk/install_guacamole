#!/bin/bash

# Nom		: Installation de Guacamole 1.4.0
# Description	: Script d'installation en local
# Version	: 0.1
# Auteur	: Lyronn
# Date		: 03/04/2022
# Changelog	: 03/04/2022-Creation du script, hash
# Changelog	: 04/04/2022-Vérification gpg
# Changelog	: 07/04/2022-Ajout paquets et installation
# Changelog	: 08/04/2022-Ajout installation guacamole-client, a corriger maven
# Changelog	: 09/04/2022-Ajout java path, installation maven et path

# Affiche les commandes réalisées
set -x

# Arrête le script dès qu'un erreur survient
set -e

function download_tools()
{
	apt install make vim curl git gnupg -y
}

function download_guacamole_server()
{

	mkdir -vp /opt/guacamole/guacamole-server
	cd /opt/guacamole/guacamole-server

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
	sha256sum -c /opt/guacamole/guacamole-server/guacamole-server-1.4.0.tar.gz.sha256

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

function required_dependencies()
{
	apt install libcairo2-dev \ 			# Utilisé par libguac pour le rendu graphique
		libjpeg62-turbo-dev \			# Support JPEG 
		libpng-dev \				# Ecrit des images PNG, le format principal de Guacamole
		libtool-bin \ 				# Crée des bibliothèques compilées pour installer Guacamole
		uuid-dev \ 				# Permet d'assigner des identifiants uniques aux utilisateurs et connexions
		libossp-uuid-dev \ 
		freerdp2-dev \				# Support de RDP
		libpango1.0-dev \ 			# Support SSH, Kubernetes et telnet
		libssh2-1-dev \ 			# Support SSH et SFTP
		libvncserver-dev \			# Support VNC
		libssl-dev -y				# Support SSL et TLS
}

function build_guacamole_server()
{
	# Extrait le code source de Guacamole	
	tar xzf guacamole-server-1.4.0.tar.gz

	cd guacamole-server-1.4.0

	# Lancer configure pour déterminer les bibliothèques installées
	./configure --with-init-dir=/etc/init.d

	# Lancer make pour démarrer la compilation 
	make

	# Lancer l'installation
	make install

	# Mettre à jour le cache du système des bibliothèques installés
	ldconfig
}

function install_java_jdk()
{
	mkdir -vp /opt/java
	cd /opt/java/

	# Téléchargement de Java jdk
	curl -O https://download.oracle.com/java/18/latest/jdk-18_linux-x64_bin.tar.gz

	# Téléchargement du hash
	curl -O https://download.oracle.com/java/18/latest/jdk-18_linux-x64_bin.tar.gz.sha256

	# Vérification du hash
	# A améliorer: que le hash soit bien formaté
	sha256sum -c /opt/java/jdk-18_linux-x64_bin.tar.gz.sha256

	tar zxvf jdk-18_linux-x64_bin.tar.gz
	rm -v jdk-18_linux-x64_bin.tar.gz
	rm -v jdk-18_linux-x64_bin.tar.gz.sha256

	echo "export JAVA_HOME=/opt/java/jdk-18/" >> ~/.bashrc
	source ~/.bashrc

	cat > /etc/environment << "EOF"
JAVA_HOME=/opt/java/jdk-18
PATH=$PATH:$JAVA_HOME/bin

EOF
	source /etc/environment

}

function install_maven()
{
	mkdir -vp /opt/apache-maven/
	cd /opt/apache-maven/

	# Téléchargement de apache maven
	curl -O https://dlcdn.apache.org/maven/maven-3/3.8.5/binaries/apache-maven-3.8.5-bin.tar.gz

	# Téléchargement du hash
	curl -O https://downloads.apache.org/maven/maven-3/3.8.5/binaries/apache-maven-3.8.5-bin.tar.gz.sha512

	# Téléchargement de la signature
	curl -O https://downloads.apache.org/maven/maven-3/3.8.5/binaries/apache-maven-3.8.5-bin.tar.gz.asc

	# Téléchargement des cles publiques
	curl -O https://downloads.apache.org/maven/KEYS

	sha512sum -c /opt/apache-maven/apache-maven-3.8.5-bin.tar.gz.sha512

	gpg --import KEYS
	gpg --verify apache-maven-3.8.5-bin.tar.gz.asc apache-maven-3.8.5-bin.tar.gz

	tar xzvf apache-maven-3.8.5-bin.tar.gz

	echo "export PATH=/opt/apache-maven/apache-maven-3.8.5/bin:$PATH" >> ~/.bashrc
	source ~/.bashrc
}

function guacamole_client()
{
	mkdir -vp /opt/guacamole/guacamole-client
	cd /opt/guacamole/guacamole-client

	# Téléchargement du client
	curl -O https://downloads.apache.org/guacamole/1.4.0/source/guacamole-client-1.4.0.tar.gz 

	# Téléchargement de la signature gpg
	curl -O https://downloads.apache.org/guacamole/1.4.0/source/guacamole-client-1.4.0.tar.gz.asc

	# Téléchargement du hash
	curl -O https://downloads.apache.org/guacamole/1.4.0/source/guacamole-client-1.4.0.tar.gz.sha256

	# Vérification du hash
	sha256sum -c /opt/guacamole/guacamole-client/guacamole-client-1.4.0.tar.gz.sha256

	# Vérification de la signature gpg
	gpg --verify guacamole-client-1.4.0.tar.gz.asc guacamole-client-1.4.0.tar.gz

	# Extraire le fichier tar
	tar xzf guacamole-client-1.4.0.tar.gz

	cd guacamole-client-1.4.0/

	# Construction de Guacamole client
	mvn package
}

clear
