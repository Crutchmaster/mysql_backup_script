#!/bin/bash
host=$1;
if [ $1 = "--help" ]; then
	echo "MySQL backup script."
	echo "Include mysqldump, mysql, git"
	echo "Usage: dump.sh <host> <user> <password>";
else
	mkdir $host 2> /dev/null
	cd $host

	echo 'show databases;' | mysql -h $1 --user=$2 --password=$3 | tail -n +2 > databases.list
	dbcnt=$(wc -l databases.list | cut -d ' ' -f 1)
	dbcur=0
	
	for db in $(cat databases.list);
	do
		dbcur=$(($dbcur+1))
		echo "DB# $dbcur/$dbcnt Start dump $db"
		if [ -d $db ]; then 
			newdb=0
		else
			mkdir $db 2> /dev/null
			newdb=1
		fi
		cd $db
		if [ $newdb -eq 1 ]; then 
			echo "git init"
			git init 
		fi

		echo "use $db;show tables;" | mysql -h $1 --user=$2 --password=$3 | tail -n +2 > tables.list
		tabcnt=$(wc -l tables.list | cut -d ' ' -f 1)
		tabcur=0
		
		#git: rm 
		for remove in $(dir -1 | grep -v -f tables.list | grep -v "routines.sql" | grep -v "tables.list");
		do
			echo "rm:$remove"
			git rm $remove
			rm $remove
		done

		for table in $(cat tables.list);
		do
			tabcur=$(($tabcur+1))
			echo "DB# $dbcur/$dbcnt TAB# $tabcur/$tabcnt dump $db.$table"
			#dump tables
			mysqldump --user=$2 -h $1 --password=$3 --lock-tables=false --extended-insert=false $db $table | grep -v 'SQL SECURITY DEFINER' > $table.sql 2>>/home/user/backup/db/error.log
			git add $table.sql
		done
		#dump routines
		echo "DB# $dbcur/$dbcnt dump $db routines"
		mysqldump --user=$2 -h $1 --password=$3 -R -t -d --extended-insert=false $db | grep -v 'SQL SECURITY DEFINER' | tr '[:upper:]' '[:lower:]' | sed 's/ definer=`root`@`[^`]*`//' > $db.routines.sql 2>>/home/user/backup/db/error.log
		git add $db.routines.sql
		git commit -m "$(date +%F_%R)"
		git gc
		cd ..
	done
	cd ..
fi
