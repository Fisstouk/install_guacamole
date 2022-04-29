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

set -x
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

	# Activer le service
	systemctl enable guacd

	# Démarrer le service
	systemctl start guacd
}

function install_tomcat()
{
	apt install tomcat9 tomcat9-admin tomcat9-common tomcat9-user -y
	systemtctl status tomcat9
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

	# Création du fichier configuration principal de Guacamole
	cat >> /opt/guacamole/guacamole.properties << EOF
	guacd-hostname: guacamole.lyronn.local
	guacd-port:	4822
	user-mapping:	/opt/guacamole/user-mapping.xml

EOF

	GUAC_PASSWORD=$(echo -n admin | openssl md5)

	cat >> /opt/guacamole/user-mapping.xml << EOF
<user-mapping>

	<!--Authentification et configuration par utilisateur-->
	<authorize username="USERNAME" password="PASSWORD">
		<protocol>vnc</protocol>
		<param name="hostname">localhost</param>
		<param name="port">5900</param>
		<param name="password">VNCPASS</param>
	</authorize>

	<!--Autre utilisateur, mais utilise md5 pour hasher le mdp-->
	<authorize
		username="USERNAME2"
		password="$GUAC_PASSWORD"
		encoding="md5">
	
		<!--Première connexion-->
		<conection name="Hardening">
			<protocol>ssh</protocol>
			<param name="hostname">192.168.1.100</param>
			<param name="port">22</param>
		</connection>
		
		<!--Deuxième connexion-->
		<connection name="otherhost">
			<protocol>vnc</protocol>
			<param name="hostname">otherhost</param>
			<param name="port">5900</param>
			<param name="password">VNCPASS</param>
		</connection>
	</authorize>
</user-mapping>

EOF

	# Lien entre l'application guacamole client et le client web
	ln -s /opt/guacamole/guacamole-1.4.0.war /var/lib/tomcat9/webapps

	# Lien entre la configuration de guacamole et le serveur tomcat
	ln -s /opt/guacamole/guacamole.properties /usr/share/tomcat9/.guacamole

	# Démarrage de tomcat et guacd
	systemctl restart tomcat
	/etc/init.d/guacd start
}

clear

synchronize_time
download_tools
required_dependencies
download_guacamole_server
build_guacamole_server
install_tomcat
guacamole_client
