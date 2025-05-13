#!/bin/bash
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
    bluerange_postgresql \
    bluerange_mysql \
    bluerange_mongodb

# server configuration
echo "$ tar -xvf backup/restore/${FOLDER}/server.tar"
tar -xvf backup/restore/${FOLDER}/server.tar

# start database containers
./bluerange-compose.sh up -d \
    postgresql \
    database \
    mongodb

RESTORE_MARIADB=$( [ -f "backup/restore/${FOLDER}/database.sql" ] && echo "true" || echo "")
RESTORE_POSTGRESQL=$( [ -f "backup/restore/${FOLDER}/postgresql.sql" ] && echo "true"  || echo "")

# wait for databases
if [ -n "$RESTORE_MARIADB" ]; then
    MYSQL_PASSWORD=$(./bluerange-compose.sh exec -T database printenv MYSQL_PASSWORD | tr -d [:space:])
    while ! echo "SELECT 'MariaDB is ready now! (Please ignore afore errors.)';" | ./bluerange-compose.sh exec -T database mysql --user="bluerange" --password="${MYSQL_PASSWORD}" --database="bluerange" --wait; do
        sleep 1
    done
fi
if [ -n "$RESTORE_POSTGRESQL" ]; then
    while ! echo "SELECT 'PostgreSQL is ready now! (Please ignore afore errors.)';" | ./bluerange-compose.sh exec -T postgresql psql --username="bluerange" -c 'SELECT version();'; do
        sleep 1
    done
fi

# restore postgresql
if [ -n "$RESTORE_POSTGRESQL" ]; then
    ./bluerange-compose.sh exec -T postgresql psql \
        --username=bluerange \
        --file=backup/restore/${FOLDER}/postgresql.sql
else
    echo "PostgreSQL isn't running. Skipping restore. Start it, if you want to restore it, too."; echo
fi

# restore mongodb
IS_RUNNING_MONGODB=$(./bluerange-compose.sh ps --services --filter "status=running" | grep mongodb || true)
if [ -n "$IS_RUNNING_MONGODB" ]; then
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
else
    echo "MongoDB isn't running. Skipping restore. Start it, if you want to restore it, too."; echo
fi

# restore mariadb
if [ -n "$RESTORE_MARIADB" ]; then
    echo "$ mysql <backup/restore/${FOLDER}/mariadb.sql"
    MYSQL_ROOT_PASSWORD=$(./bluerange-compose.sh exec -T database printenv MYSQL_ROOT_PASSWORD | tr -d [:space:])
    ./bluerange-compose.sh exec -T database mysql \
        --password="${MYSQL_ROOT_PASSWORD}" \
        <backup/restore/${FOLDER}/mariadb.sql
else
    echo "MariaDB isn't running. Skipping restore. Start it, if you want to restore it, too."; echo
fi

# cleanup
rm -rf backup/restore
echo "Backup ${FOLDER} restored."
echo "* ./bluerange-compose.sh to start the server..."
