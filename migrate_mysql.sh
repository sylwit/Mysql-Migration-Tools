#!/bin/bash
# Copyright (c) 2005 nixCraft project <http://cyberciti.biz/fb/>
# This script is licensed under GNU GPL version 2.0 or above
# Author Vivek Gite <vivek@nixcraft.com>
#
# http://www.cyberciti.biz/tips/move-mysql-users-privileges-grants-from-one-host-to-new-host.html
#
# 2011-09-15 : Sylvain WITMEYER <s.witmeyer@myeshop.fr>
# add ssh port
# add usage with a single argument
# change DB privs to allow the remote connection instead of the local one
# ------------------------------------------------------------
# SETME First - local mysql user/pass
_lusr="admin"
_lpass="password"
_lhost="localhost"
_lhostname="local.server.fr"
 
# SETME First - remote mysql user/pass
_rusr="admin"
_rpass="password"
_rhost="remote.server.fr"
 
# SETME First - remote mysql ssh info
# Make sure ssh keys are set
_rsshusr="root"
_rsshhost="remote.server.fr"
_rsshport="22"
 
# sql file to hold grants and db info locally
_tmp="/tmp/output.mysql.$$.sql"
 
#### No editing below #####
 
# Input data
_db="$1"
_user="$2"
 
# Die if no input given
[ $# -eq 0 ] && { echo "Usage: $0 MySQLDatabaseName MySQLUserName"; exit 1; }


#if no user is given, we use the db value instead
if [ $# -eq 1 ] 
then
 _user=${_db}
fi

# Make sure you can connect to local db server
mysqladmin -u "$_lusr" -p"$_lpass" -h "$_lhost"  ping &>/dev/null || { echo "Error: Mysql server is not online or set correct values for _lusr, _lpass, and _lhost"; exit 2; }
 
# Make sure database exists
mysql -u "$_lusr" -p"$_lpass" -h "$_lhost" -N -B  -e'show databases;' | grep -q "^${_db}$" ||  { echo "Error: Database $_db not found."; exit 3; }
 
##### Step 1: Okay build .sql file with db and users, password info ####
echo "*** Getting info about $_db..."
echo "create database IF NOT EXISTS $_db; " > "$_tmp"
 
# Build mysql query to grab all privs and user@host combo for given db_username
mysql -u "$_lusr" -p"$_lpass" -h "$_lhost" -B -N \
-e "SELECT DISTINCT CONCAT('SHOW GRANTS FOR ''',user,'''@''',host,''';') AS query FROM user WHERE user != '' " \
mysql \
| mysql  -u "$_lusr" -p"$_lpass" -h "$_lhost" \
| grep  "$_user" \
| sed ':a;N;$!ba;s/\n/;\n/g' \
| sed ':a;N;$!ba;s/\\\\//g' \
| sed ':a;N;$!ba;s/localhost/'${_lhostname}'/g' \
| sed 's/Grants for .*/#### &/' >> "$_tmp"

##### Step 2: send .sql file to remote server ####
echo "*** Creating $_db on ${rsshhost}..."
scp -P${_rsshport} "$_tmp" ${_rsshusr}@${_rsshhost}:/tmp/
 
#### Step 3: Create db and load users into remote db server ####
ssh ${_rsshusr}@${_rsshhost} -p ${_rsshport} mysql -u "$_rusr" -p"$_rpass" < "$_tmp"
 
#### Step 4: Send mysql database and all data ####
echo "*** Exporting $_db from $HOSTNAME to ${_rsshhost}..."
mysqldump -u "$_lusr" -p"$_lpass" "$_db" | ssh ${_rsshusr}@${_rsshhost} -p ${_rsshport} mysql -u "$_rusr" -p"$_rpass" "$_db"
 
rm -f "$_tmp"
