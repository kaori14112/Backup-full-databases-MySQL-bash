#!/bin/bash


source ./config.conf

if [ -z "${PATH-}" ]; then export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin; fi

[ ! -d "$BACKUP_PATH" ] && echo "Directory $BACKUP_PATH DOES NOT exists." && exit 1
TIME=`date "+%Y%m%d_%H%M%S"`

#This is only for backup log
echo "========================="
echo "* Starting backup: `date +"%d-%m-%y--%T"`."
echo "* Backup directory: $BACKUP_PATH."
BK_FD=$BACKUP_PATH/$TIME

mkdir -p "${BK_FD}"

IGNORE_TABLES_STRING=""
FL=""
for i in "${IGNORE_TABLES[@]}"
do
	IGNORE_TABLES_STRING+="$FL$i"
	FL="|"
done

IGNORE=""

mysql --defaults-extra-file=./my.cnf -s -r -e 'show databases' |
while read db
do
	if [ "$db" = information_schema ] || [ "$db" =  mysql ] || [ "$db" =  phpmyadmin ] || [ "$db" =  performance_schema ]  # exclude this DB
	then
		echo "-- Skip $db ..."
		continue
	fi
	
	for y in `mysql --defaults-extra-file=./my.cnf -e "use $db;show tables" | grep -E $IGNORE_TABLES_STRING`
	do
		IGNORE+=" --ignore-table=$db.$y"
	done

	
	echo "-- Dumping $db ..."
	if [ -z "$IGNORE" ]
	then
		echo "No match pattern, no tables will be skip.."
		mysqldump --defaults-extra-file=./my.cnf $db --single-transaction --routines --triggers -e --no-tablespaces > $BK_FD/$db.sql
	else
		echo "-- Those tables will be IGNORED: $IGNORE"
		mysqldump --defaults-extra-file=./my.cnf $db --single-transaction --routines --triggers -e $IGNORE --no-tablespaces > $BK_FD/$db.sql
	fi
	[[ $? -eq 0 ]] && gzip $BK_FD/$db.sql
	[[ $? -eq 0 ]] && echo "-- Backup success database $db - locate at: $BK_FD/$db.sql.gz"
done

echo "* Backup completed at `date +"%d-%m-%y--%T"`"

find $BACKUP_PATH -type f -mtime +7 -exec rm {} +
