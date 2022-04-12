#!/usr/bin/env bash
# Provision script for Delicious Media WordPress Projects

# Add the bitbucket.org ssh host keys to our known hosts file if it isn't there already
if ! grep -q bitbucket.org ~/.ssh/known_hosts; then
	echo -e "\n Getting BitBucket ssh host keys.\n\n"
    noroot ssh-keyscan bitbucket.org >> ~/.ssh/known_hosts
fi;

# Add the github.com ssh host keys to our known hosts file if it isn't there already
if ! grep -q github.com ~/.ssh/known_hosts; then
	echo -e "\n Getting GitHub ssh host keys.\n\n"
    noroot ssh-keyscan github.com >> ~/.ssh/known_hosts
fi;

# fetch the first host as the primary domain. If none is available, generate a default using the site name
DOMAIN=`get_primary_host "${VVV_SITE_NAME}".test`
SITE_TITLE=`get_config_value 'site_title' "${DOMAIN}"`
WP_VERSION=`get_config_value 'wp_version' 'latest'`
WP_TYPE=`get_config_value 'wp_type' "single"`
DB_NAME=`get_config_value 'db_name' "${VVV_SITE_NAME}"`
DB_NAME=${DB_NAME//[\\\/\.\<\>\:\"\'\|\?\!\*-]/}

# Make a database, if we don't already have one
echo -e "\nCreating database '${DB_NAME}' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME}"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Create Nginx log files if missing
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/error.log
touch ${VVV_PATH_TO_SITE}/log/access.log

# Create folder for application logs.
mkdir -p ${VVV_PATH_TO_SITE}/app_logs


# Install and configure the latest stable version of WordPress
if [[ ! -d "${VVV_PATH_TO_SITE}/public_html" ]]; then

	echo -e "\n Setting up site ${VVV_SITE_NAME}.\n\n"

	# Add the site name to the hosts file
	echo "127.0.0.1 ${VVV_SITE_NAME}.test # vvv-auto" >> "/etc/hosts"

	mkdir -p ${VVV_PATH_TO_SITE}/public_html
	cd ${VVV_PATH_TO_SITE}/public_html

	# Clone the develop branch of our site WordPress repository into public_html folder
	echo -e "\n Cloning DM-WordPress-Layout repository from GitHub\n\n"
	noroot git clone https://github.com/DeliciousMedia/DM-WordPress-Layout.git .
	
	# Install WordPress
	echo -e "\n Installing WordPress core.\n\n"
	mkdir wp
	noroot wp core download

	# Remove unnecessary wp-content folder from WP core install
	rm -rf ${VVV_PATH_TO_SITE}/public_html/wp/wp-content/
	
	echo -e "\n Creating local-config.php.\n\n"
	dbprefix="wp`env LC_CTYPE=C LC_ALL=C tr -dc "a-f0-9" < /dev/urandom | head -c 6`_"
	cat local-config-sample.php | sed "s|@DB_NAME@|${VVV_SITE_NAME}|g;s|@DB_USER@|wp|g;s|@DB_PASSWORD@|wp|g;s|@DB_HOST@|localhost|g;s|@DB_PREFIX@|${dbprefix}|g;s|@LOG_PATH@|${VVV_PATH_TO_SITE}|g;" > local-config.php
    rm local-config-sample.php

	echo -e "\n Getting new salts for local-config.php.\n\n"
	SALT=$(curl -sL https://api.wordpress.org/secret-key/1.1/salt/)
	printf '%s\n' "g/@SALT_PLACEHOLDER@/d" a "$SALT" . w | ed -s local-config.php

  	noroot wp core install --url=${VVV_SITE_NAME}.test --title="${VVV_SITE_NAME}" --admin_user=deliciousmedia --admin_password=password --admin_email=clients@deliciousmedia.co.uk

	echo -e "\n Creating local folders for uploads & static content.\n\n"
    mkdir -p shared/content/uploads
    mkdir -p shared/content/static

	echo -e "\nTidying up WordPress install."
	noroot wp post delete {1,2} --force
	noroot wp rewrite structure "/%postname%/"
	noroot wp rewrite flush
	noroot wp option update default_comment_status closed
	noroot wp option update default_ping_status closed
	noroot wp option update default_pingback_flag 0
    noroot wp core language install en_GB
    noroot wp core language activate en_GB

	echo -e "\nRemoving previous git data & setting up new git repor\n\n"
    rm README.md
	git remote rm origin
	rm -rf .git
	git init

	echo -e "\nCreating ${VVV_SITE_NAME} theme from DM-Base-Theme\n\n"
	cd content/themes/
	curl -sS https://codeload.github.com/DeliciousMedia/DM-Base-Theme/zip/master > ${VVV_SITE_NAME}.zip
	unzip ${VVV_SITE_NAME}.zip
	rm ${VVV_SITE_NAME}.zip
	mv DM-Base-Theme-master ${VVV_SITE_NAME}
	cd ${VVV_SITE_NAME}
	rm README.md
	find . -type f | xargs perl -pi -e "s/\\b_s\\b/${VVV_SITE_NAME}/g"
	find . -type f | xargs perl -pi -e "s/\\b_s_/${VVV_SITE_NAME}_/g"
	mv src/sass/site.scss src/sass/${VVV_SITE_NAME}.scss 
	noroot wp theme activate ${VVV_SITE_NAME}
    cd ${VVV_PATH_TO_SITE}/public_html

	# Call composer.
	echo -e "\n Fetching additional plugins via Composer.\n\n"
	noroot /usr/local/bin/composer global require balbuf/composer-wp
	noroot /usr/local/bin/composer install

	if [ -d "${VVV_PATH_TO_SITE}/public_html/content/mu-plugins/dm-muloader/" ]; then
		echo -e "\n Found DM-MuLoader, copying plugin loader to mu-plugins folder."
		cp "${VVV_PATH_TO_SITE}/public_html/content/mu-plugins/dm-muloader/dm-muloader.php" "${VVV_PATH_TO_SITE}/public_html/content/mu-plugins/dm-muloader.php"
	fi
else 
	echo -e "\n Nothing to do for site.\n\n"
fi

#Copy the template across to the conf file
cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
