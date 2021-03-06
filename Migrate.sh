#!/bin/bash

##############################################################################
#
# Migrate.sh
#
# Author: Terrance Medina
#
# Description: an interactive script to install a wordpress blog from backups
#
###############################################################################

# DEFAULTS
FILES_LOC_DF=""

function fail
{
	echo $1
	exit -1
}

DB_BAK=db.sql
FILES_BAK=files.tar.bz2

[ -e $DB_BAK.bz2 ] || fail "Don't see any database backups here. Make sure you run from within an untarred backup directory."
[ -e $FILES_BAK ] || fail "Don't see any file backups here. Make sure you run from within an untarred backup directory."

GAWK=`which gawk`
if [ "$GAWK" == "" ]; then
fail "ERROR: gawk is required. Please install it."
fi


echo "Where is Wordpress installed? [${FILES_LOC_DF}]"
read FILES_LOC
[ "$FILES_LOC" == "" ] && FILES_LOC=${FILES_LOC_DF}
FILES_LOC=`eval echo ${FILES_LOC//>}`

touch $FILES_LOC/test.txt 2> /dev/null
if [ $? -ne 0 ]; then 
echo "Insufficient write permissions on $FILES_LOC. Maybe run under sudo?" 
exit 1
fi
rm $FILES_LOC/test.txt > /dev/null

SITE_URL_DF=`grep WP_HOME ${FILES_LOC}/wp-config.php | gawk -F "," '{ print $2 }' | gawk -F "'" '{ print $2}'`
echo "Enter the site URL (hint -- start with http://): [${SITE_URL_DF}]"
read SITE_URL
[ "$SITE_URL" == "" ] && SITE_URL=${SITE_URL_DF}

pushd . > /dev/null
cd ${FILES_LOC}
# read defaults from existing config file, but allow overwrite
DB_NAME_DF=`grep DB_NAME wp-config.php | gawk -F "," '{ print $2 }' | gawk -F "'" '{ print $2}'`
DB_USER_DF=`grep DB_USER wp-config.php | gawk -F "," '{ print $2 }' | gawk -F "'" '{ print $2}'`
#DB_PASS_DF=`grep DB_PASSWORD wp-config.php | gawk -F "," '{ print $2 }' | gawk -F "'" '{ print $2}'`
popd > /dev/null

echo "Enter the name of the Wordpress Database [${DB_NAME_DF}]:"
read DB_NAME
[ "$DB_NAME" == "" ] && DB_NAME=$DB_NAME_DF

echo "Enter the username for the MySql database [${DB_USER_DF}]:"
read DB_USER
[ "$DB_USER" == "" ] && DB_USER=$DB_USER_DF

#echo "Enter the password for the MySql database [${DB_PASS_DF}]:"
#read -s DB_PASS
#[ "$DB_PASS" == "" ] && DB_PASS=$DB_PASS_DF



# backup the existing database and files
#mv ${FILES_LOC} ${FILES_LOC}.bak.`date +"%Y.%m.%d"` || fail "Unable to create directory for backups."
echo "Backing up existing files and database to /tmp ..."
./BlogBackup.sh -d /tmp -f $FILES_LOC -u $DB_USER -n $DB_NAME || fail "Unable to create directory for backups."

rm -r ${FILES_LOC}

# extract the files
echo "Installing new Wordpress site files to ${FILES_LOC} ..."
mkdir ${FILES_LOC}
tar xfj $FILES_BAK -C ${FILES_LOC} || fail "Failed extracting backup files to $FILES_LOC"

# export the database dump
# ensure the database exists and user has full access
bzip2 -d $DB_BAK.bz2
echo "Importing sql data ..."
printf "MySql "
mysql -u $DB_USER -p -e "create database if not exists ${DB_NAME}" 
mysql -u $DB_USER -p ${DB_NAME} < ${DB_BAK} || fail "Failed exporting database backup."


# update the website's URLs
# wp-config.php, make sure it has define rules for WP_HOME and WP_SITEURL, and set their values to the correct site URL
pushd . > /dev/null
cd ${FILES_LOC}
echo "Updating configuration file ..."

if [ `grep -c WP_HOME wp-config.php` -eq 1 ]; then
sed "s|\(define('WP_HOME','\).*\(');\)|\1${SITE_URL}\2|" -i wp-config.php
else
echo "WARNING: WP_HOME not defined in wp-config.php. You may need to reset URLs manually."
fi

if [ `grep -c WP_SITEURL wp-config.php` -eq 1 ]; then
sed "s|\(define('WP_SITEURL','\).*\(');\)|\1${SITE_URL}\2|" -i wp-config.php
else
echo "WARNING: WP_SITEURL not defined in wp-config.php. You may need to reset URLs manually."
fi

echo "Updating .htaccess file ..."
BASE_PATH=`echo $SITE_URL | awk -F'http://' '{print $2}' | awk -F'/' '{printf "/"; for(i=2;i<=NF;i++) printf "%s/", $i}'`
sed "s|\(RewriteBase \).*|\1${BASE_PATH}|" -i .htaccess
sed "s|\(RewriteRule \. \).*|\1${BASE_PATH}index.php [L]|" -i .htaccess

popd > /dev/null

echo "Do you want to change ownership of $FILES_LOC [N/y]?"
read SHOULD_CHANGE
if [ "$SHOULD_CHANGE" == "Y" -o "$SHOULD_CHANGE" == "y" ]; then
	echo "Enter the new user:group"
	read NEW_USER

	sudo chown -R $NEW_USER $FILES_LOC
fi

echo "SUCCESS"
