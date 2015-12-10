#!/bin/bash

# A script that installs dependencies and sets up the development environment for the Ubuntu QATracker

echo "This is an automated script for setting up a dev environment for the Ubuntu QATracker."
echo
read -p "Enter the IP Adress for your Apache server: " SERVER_IP
echo

#### Installation of dependencies
echo "Installing dependencies"

sudo debconf-set-selections <<< "postfix postfix/main_mailer_type select No configuration"
sudo DEBIAN_FRONTEND=noninteractive apt-get -y install php5-pgsql postgresql apache2 drupal7 bzr

#### Setting up Apache2
echo
echo "Setting up Apache server"

sudo sh -c ' cat > /etc/apache2/sites-enabled/000-default.conf <<- _EOF_
	<VirtualHost *:80>
		#NOWEBSTATS
		ServerName      '$SERVER_IP'

		DocumentRoot    /usr/share/drupal7

		# Protect the /scripts directory.
		RewriteEngine on
		RewriteRule   ^/scripts(|/.*) http://%{SERVER_NAME}/ [R=301,L]
	</VirtualHost>
_EOF_'

#### Creating new user
sudo userdel qatracker
# FIXME Find better way to do this
echo -e "qatracker\nqatracker\n\n\n\n\n\ny\n" | sudo adduser qatracker

#### Setting up Drupal7
echo
echo "Configuring Drupal"
cat <<- _EOF1_

	For Drupal setup the following will be chosen:
	* Database: pgsql
	* Connection method: unix socket
	* Authentication method: ident
	* Postgres authentication method: ident
	* Database admin user: "postgres"
	* Username for drupal7: "qatracker"
	* Password for postgres application: will be generated randomly
	* Database name for drupal7: qatracker
_EOF1_

sudo debconf-set-selections <<< "drupal7 drupal7/pgsql/authmethod-user select ident"
sudo debconf-set-selections <<< "drupal7 drupal7/db/app-user string qatracker"
sudo debconf-set-selections <<< "drupal7 drupal7/pgsql/method select unix socket"
sudo debconf-set-selections <<< "drupal7 drupal7/internal/reconfiguring boolean true"
sudo debconf-set-selections <<< "drupal7 drupal7/db/dbname string qatracker"
sudo debconf-set-selections <<< "drupal7 drupal7/pgsql/authmethod-user select ident"
sudo debconf-set-selections <<< "drupal7 drupal7/pgsql/admin-user string postgres"
sudo debconf-set-selections <<< "drupal7 drupal7/database-type select pgsql"

sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure debconf drupal7

#### Installing QATracker modules
echo "Installing QATracker modules"
bzr branch lp:ubuntu-qa-website
sudo cp -R ubuntu-qa-website/modules/* /usr/share/drupal7/modules/
rm -rf ubuntu-qa-website

#### Adding OpenID modules
echo "Installing OpenID modules"
bzr branch lp:~ubuntu-qa-website-devel/ubuntu-qa-website/drupal-launchpad-7.x drupal-launchpad
bzr branch lp:~ubuntu-drupal-devs/drupal-teams/7.x-dev/ drupal-teams 
sudo cp -R drupal-teams drupal-launchpad /usr/share/drupal7/modules
rm -rf drupal-launchpad drupal-teams

#### Applying theme
echo "Installing Antonelli theme"
wget http://ftp.drupal.org/files/projects/antonelli-7.x-1.0-rc1.tar.gz
tar xvzf antonelli-7.x-1.0-rc1.tar.gz 
sudo cp -R antonelli /usr/share/drupal7/themes/
rm -rf antonelli-7.x-1.0-rc1.tar.gz antonelli

#### Activate Apache
echo "Activating Apache"
sudo a2enmod rewrite
sudo service apache2 restart

#### Launching Drupal Wizard
URL="http://localhost/install.php"

echo "You will be redirected to your browser to finish with the setup of the website:"
cat <<- _EOF_
	In the wizard, choose following:
	* Modules: Standard
	* Language: English
	Site Information
	* Name: IP or anything you wish
	* email: anything you wish (root@localhost.com)
	* username and password of your choosing

	In modules tab, do following:
	* Uncheck the search module
	* Under Other, enable Launchpad OpenID and OpenID Teams if desired
	* Under Ubuntu QA, enable all modules

	To set theme (optional), in appearance tab:
	* Find Antonelli and click 'enable and set default'
	* Click settings
	* Set color for Link color, Header top and Header bottom to #DD4814.
	* Uncheck the site name
_EOF_

# Opening in browser
if which xdg-open > /dev/null
then
  xdg-open $URL
elif which gnome-open > /dev/null
then
  gnome-open $URL
fi

echo "For additional information on how to set up your website, please visit: https://wiki.ubuntu.com/Testing/ISO/DevEnv"
echo
echo "Done"