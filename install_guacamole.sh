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
# Changelog	: 28/04/2022-Refonte, installation apache tomcat

# Affiche les commandes réalisées
set -x

# Arrête le script dès qu'un erreur survient
set -e

function synchronize_time()
{
	timedatectl set-ntp on
	systemctl restart systemd-timesyncd
	systemctl status systemd-timesyncd --no-pager
}

function download_tools()
{
	apt update && apt upgrade -y
	apt install make vim curl git gnupg ufw -y
}

function required_dependencies()
{
	apt install libcairo2-dev libjpeg62-turbo-dev libpng-dev libtool-bin uuid-dev libossp-uuid-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libvncserver-dev libssl-dev -y
}

function install_tomcat()
{
	# Installation de Java Developement Kit
	apt install default-jdk -y

	# Création de l'utilisateur tomcat
	# Sans privilège, personne ne peut s'y connecter
	groupadd tomcat
	useradd -s /bin/false -g tomcat -d /opt/tomcat tomcat

	# Téléchargement de Tomcat
	cd /tmp
	curl -O https://downloads.apache.org/tomcat/tomcat-10/v10.0.20/bin/apache-tomcat-10.0.20.tar.gz
	curl -O https://downloads.apache.org/tomcat/tomcat-10/v10.0.20/bin/apache-tomcat-10.0.20.tar.gz.asc
	curl -O https://downloads.apache.org/tomcat/tomcat-10/v10.0.20/bin/apache-tomcat-10.0.20.tar.gz.sha512
	curl -O https://downloads.apache.org/tomcat/tomcat-10/v10.0.20/KEYS

	# Vérification de l'authenticité des fichiers téléchargés
	gpg --import KEYS
	gpg --verify apache-tomcat-10.0.20.tar.gz.asc apache-tomcat-10.0.20.tar.gz
	sha512sum -c apache-tomcat-10.0.20.tar.gz.sha512

	mkdir -vp /opt/tomcat
	# Strip-components extrait tous les fichiers dans le dossier indiqué
	tar xzvf apache-tomcat-10.0.20.tar.gz -C /opt/tomcat --strip-components=1

	# Autorisations de l'utilisateur tomcat
	cd /opt/tomcat
	chgrp -R tomcat /opt/tomcat
	chmod -R g+r conf
	chmod g+x conf
	chown -R tomcat webapps/ work/ temp/ logs/

	cat >> /etc/systemd/system/tomcat.service << EOF
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/lib/jvm/java-1.11.0-openjdk-amd64
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'

ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh

User=tomcat
Group=tomcat
UMask=0007
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target

EOF
	ufw allow 8080
	systemctl enable tomcat

	systemctl daemon-reload
	systemctl start tomcat
	systemctl status tomcat

}

function download_guacamole_server()
{
	cd /tmp

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
	sha256sum -c guacamole-server-1.4.0.tar.gz.sha256

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

function build_guacamole_server()
{
	mkdir -vp /opt/guacamole/guacamole-server
	cd /tmp
	# Extrait le code source de Guacamole	
	tar xzf guacamole-server-1.4.0.tar.gz -C /opt/guacamole/guacamole-server --strip-components=1

	cd /opt/guacamole/guacamole-server

	# Lancer configure pour déterminer les bibliothèques installées
	./configure --with-init-dir=/etc/init.d

	# Lancer make pour démarrer la compilation 
	make

	# Lancer l'installation
	make install

	# Mettre à jour le cache du système des bibliothèques installés
	ldconfig
}

function guacamole_client()
{
	cd /tmp
	curl -O https://downloads.apache.org/guacamole/1.4.0/binary/guacamole-1.4.0.war
	curl -O https://downloads.apache.org/guacamole/1.4.0/binary/guacamole-1.4.0.war.asc
	curl -O https://downloads.apache.org/guacamole/1.4.0/binary/guacamole-1.4.0.war.sha256
	curl -O https://downloads.apache.org/guacamole/KEYS

	gpg --import KEYS 
	gpg --verify guacamole-1.4.0.war.asc guacamole-1.4.0.war
	sha256sum -c guacamole-1.4.0.war.sha256

	cp guacamole-1.4.0.war /opt/guacamole/

	ln -s /opt/guacamole/guacamole-1.4.0.war /opt/tomcat/webapps

	# Démarrage de tomcat et guacd
	systemctl restart tomcat
	/etc/init.d/guacd start
}

clear

synchronize_time
download_tools
required_dependencies
install_tomcat
download_guacamole_server
build_guacamole_server
guacamole_client
