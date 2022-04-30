#!/bin/bash

# Nom		: Installation de Guacamole $GUAC_VERSION
# Description	: Script d'installation en local
# Version	: 0.1
# Auteur	: Lyronn
# Date		: 30/04/2022
# Changelog	: 03/04/2022-Creation du script, hash
# Changelog	: 04/04/2022-Vérification gpg
# Changelog	: 07/04/2022-Ajout paquets et installation
# Changelog	: 08/04/2022-Ajout installation guacamole-client, a corriger maven
# Changelog	: 09/04/2022-Ajout java path, installation maven et path
# Changelog	: 28/04/2022-Refonte, installation apache tomcat

set -x
set -e

GUAC_VERSION=1.3.0
JDBC_VERSION=8.0.29

function synchronize_time()
{
	timedatectl set-ntp on
	systemctl restart systemd-timesyncd
	systemctl status systemd-timesyncd --no-pager
}

function download_tools()
{
	apt update && apt upgrade -y
	apt install make vim curl git gnupg -y
}

function required_dependencies()
{
	apt install libcairo2-dev libjpeg62-turbo-dev libpng-dev libtool-bin uuid-dev libossp-uuid-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libvncserver-dev libssl-dev -y
}

function download_guacamole_server()
{
	cd /tmp

	# Téléchargement le tar gz de guacamole-server
	# -O conserve le même nom que le fichier téléchargé
	curl -O https://downloads.apache.org/guacamole/$GUAC_VERSION/source/guacamole-server-$GUAC_VERSION.tar.gz 

	# Téléchargement de la signature gpg
	curl -O https://downloads.apache.org/guacamole/$GUAC_VERSION/source/guacamole-server-$GUAC_VERSION.tar.gz.asc

	# Téléchargement de la signature sha256
	curl -O https://downloads.apache.org/guacamole/$GUAC_VERSION/source/guacamole-server-$GUAC_VERSION.tar.gz.sha256

	# Téléchargement des clés gpg
	curl -O https://downloads.apache.org/guacamole/KEYS

	# Vérification du hash
	sha256sum -c guacamole-server-$GUAC_VERSION.tar.gz.sha256

	# Importation des clés gpp
	gpg --import KEYS
	
	# Vérification de la signature gpg
	gpg --verify guacamole-server-$GUAC_VERSION.tar.gz.asc guacamole-server-$GUAC_VERSION.tar.gz
}

function build_guacamole_server()
{
	mkdir -vp /opt/guacamole/guacamole-server
	cd /tmp
	# Extrait le code source de Guacamole	
	tar xzf guacamole-server-$GUAC_VERSION.tar.gz -C /opt/guacamole/guacamole-server --strip-components=1

	cd /opt/guacamole/guacamole-server

	# Lancer configure pour déterminer les bibliothèques installées
	./configure --with-init-dir=/opt/init.d

	# Lancer make pour démarrer la compilation 
	make

	# Lancer l'installation
	make install

	# Mettre à jour le cache du système des bibliothèques installées
	ldconfig

	# Activer le service
	systemctl enable guacd

	# Démarrer le service
	systemctl start guacd
}

function install_tomcat()
{
	apt install tomcat9 tomcat9-admin tomcat9-common tomcat9-user -y
	# systemctl status tomcat9
}

function guacamole_client()
{
	cd /tmp
	curl -O https://downloads.apache.org/guacamole/$GUAC_VERSION/binary/guacamole-$GUAC_VERSION.war
	curl -O https://downloads.apache.org/guacamole/$GUAC_VERSION/binary/guacamole-$GUAC_VERSION.war.asc
	curl -O https://downloads.apache.org/guacamole/$GUAC_VERSION/binary/guacamole-$GUAC_VERSION.war.sha256
	curl -O https://downloads.apache.org/guacamole/KEYS

	gpg --import KEYS 
	gpg --verify guacamole-$GUAC_VERSION.war.asc guacamole-$GUAC_VERSION.war
	sha256sum -c guacamole-$GUAC_VERSION.war.sha256

	cp guacamole-$GUAC_VERSION.war /opt/guacamole/guacamole.war

	# Lier guacamole client et tomcat
	echo "GUACAMOLE_HOME=/opt/guacamole" >> /opt/default/tomcat9

	# Lien entre l'application guacamole client et le client web
	ln -s /opt/guacamole/guacamole.war /var/lib/tomcat9/webapps

	# Démarrage de tomcat et guacd
	systemctl restart tomcat9
	systemctl restart guacd 
}

install_mariadb()
{
	# Création des dossiers où seront installés les extensions
	mkdir -vp /opt/guacamole/extensions/
	mkdir -vp /opt/guacamole/lib/

	# Installation de mariadb
	apt install mariadb-server mariadb-client -y

	# Création de la bdd guacamole
	mysql -e "CREATE DATABASE guacamole_db;"

	cd /tmp/

	# Téléchargement de l'extension mysql pour Guacamole
	curl -O https://downloads.apache.org/guacamole/$GUAC_VERSION/binary/guacamole-auth-jdbc-$GUAC_VERSION.tar.gz

	tar xzf guacamole-auth-jdbc-$GUAC_VERSION.tar.gz

	# Ajouter les tables dans la bdd
	cat guacamole-auth-jdbc-$GUAC_VERSION/mysql/schema/*.sql | mysql guacamole_db

	# Autoriser Guacamole à accéder à la bdd
	# Création de l'utilisateur
	mysql -e "CREATE USER 'guacamole_user'@'localhost' IDENTIFIED BY 'P@ssw0rd';"

	# Attribution des droits à l'utilisateur guacamole_user
	mysql -e "GRANT SELECT, INSERT, UPDATE, DELETE ON guacamole_db.* TO 'guacamole_user'@'localhost';"

	# Mise à jour de la bdd
	mysql -e "FLUSH PRIVILEGES;"

	# Installation de l'extension
	cp guacamole-auth-jdbc-$GUAC_VERSION/mysql/guacamole-auth-jdbc-mysql-$GUAC_VERSION.jar /opt/guacamole/extensions/

	# Téléchargement du driver JDBC
	wget https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-$JDBC_VERSION.tar.gz

	tar xvzf mysql-connector-java-$JDBC_VERSION.tar.gz

	# Installer le driver pour Guacamole
	cp mysql-connector-java-$JDBC_VERSION/mysql-connector-java-$JDBC_VERSION.jar /opt/guacamole/lib/

	# Ajouter la configuration de mariadb dans guacamole.properties
	cat >> /opt/guacamole/guacamole.properties << EOF
# Hôte et port
guacd-hostname: guacamole.lyronn.local
guacd-port:	4822

# Parmètres MySQL
mysql-hostname: guacamole.lyronn.local	
mysql-port:	3306
mysql-database:	guacamole_db
mysql-username:	guacamole_user
mysql-password:	P@ssw0rd

EOF
	# Lien entre la configuration de guacamole et le serveur tomcat
	ln -s /opt/guacamole/guacamole.properties /usr/share/tomcat9/.guacamole

	systemctl restart tomcat9
	systemctl restart guacd 

}

clear

synchronize_time
download_tools
required_dependencies
download_guacamole_server
build_guacamole_server
install_tomcat
guacamole_client
install_mariadb
