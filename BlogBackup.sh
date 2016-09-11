#!/bin/bash

##################################################################################
#
# BlogBackup.sh
#
# Author: Terrance Medina
#
# Description: An interactive script for backing up and archiving a wordpress blog
#
####################################################################################

# Default values for mysql
DEFAULT_DB=""
DEFAULT_USER=""
DEFAULT_FILES=""

# get parameters for DB_NAME, DB_USER, FILES_LOC, BAK_DEST
while getopts "f:u:n:d:" arg; do

	case $arg in
	f)
		PARAM_FILES_LOC=$OPTARG
		;;
	u) 
		PARAM_DB_USER=$OPTARG
		;;
	n) 
		PARAM_DB_NAME=$OPTARG
		;;
	d)
		PARAM_BAK_DEST=$OPTARG
		;;
		
	esac
done

function fail
{
	echo $1
	rm -r $DEST/$TEMP 2> /dev/null
	exit -1
}

trap "fail 'Aborted by user '" SIGINT SIGTERM

DEST=$PARAM_BAK_DEST
DATE=`date +"%Y.%m.%d"`
TEMP=backup.${DATE}
TABLES="wp_commentmeta wp_comments wp_links wp_options wp_postmeta wp_posts wp_term_relationships wp_term_taxonomy wp_termmeta wp_terms wp_usermeta wp_users"

# Ensure a destination directory has been provided
if [ "$DEST" == "" ]; then
echo "usage: BlogBackup [required: -d <backup destination>] (optional: -f <path to wordpress files> -u <mysql username> -n <mysql database>)"
exit -1
fi

# check for clobbering old backups
CLOBBER="Y"
if [ -f $DEST/BlogBackup.${DATE}.tar.bz2 ]; then
echo "A backup for today already exists in ${DEST}. Do you want to overwrite? [y/N]"
read CLOBBER
fi

if [ "$CLOBBER" == "N" -o "$CLOBBER" == "n" -o "$CLOBBER" == "" ]; then
echo "Quitting"
exit 0
fi

# cleanup any old extracted backups
if [ -e $DEST/$TEMP ]; then
rm -r $DEST/$TEMP
fi

mkdir -p $DEST/$TEMP || fail "Unable to create destination directory"

#backup database
if [ ! "$PARAM_DB_NAME" == "" ]; then
MYSQL_DB=$PARAM_DB_NAME
else
echo "Enter the database used by wordpress [$DEFAULT_DB]:"
read MYSQL_DB
[ "$MYSQL_DB" == "" ] && MYSQL_DB=$DEFAULT_DB
fi

if [ ! "$PARAM_DB_USER" == "" ]; then
MYSQL_USER=$PARAM_DB_USER
else
echo "Enter your MySQL Username [$DEFAULT_USER]:"
read MYSQL_USER
[ "$MYSQL_USER" == "" ] && MYSQL_USER=$DEFAULT_USER
fi

echo "Backing up the database ... "
printf "MySQL "
mysqldump --add-drop-table -h localhost  -u ${MYSQL_USER} -p  ${MYSQL_DB} `echo $TABLES` \
	 | bzip2 -c \
	 > $DEST/$TEMP/db.sql.bz2

# check return status of mysqldump
if [ ${PIPESTATUS[0]} -ne 0 -o $? -ne 0 ]; then
fail "Failed backing up database"
fi

#backup files
if [ ! "$PARAM_FILES_LOC" == "" ]; then
FILES_LOC=$PARAM_FILES_LOC
else
echo "Where are the Wordpress files [$DEFAULT_FILES]?"
read FILES_LOC
[ "$FILES_LOC" == "" ] && FILES_LOC=$DEFAULT_FILES
fi

FILES_LOC=`eval echo ${FILES_LOC//>}`

while [ ! -d "${FILES_LOC}" ]; do
echo "Can't find directory $FILES_LOC. Where are the Wordpress files?"
read FILES_LOC
done

pushd . > /dev/null
cd ${FILES_LOC}
echo "Backing up the files ..."
tar cfj $DEST/$TEMP/files.tar.bz2 . || fail "Failed making files backup"
popd > /dev/null

#copy these scripts into the archive
cp ./BlogBackup.sh $DEST/$TEMP/ || fail "Unable to copy BlogBackup.sh to backup directory."
cp ./Migrate.sh $DEST/$TEMP/ || fail "Unable to copy Migrate.sh to backup directory."

#archive everything
pushd . > /dev/null
cd $DEST
echo "Archiving the backup ..."
tar cfj BlogBackup.${DATE}.tar.bz2 backup.${DATE} || fail "Failed making BlogBackup.${DATE}.tar.bz2"
rm -r $TEMP
popd > /dev/null

echo "SUCCESS!"
