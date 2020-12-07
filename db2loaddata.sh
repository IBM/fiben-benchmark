#!/bin/sh

# If a userid is not provided, then a local connection is assumed.
# If a userid is provided, but a password is not, the password is prompted for.
# If a schema is not provided, the current user is assumed.
# If the database is remote, provide a hostname and port, otherwise a local database is assumed
# -l is to use load instead of import.  Default is import.
# Load will perform much faster, but requires LOAD authority.
# Typical uses would be as follows:
# 1. Local database
# db2loaddata.sh -d <dbname> -s <schema>
# 2. Remote database
# db2loaddata.sh -d <dbname> -h <hostname> -o <port> -s <schema> -u <userid>
# 3. Remote database already cataloged
# db2loaddata.sh -d <dbname> -s <schema> -u <userid>

USAGE="Usage: db2loaddata.sh -d <dbname> [-h <hostname> -o <port>] [-s <schema>] [-u <userid> [-p <password]] [-l]"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
TABLELIST=tablelist.txt
DATADIR=data
DSDRIVERCFG=$SCRIPTPATH/db2dsdriver.cfg
INTTABFILE=$SCRIPTPATH/inttabs2.txt
ACTION=IMPORT

SCHEMA=$USER

function atexit
{
   echo "Exiting ..."
   if [[ -e $DSDRIVERCFG ]]
   then
      echo "Cleaning up generated $DSDRIVERCFG"
      rm $DSDRIVERCFG
   fi
   if [[ -e $INTTABFILE ]]
   then
      echo "Cleaning up generated $INTTABFILE"
      rm $INTTABFILE
   fi
}

trap atexit EXIT

while getopts 'ld:s:u:p:h:o:' c
do
  case $c in
    d) DBNAME=$OPTARG ;;
    s) SCHEMA=$OPTARG ;;
    u) DBUSER=$OPTARG ;;
    p) PASSWORD=$OPTARG ;;
    h) DBHOST=$OPTARG ;;
    o) DBPORT=$OPTARG ;;
    l) ACTION=LOAD ;;
  esac
done


SCHEMA=$(echo "$SCHEMA" | tr '[:lower:]' '[:upper:]')

if [[ -z $DBNAME ]]
then
   echo $USAGE
   exit 2
fi

# If we were given a userid but no password, prompt for it.
if [[ ! -z $DBUSER ]]
then
   if [[ -z $PASSWORD ]]
   then
      stty -echo
      printf "Password: "
      read PASSWORD
      stty echo
      printf "\n"
   fi
fi


echo "Connecting using the following values:"
echo "HOSTNAME = $DBHOST"
echo "PORT     = $DBPORT"
echo "DBNAME   = $DBNAME"
echo "SCHEMA   = $SCHEMA"
echo "USER     = $DBUSER"

# If the user has given us a hostname, then lets catalog it.
if [[ ! -z $DBHOST ]]
then
   export DB2DSDRIVER_CFG_PATH=$DSDRIVERCFG
   echo "Creating db2dsdriver.cfg alias for database ..."
   db2cli writecfg add -dsn FIBENSCR -host $DBHOST -port $DBPORT -database $DBNAME
fi

# Make sure the data directory exists.
echo "Checking existence of directory $SCRIPTPATH/$DATADIR ..."
if [ ! -d $SCRIPTPATH/$DATADIR ]
then
   echo "Data directory does not exists: $SCRIPTPATH/$DATADIR"
   exit 1
fi

#Make sure all the .csv files exist
echo "Checking existence of .csv files ..."
for tablename in $(cat $TABLELIST)
do
   if [ ! -f $SCRIPTPATH/$DATADIR/$tablename.csv ]
   then
       echo "CSV file does not exist: $SCRIPTPATH/$DATADIR/$tablename.csv"
       exit 1
   fi
done

if [[ -z $DBHOST ]]
then
   DBCONNNAME=$DBNAME
else
   DBCONNNAME=FIBENSCR
fi

echo "Connecting to database $DBNAME ..."
if [[ -z $DBUSER ]]
then
   db2 connect to $DBCONNNAME
else
   db2 connect to $DBCONNNAME user $DBUSER using $PASSWORD
fi

if [ $? -ne 0 ]
then
  echo "Error: Could not connect to database, quitting."
  exit 1
fi


echo "Creating schema $SCHEMA.  SQL0601N is OK for schemas that already exist"
db2 -v "create schema $SCHEMA"
db2 -v "set current schema $SCHEMA"

echo "Creating tables ..."
db2 -tvf $SCRIPTPATH/FIBEN.sql

if [ $? -ne 0 ]
then
  echo "Error: Could not create tables, quitting."
  exit 1
fi

echo "Beginning table loads"

for tablename in $(cat $TABLELIST)
do
   fulltab="$SCHEMA.$tablename"
   echo "Loading from $DATADIR/$tablename.csv info $fulltab"
   case $ACTION in
   IMPORT)
      db2 -v "import from $SCRIPTPATH/$DATADIR/$tablename.csv of del commitcount 100000 insert into $fulltab"
      ;;
   LOAD)
      db2 -v "load client from $SCRIPTPATH/$DATADIR/$tablename.csv of del replace into $fulltab nonrecoverable"
      ;;
   esac

   if [ $? -ne 0 ]
   then
     echo "Error: Failed to load from  $DATADIR/$tablename.csv info $fulltab, quitting."
     exit 1
   fi
done

case $ACTION in
LOAD)
   # The db2 load command will place tables into SET INTEGRITY PENDING mode.
   # We need to call set integrity so they are usable.
   echo "Checking for tables in SET INTEGRITY PENDING mode ..."
   echo "db2 -x select  rtrim( rtrim(tabschema) || '.' || rtrim(tabname) ) as qual_tab from syscat.tables where TABSCHEMA = '$SCHEMA' and ( CONST_CHECKED like '%N%' or status != 'N' or access_mode != 'F' ) with ur"
   db2 -x "select  rtrim( rtrim(tabschema) || '.' || rtrim(tabname) ) as qual_tab from syscat.tables where TABSCHEMA = '$SCHEMA' and ( CONST_CHECKED like '%N%' or status != 'N' or access_mode != 'F' ) with ur" > $INTTABFILE

   if [ $? -ne 0 ]
   then
     echo "Error: Could not obtain list of tables in set integrity pending mode.  Loaded tables may not be available, quitting."
     exit 1
   fi

   # Get the list of tables output to the $INTTABFILE file
   sed -i 's/[[:space:]]*$//' $INTTABFILE

   INTPENDTABLES=""

   while read -ru 3 LINE; do
      INTPENDTABLES="$LINE, $INTPENDTABLES"
   done 3< $INTTABFILE

   #Strip last comma
   INTPENDTABLES=${INTPENDTABLES%,*}

   if [[ ! -z $INTPENDTABLES ]]
   then
      db2 -v "set integrity for $INTPENDTABLES immediate checked"
      if [ $? -ne 0 ]
      then
        echo "Error: Error setting integrity for loaded files, table may not be available."
        exit 1
      fi
   fi
  ;;
esac

db2 terminate
