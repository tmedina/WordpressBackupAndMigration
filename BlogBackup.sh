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

function fail
{
	echo $1
	rm -r $DEST/$TEMP 2> /dev/null
	exit -1
}

trap "fail 'Aborted by user '" SIGINT SIGTERM

DEST=$1
DATE=`date +"%Y.%m.%d"`
TEMP=backup.${DATE}
TABLES="wp_commentmeta wp_comments wp_links wp_options wp_postmeta wp_posts wp_term_relationships wp_term_taxonomy wp_termmeta wp_terms wp_usermeta wp_users"

# Ensure a destination directory has been provided
if [ "$DEST" == "" ]; then
echo "usage: BlogBackup <destination_path>"
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
echo "Enter the database used by wordpress [$DEFAULT_DB]:"
read MYSQL_DB
if [ "$MYSQL_DB" == "" ]; then
MYSQL_DB=$DEFAULT_DB
fi

echo "Enter your MySQL Username [$DEFAULT_USER]:"
read MYSQL_USER
if [ "$MYSQL_USER" == "" ]; then
MYSQL_USER=$DEFAULT_USER
fi

printf "MySQL "
mysqldump --add-drop-table -h localhost  -u ${MYSQL_USER} -p  ${MYSQL_DB} `echo $TABLES` \
	 | bzip2 -c \
	 > $DEST/$TEMP/db.sql.bz2

# check return status of mysqldump
if [ ${PIPESTATUS[0]} -ne 0 -o $? -ne 0 ]; then
fail "Failed backing up database"
fi

#backup files
echo "Where are the Wordpress files [$DEFAULT_FILES]?"
read FILES_LOC
if [ "$FILES_LOC" == "" ]; then
FILES_LOC=$DEFAULT_FILES
fi

while [ ! -d "`eval echo ${FILES_LOC//>}`" ]; do
echo "Can't find directory $FILES_LOC. Where are the Wordpress files?"
read FILES_LOC
done

#TODO: tar files into flat directory 
pushd . 
cd `eval echo ${FILES_LOC//>}`
tar cvfj $DEST/$TEMP/files.bz2 . || fail "Failed making files backup"
popd

#copy these scripts into the archive
cp ~/Scripts/BlogBackup.sh $DEST/$TEMP/ || fail "Unable to copy BlogBackup.sh to backup directory."
cp ~/Scripts/Migrate.sh $DEST/$TEMP/ || fail "Unable to copy Migrate.sh to backup directory."

#archive everything
pushd .
cd $DEST
tar cvfj BlogBackup.${DATE}.tar.bz2 backup.${DATE} || fail "Failed making BlogBackup.${DATE}.tar.bz2"
rm -r $TEMP
popd

echo "SUCCESS!"
