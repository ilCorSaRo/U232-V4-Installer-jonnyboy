#!/usr/bin/env bash
#set these and avoid some prompts
USERNAME=""		#username for mysql
PASS=""			#password for mysql user
DBNAME=""		#database name
MAILNAME=""		#email address for fail2ban
IPADDY=""		#fully qualified domain name or routable ip
VERSION=""		#Ubuntu version codename utopic, trusty, precise

if [[ $EUID -ne 0 && whoami != $SUDO_USER ]]; then
	export script=`basename $0`
	echo
	echo -e "\033[1;31mYou must run this script as a user using
	sudo ./${script}\033[0m" 1>&2
	echo
	exit
fi

UPDATEALL='apt-get -yqq update'

clear
read -p "This script uses color by default.
Enter N or n to not use color in the messages.
Any other key to use color.

" -n 1 -r

if [[ $REPLY =~ ^[Nn]$ ]]
then
	YELLOW=""
	RED=""
	CLEAR=""
else
	YELLOW="\033[1;33m"
	RED="\033[1;31m"
	CLEAR="\033[00m"
fi
clear

echo -e "${YELLOW}|---------------------------------------------------------------------------|
| https://github.com/Bigjoos/                                               |
|---------------------------------------------------------------------------|
| Licence Info: GPL                                                         |
|---------------------------------------------------------------------------|
| Copyright (C) 2010 U-232 V4                                               |
|---------------------------------------------------------------------------|
| A bittorrent tracker source based on TBDev.net/tbsource/bytemonsoon.      |
|---------------------------------------------------------------------------|
| Project Leaders: Mindless,putyn.                                          |
|---------------------------------------------------------------------------|
| Original Script by swizzles, modified by jonnyboy                         |
|---------------------------------------------------------------------------|

We are about to install all the basics that you require to get v4 to work.
I am assuming you have at least a basic understanding of servers!!!!!!!!!!!

All that is needed for this script to WORK is a base server install.

This has been written and tested for Ubuntu 14.04 DEDICATED SERVERS. It will
work providing you follow all the instructions.

1. This script will install U-232-V4 from
   here >> https://github.com/jonnyboy/U232-V4-Installer.git.
2. It will install nginx, percona, php5-fpm, memcached, opcache, adminer,
   fail2ban and finally xbt.

This has been made as easy as possible with very little interaction from you

ENTER Y or y to continue:
$CLEAR"
read -p "
" -n 1 -r

if [[ $REPLY =~ ^[Yy]$ ]]
then
clear

if [[ $USERNAME == "" ]]; then
	echo -e "${YELLOW}We will need to create a MySQL user and database for U232.
	Please enter a username to be created.$CLEAR"
	read NAME
	if [[ $NAME == "" ]]; then
		USERNAME="admin"
	else
		USERNAME=$NAME
	fi
fi

if [[ $PASS == "" ]]; then
	echo -e "${YELLOW}We need to give \"$USERNAME\" a password.
	Please enter a password.$CLEAR"
	read -s PW
	if [[ $PW == "" ]]; then
		PASS="admin"
	else
		PASS=$PW
	fi
fi

if [[ $DBNAME == "" ]]; then
	echo -e "${YELLOW}Please enter the database name to be created.$CLEAR"
	read DB
	if [[ $DB == "" ]]; then
		DBNAME="admin"
	else
		DBNAME=$DB
	fi
fi

if [[ $MAILNAME == "" ]]; then
	echo -e "${YELLOW}Please enter an email address for fail2ban to send mail to.$CLEAR"
	read MAIL
	if [[ $MAIL == "" ]]; then
		MAILNAME="$SUDO_USER"
	else
		MAILNAME=$MAIL
	fi
fi
clear

echo "USERNAME = $USERNAME"
echo "PASS	 = $PASS"
echo "DBNAME   = $DBNAME"
echo "MAILNAME = $MAILNAME"
echo "IPADDY   = $IPADDY"

echo -e "${YELLOW}Last chance before we begin. If any of the above is not correct, press N to exit.

ENTER Y or y to continue:
$CLEAR"
read -p "
" -n 1 -r

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	exit
fi
clear

echo -e "${YELLOW}Updating your system before we begin.$CLEAR"
sleep 5
$UPDATEALL
apt-get -yqq upgrade
updatedb
clear

echo -e "${YELLOW}Removing Apparmor.\n$CLEAR"
/etc/init.d/apparmor stop
/etc/init.d/apparmor teardown
update-rc.d -f apparmor remove
apt-get purge -yqq apparmor* apparmor-utils
clear

echo -e "${YELLOW}Installing PPA's.\n$CLEAR"
apt-get install -yqq python-software-properties software-properties-common git
add-apt-repository -y ppa:nginx/stable
add-apt-repository -y ppa:ondrej/php5-5.6
add-apt-repository -y ppa:pi-rho/dev
$UPDATEALL
clear

echo -e "${YELLOW}We will install Percona XtraDB Server first, if it is not already installed.\n$CLEAR"
sleep 5
if [[ $VERSION == "" ]]; then
	VERSION=$(lsb_release -a | grep Codename: | awk -F : '{print $2}')
fi

# Increase open files limit
echo "* soft nofile 10000
* hard nofile 10000" >> /etc/security/limits.conf
echo "session required pam_limits.so" >> /etc/pam.d/common-session
echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive

gpg --keyserver  hkp://keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A
gpg -a --export CD2EFD2A | apt-key add -
sed -i 's/deb http:\/\/ftp.osuosl.org/#deb http:\/\/ftp.osuosl.org/' /etc/apt/sources.list
sed -i 's/deb-src http:\/\/ftp.osuosl.org/#deb-src http:\/\/ftp.osuosl.org/' /etc/apt/sources.list
sed -i 's/#deb http:\/\/repo.percona.com/deb http:\/\/repo.percona.com/' /etc/apt/sources.list
sed -i 's/#deb-src http:\/\/repo.percona.com/deb-src http:\/\/repo.percona.com/' /etc/apt/sources.list
if ! grep -q '#Percona' "/etc/apt/sources.list" ; then
	echo "" | tee -a /etc/apt/sources.list
	echo "#Percona" >> /etc/apt/sources.list
	echo "deb http://repo.percona.com/apt $VERSION main" >>/etc/apt/sources.list
	echo "deb-src http://repo.percona.com/apt $VERSION main" >> /etc/apt/sources.list
fi

#pin percona to ensure proper dependancies are installed
echo "Package: *
Pin: release o=Percona Development Team
Pin-Priority: 1001
" > /etc/apt/preferences.d/00percona.pref

# set to non interactive
export DEBIAN_FRONTEND=noninteractive

$UPDATEALL
apt-get install -yqq percona-server-client-5.6 percona-server-server-5.6 percona-toolkit
mkdir -p /etc/mysql
wget --no-check-certificate https://raw.githubusercontent.com/jonnyboy/U232-V4-Installer/master/config/my.cnf -O /etc/mysql/my.cnf
service mysql restart
clear

echo -e "${YELLOW}If this is the first time installing Percona or MySQL, then your
MySQL password for root is currently empty, meaning no password has been set."
echo -e "Adding Percona functions: to install, press enter."
echo -e "${RED}To NOT install, type anything for the password and press enter.\n\n$CLEAR"
echo -e "${YELLOW}mysql -uroot -p -e \"CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so'\"$CLEAR"
mysql -uroot -p -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so'"
echo -e "${YELLOW}mysql -uroot -p -e \"CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so'\"$CLEAR"
mysql -uroot -p -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so'"
echo -e "${YELLOW}mysql -uroot -p -e \"CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so'\"$CLEAR"
mysql -uroot -p -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so'"

clear
echo -e "${YELLOW}REMEMBER THE PASSWORD YOU INPUT HERE AS YOU WILL NEED IT FOR YOUR CONF FILES LATER!"
echo -e "IT IS NOT RECOMMENDED TO LEAVE THE PASSWORD BLANK!$CLEAR"
mysql -uroot -e "CREATE USER \"$USERNAME\"@'localhost' IDENTIFIED BY \"$PASS\";CREATE DATABASE $DBNAME;GRANT ALL PRIVILEGES ON $DBNAME . * TO $USERNAME@localhost;FLUSH PRIVILEGES;"
mysql_secure_installation
sleep 1
clear

if [[ $IPADDY == "" ]]; then
	echo -e "${YELLOW}Nginx needs to have the ip or FQDN of the server you are installing to.
	If your installing remotely, localhost will not work in most cases.
	Enter the ip or FQDN of this server.
	Detected IP's and hostname:$CLEAR"
	hostname
	/sbin/ifconfig | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'
	netcat icanhazip.com 80 <<< $'GET / HTTP/1.0\nHost: icanhazip.com\n\n' | tail -n1

	echo
	read IPADDY
fi

apt-get install -yqq nginx-extras apache2-utils
mkdir -p /var/log/nginx
chmod 755 /var/log/nginx
wget --no-check-certificate https://raw.githubusercontent.com/jonnyboy/U232-V4-Installer/master/config/tracker -O /etc/nginx/sites-available/tracker
sed -i "s/root.*$/root \/var\/www\/$IPADDY\/;/" /etc/nginx/sites-available/tracker
wget --no-check-certificate https://raw.githubusercontent.com/jonnyboy/U232-V4-Installer/master/config/nginx.conf -O /etc/nginx/nginx.conf
CORES=`cat /proc/cpuinfo | grep processor | wc -l`
sed -i "s/^worker_processes.*$/worker_processes $CORES;/" /etc/nginx/nginx.conf
sed -i "s/localhost/$IPADDY/" /etc/nginx/sites-available/tracker
if ! grep -q 'fastcgi_index index.php;' "/etc/nginx/fastcgi_params" ; then
	echo "" >> /etc/nginx/fastcgi_params
	echo "fastcgi_index index.php;" | tee -a /etc/nginx/fastcgi_params
fi
if ! grep -q 'fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' "/etc/nginx/fastcgi_params" ; then
	echo "fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;" | tee -a /etc/nginx/fastcgi_params
fi

if [ -f "/etc/nginx/sites-enabled/default" ]; then
	unlink /etc/nginx/sites-enabled/default
fi
ln -sf /etc/nginx/sites-available/tracker /etc/nginx/sites-enabled/tracker

clear

echo -e "${YELLOW}Installing PHP, PHP-FPM.$CLEAR"
apt-get install -yqq php5-fpm
apt-get install -yqq php5 php5-dev php-pear php5-curl php5-json php5-xdebug memcached php5-memcache php5-mcrypt php5-mysqlnd php5-imagick
#not sure these are needed will add back as proven needed
#php5-gd php5-idn php5-imap php5-mhash php5-ming php5-ps php5-pspell php5-recode php5-tidy php5-xmlrpc php5-xsl php5-cgi php5-geoip
apt-get -yqq install libpcre3 libpcre3-dev unzip htop tmux
apt-get -yqq install cmake g++ libboost-date-time-dev libboost-dev libboost-filesystem-dev libboost-program-options-dev libboost-regex-dev libboost-serialization-dev libmysqlclient15-dev make subversion zlib1g-dev
sed -i 's/max_execution_time.*$/max_execution_time = 180/' /etc/php5/cli/php.ini
sed -i 's/max_execution_time.*$/max_execution_time = 180/' /etc/php5/fpm/php.ini
sed -i 's/memory_limit.*$/memory_limit = 100M/' /etc/php5/cli/php.ini
sed -i 's/memory_limit.*$/memory_limit = 100M/' /etc/php5/fpm/php.ini
sed -i 's/[;?]date.timezone.*$/date.timezone = America\/New_York/' /etc/php5/cli/php.ini
sed -i 's/[;?]date.timezone.*$/date.timezone = America\/New_York/' /etc/php5/fpm/php.ini
sed -i 's/[;?]cgi.fix_pathinfo.*$/cgi.fix_pathinfo = 0/' /etc/php5/fpm/php.ini
sed -i 's/[;?]cgi.fix_pathinfo.*$/cgi.fix_pathinfo = 0/' /etc/php5/cli/php.ini
sed -i 's/short_open_tag.*$/short_open_tag = Off/' /etc/php5/fpm/php.ini
sed -i 's/short_open_tag.*$/short_open_tag = Off/' /etc/php5/cli/php.ini
sed -i 's/display_errors.*$/display_errors = On/' /etc/php5/fpm/php.ini
sed -i 's/display_errors.*$/display_errors = On/' /etc/php5/cli/php.ini
sed -i 's/display_startup_errors.*$/display_startup_errors = On/' /etc/php5/fpm/php.ini
sed -i 's/display_startup_errors.*$/display_startup_errors = On/' /etc/php5/cli/php.ini

sed -i 's/listen = \/var\/run\/php5-fpm.sock/;listen = \/var\/run\/php5-fpm.sock\nlisten = 127.0.0.1:9000/' /etc/php5/fpm/pool.d/www.conf
sed -i 's/[;?]listen.backlog.*$/listen.backlog = 65535/' /etc/php5/fpm/pool.d/www.conf

# Enable mcrypt extension
ln -s /etc/php5/mods-available/mcrypt.ini /etc/php5/fpm/conf.d/20-mcrypt.ini
ln -s /etc/php5/mods-available/mcrypt.ini /etc/php5/cli/conf.d/20-mcrypt.ini

clear
echo -e "${YELLOW}Enabling opcache$CLEAR"
sleep 2
sed -i 's/[;?]opcache.enable=.*$/opcache.enable=1/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.enable=.*$/opcache.enable=1/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.enable_cli=.*$/opcache.enable_cli=1/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.enable_cli=.*$/opcache.enable_cli=1/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.memory_consumption=.*$/opcache.memory_consumption=128/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.memory_consumption=.*$/opcache.memory_consumption=128/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.interned_strings_buffer=.*$/opcache.interned_strings_buffer=8/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.interned_strings_buffer=.*$/opcache.interned_strings_buffer=8/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.max_accelerated_files=.*$/opcache.max_accelerated_files=4000/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.max_accelerated_files=.*$/opcache.max_accelerated_files=4000/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.max_wasted_percentage=.*$/opcache.max_wasted_percentage=5/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.max_wasted_percentage=.*$/opcache.max_wasted_percentage=5/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.use_cwd=.*$/opcache.use_cwd=1/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.use_cwd=.*$/opcache.use_cwd=1/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.validate_timestamps=.*$/opcache.validate_timestamps=1/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.validate_timestamps=.*$/opcache.validate_timestamps=1/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.revalidate_freq=.*$/opcache.revalidate_freq=60/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.revalidate_freq=.*$/opcache.revalidate_freq=60/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.fast_shutdown=.*$/opcache.fast_shutdown=1/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.fast_shutdown=.*$/opcache.fast_shutdown=1/' /etc/php5/cli/php.ini
sed -i 's/[;?]opcache.save_comments=.*$/opcache.save_comments=0/' /etc/php5/fpm/php.ini
sed -i 's/[;?]opcache.save_comments=.*$/opcache.save_comments=0/' /etc/php5/cli/php.ini
clear

echo -e "${YELLOW}Installing Fail2Ban (posted by Payaa).$CLEAR"
apt-get install -yqq fail2ban
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
echo "[DEFAULT]

bantime  = 600
destemail = $MAILNAME
action = %(action_mwl)s


[ssh]

enabled = true
port	= ssh
filter  = sshd
logpath  = /var/log/auth.log
maxretry = 5

#
#Nginx configuration
#

[nginx]

enabled = true
port	= http,https
filter  = apache-auth
logpath = /var/log/nginx*/*error.log
maxretry = 6

[nginx-noscript]

enabled = false
port	= http,https
filter  = apache-noscript
logpath = /var/log/nginx*/*error.log
maxretry = 6

[nginx-overflows]

enabled = false
port	= http,https
filter  = apache-overflows
logpath = /var/log/nginx*/*error.log
maxretry = 2

[apache-badbots]

enabled  = true
port	= http,http
filter   = apache-badbots
logpath  = /var/log/nginx*/*access.log
bantime  = 172800
maxretry = 1" > /etc/fail2ban/jail.local
service fail2ban restart
sleep 3
clear

if [ ! -f "/etc/ssl/nginx/conf/server.key" ] || [ ! -f "/etc/ssl/nginx/conf/server.crt" ] || [ ! -f "/etc/ssl/nginx/conf/server.csr" ]; then
	echo -e "${YELLOW}Create a self-signed ssl certificate.$CLEAR"
	mkdir -p /etc/ssl/nginx/conf
	cd /etc/ssl/nginx/conf
	echo -e "${YELLOW}Enter a Secure password:$CLEAR"
	openssl genrsa -des3 -out server.key 4096
	echo -e "${YELLOW}Re-enter a Secure password again:$CLEAR"
	openssl req -new -key server.key -out server.csr
	cp server.key server.key.org
	echo -e "${YELLOW}Re-enter the Secure password one more time:$CLEAR"
	openssl rsa -in server.key.org -out server.key
	openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt
fi

unset DEBIAN_FRONTEND
dpkg-reconfigure tzdata
clear
echo -e "${YELLOW}PHP timezone was set to New York, you may wish to change that.$CLEAR"

#get user home folder
export USER_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)

wget --no-check-certificate https://raw.githubusercontent.com/jonnyboy/U232-V4-Installer/master/config/tmux.conf -O $USER_HOME/.tmux.conf
wget --no-check-certificate https://raw.githubusercontent.com/jonnyboy/U232-V4-Installer/master/config/bashrc -O $USER_HOME/.bashrc
cp /etc/nanorc $USER_HOME/.nanorc
sed -i -e 's/^# include/include/' $USER_HOME/.nanorc
sed -i -e 's/^# set tabsize 8/set tabsize 4/' $USER_HOME/.nanorc
sed -i -e 's/^# set historylog/set historylog/' $USER_HOME/.nanorc
ln -sf $USER_HOME/.nanorc /root/
clear

echo -e "${YELLOW}Configuring OpenNTPD$CLEAR"
ntpdate pool.ntp.org
apt-get install -yqq openntpd
mv /etc/openntpd/ntpd.conf /etc/openntpd/ntpd.conf.orig
echo 'server 0.us.pool.ntp.org' >> /etc/openntpd/ntpd.conf
echo 'server 1.us.pool.ntp.org' >> /etc/openntpd/ntpd.conf
echo 'server 2.us.pool.ntp.org' >> /etc/openntpd/ntpd.conf
echo 'server 3.us.pool.ntp.org' >> /etc/openntpd/ntpd.conf
service openntpd restart
sleep 5
clear

echo -e "${YELLOW}Creating .my.cnf$CLEAR"
echo "[client]
user=$USERNAME
password=$PASS

[mysql]
user=$USERNAME
password=$PASS
database=$DBNAME
" > $USER_HOME/.my.cnf
chmod 600 $USER_HOME/.my.cnf
clear

echo -e "${YELLOW}Now we download the Site Source:
and do all the unzips and copy site to /var/www/$IPADDY,
then we do the stuff like chmods etc.$CLEAR"
sleep 3

cd $USER_HOME
#wget https://github.com/Bigjoos/U-232-V4/archive/master.zip -O master.zip
#unzip -oqq master.zip
#use my git
mkdir $USER_HOME/src
cd $USER_HOME/src
git clone https://github.com/jonnyboy/U-232-V4.git U-232-V4
cd $USER_HOME/src/U-232-V4
tar -zxf pic.tar.gz
tar -zxf GeoIP.tar.gz
tar -zxf javairc.tar.gz
mkdir -p /var/www/$IPADDY/
cd /var/www/
mkdir -p bucket/avatar
cd bucket
cp $USER_HOME/src/U-232-V4/torrents/.htaccess .
cp $USER_HOME/src/U-232-V4/torrents/index.* .
cd avatar
cp $USER_HOME/src/U-232-V4/torrents/.htaccess .
cp $USER_HOME/src/U-232-V4/torrents/index.* .
cd $USER_HOME
chmod -R 777 /var/www/bucket
cp -ar $USER_HOME/src/U-232-V4/* /var/www/$IPADDY/
chmod -R 777 /var/www/$IPADDY/cache
chmod 777 /var/www/$IPADDY/dir_list
chmod 777 /var/www/$IPADDY/uploads
chmod 777 /var/www/$IPADDY/uploadsub
chmod 777 /var/www/$IPADDY/imdb
chmod 777 /var/www/$IPADDY/imdb/cache
chmod 777 /var/www/$IPADDY/imdb/images
chmod 777 /var/www/$IPADDY/include
chmod 777 /var/www/$IPADDY/include/backup
chmod 777 /var/www/$IPADDY/include/settings
echo > /var/www/$IPADDY/include/settings/settings.txt
chmod 777 /var/www/$IPADDY/include/settings/settings.txt
chmod 777 /var/www/$IPADDY/install
chmod 777 /var/www/$IPADDY/install/extra
chmod 777 /var/www/$IPADDY/install/extra/config.xbtsample.php
chmod 777 /var/www/$IPADDY/install/extra/ann_config.xbtsample.php
chmod 777 /var/www/$IPADDY/install/extra/config.phpsample.php
chmod 777 /var/www/$IPADDY/install/extra/ann_config.phpsample.php
mkdir /var/www/$IPADDY/logs
chmod 777 /var/www/$IPADDY/logs
chmod 777 /var/www/$IPADDY/torrents
clear

echo -e "${YELLOW}Now the biggy, to install xbt so your site can fly...lol
Time to grab the goodies and put them in root, away from prying eyes. (REMEMBER YOU CAN PUT THIS ANYWHERE YOU WANT)$CLEAR"
sleep 2
cd /root/
svn co http://xbt.googlecode.com/svn/trunk/xbt/misc xbt/misc
svn co http://xbt.googlecode.com/svn/trunk/xbt/Tracker xbt/Tracker
clear

echo -e "${YELLOW}Now for xbt. We will now copy the custom server.cpp and server.h to the TRACKER folder$CLEAR"
sleep 2
cp -R /var/www/$IPADDY/XBT/{server.cpp,server.h,xbt_tracker.conf}  /root/xbt/Tracker/
echo -e "${YELLOW}RIGHT - now we add your mysql connect details to xbt_tracker.conf$CLEAR"
sed -i "s/^mysql_user.*$/mysql_user=$USERNAME/" /root/xbt/Tracker/xbt_tracker.conf
sed -i "s/^mysql_password.*$/mysql_password=$PASS/" /root/xbt/Tracker/xbt_tracker.conf
sed -i "s/^mysql_database.*$/mysql_database=$DBNAME/" /root/xbt/Tracker/xbt_tracker.conf
clear

echo -e "${YELLOW}Now to install the daemon. Be patient as this could take a few minutes$CLEAR"
sleep 2
cd /root/xbt/Tracker/
./make.sh
clear

cd /root/xbt/Tracker
./xbt_tracker
sleep 3
clear

wget --no-check-certificate https://raw.githubusercontent.com/jonnyboy/U232-V4-Installer/master/config/check_status.sh -O $USER_HOME/check_status.sh
chmod a+x $USER_HOME/check_status.sh

#cd /var/www/$IPADDY/
#wget http://downloads.sourceforge.net/project/phpmyadmin/phpMyAdmin/4.2.9/phpMyAdmin-4.2.9-all-languages.tar.gz
#tar -xf phpMyAdmin-4.2.9-all-languages.tar.gz
#mv phpMyAdmin-4.2.9-all-languages phpmyadmin
#rm phpMyAdmin-4.2.9-all-languages.tar.gz
#cd phpmyadmin
#mkdir -p config
#chmod o+rw config

mkdir -p /var/www/$IPADDY/adminer/plugins/
wget http://downloads.sourceforge.net/adminer/adminer-4.1.0-mysql.php -O /var/www/$IPADDY/adminer/adminer.php
wget https://raw.github.com/vrana/adminer/master/designs/price/adminer.css -O /var/www/$IPADDY/adminer/adminer.css
wget https://raw.github.com/vrana/adminer/master/plugins/plugin.php -O /var/www/$IPADDY/adminer/plugins/plugin.php
wget https://raw.github.com/vrana/adminer/master/plugins/edit-calendar.php -O /var/www/$IPADDY/adminer/plugins/edit-calendar.php
echo '<?php
function adminer_object() {
	// required to run any plugin
	include_once "./plugins/plugin.php";

	// autoloader
	foreach (glob("plugins/*.php") as $filename) {
		include_once "./$filename";
	}

	$plugins = array(
		// specify enabled plugins here
		new AdminerEditCalendar
	);

	/* It is possible to combine customization and plugins:
	class AdminerCustomization extends AdminerPlugin {
	}
	return new AdminerCustomization($plugins);
	*/

	return new AdminerPlugin($plugins);
}

// include original Adminer or Adminer Editor
include "./adminer.php";
?>' > /var/www/$IPADDY/adminer/index.php

# get mysqltuner
wget https://raw.githubusercontent.com/major/MySQLTuner-perl/master/mysqltuner.pl
chmod a+x mysqltuner.pl

#set correct permissions
chown -R $SUDO_USER:$SUDO_USER $USER_HOME
chown -R www-data:www-data /var/www

php5enmod mcrypt
service php5-fpm stop
service php5-fpm start
service nginx restart
clear

#echo -e "${YELLOW}phpMyAdmin has been installed, but needs to be configured.
#To complete it's installation, point your browser to https://${IPADDY}/phpmyadmin/setup/
#and follow the instructions.
#
echo -e "${YELLOW}Adminer has been installed and is at https://${IPADDY}/adminer/
Adminer, which is a full-featured database management tool written in PHP. Conversely to phpMyAdmin,
it consist of a single file ready to deploy to the target server. More styles and information can be
found on their homepage, http://www.adminer.org/

But, for now you need to point your browser to https://${IPADDY}/install/
and complete the site installation process."
read -p "
Once you have completed the above steps, press any key to continue:
" -n 1 -r
mv /var/www/$IPADDY/install /var/www/$IPADDY/installold
clear

echo -e "${YELLOW}/var/www/$IPADDY/install has been moved to /var/www/$IPADDY/installold.

${YELLOW}Now, add yourself to the site by going to https://${IPADDY}/signup.php to create a new user.
Login using the user you just created. Then, goto https://${IPADDY}/staffpanel.php?tool=adduser
and create a second user with the name 'System'.
Ensure it's userid==2 so you dont need to alter the autoshout function on include.

Sysop is added automatically to the array in cache/staff_settings.php and cache/staff_setting2.php.
Staff is automatically added to the same 2 files, but you have to make sure the member is offline before you promote them.

$USER_HOME/check_status.sh was added to quickly check the status of the required services and restart as necessary."
read -p "
Once you have completed the above steps, press any key to continue:
" -n 1 -r

echo -e "$CLEAR"
$USER_HOME/check_status.sh

fi
