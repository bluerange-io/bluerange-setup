#!/bin/sh
set -e
cd $(dirname ${BASH_SOURCE:-$0})

if [[ -z "$1" || "$1" == "-?" || "$1" == "--help" ]]
then
    export NOW=$(date +"%Y%m%d_%H%M%S")
    echo "Please pass backup archive to restore:"
    echo "$ ./bluerange-restore.sh backup/bluerange-${NOW}.tar.gz"
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi
export ARCHIVE=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
export FOLDER=$(basename -s .tar.gz ${ARCHIVE})

# confirmation
echo "All existing BlueRange server data will be erased!"
echo "Are you sure to restore from ${FOLDER}?"
read -p "Type YES: " -r
echo "${REPLY}"
if [[ ! ${REPLY} =~ ^YES$ ]]
then
    [[ "$0" = "$BASH_SOURCE" ]] && exit 1 || return 1
fi

# unpack it all
echo "$ cd backup/restore && tar --gunzip -xvf $1"
rm -rf backup/restore
mkdir backup/restore
pushd backup/restore
tar --gunzip -xvf ${ARCHIVE}
popd

# tear down service
./bluerange-compose.sh down
docker volume rm \
    bluerange_mysql \
    bluerange_mongodb

# server configuration
echo "$ tar -xvf backup/restore/${FOLDER}/server.tar"
tar -xvf backup/restore/${FOLDER}/server.tar

# start database containers
./bluerange-compose.sh up -d \
    database \
    mongodb

# restore mongodb
echo "$ mongorestore --dir=backup/restore/${FOLDER}/mongodb"
pushd backup/restore/${FOLDER}
tar -xvf mongodb.tar
popd
MONGO_INITDB_ROOT_USERNAME=$(./bluerange-compose.sh exec -T mongodb printenv MONGO_INITDB_ROOT_USERNAME | tr -d [:space:])
MONGO_INITDB_ROOT_PASSWORD=$(./bluerange-compose.sh exec -T mongodb printenv MONGO_INITDB_ROOT_PASSWORD | tr -d [:space:])
./bluerange-compose.sh exec -T mongodb mongorestore \
    --username="${MONGO_INITDB_ROOT_USERNAME}" \
    --password="${MONGO_INITDB_ROOT_PASSWORD}" \
    --dir=backup/restore/${FOLDER}/mongodb

# restore mariadb
echo "$ mysql <backup/restore/${FOLDER}/mariadb.sql"
MYSQL_ROOT_PASSWORD=$(./bluerange-compose.sh exec -T database printenv MYSQL_ROOT_PASSWORD | tr -d [:space:])
./bluerange-compose.sh exec -T database mysql \
    --password=${MYSQL_ROOT_PASSWORD} \
    <backup/restore/${FOLDER}/mariadb.sql

# cleanup
rm -rf backup/restore
echo "Backup ${FOLDER} restored."
echo "* ./bluerange-compose.sh to start the server..."
