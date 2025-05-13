#!/bin/bash
set -e
cd $(dirname ${BASH_SOURCE:-$0})

export NOW=$(date +"%Y%m%d_%H%M%S")
mkdir backup/bluerange-${NOW}

IS_RUNNING_POSTGRESQL=$(./bluerange-compose.sh ps --services --filter "status=running" | grep postgresql || true)
if [ -n "$IS_RUNNING_POSTGRESQL" ]; then
    # backup of postgresql
    echo "$ pg_dumpall -username=bluerange --database=bluerange --file=backup/bluerange-${NOW}/postgresql.sql"
    ./bluerange-compose.sh exec -T postgresql pg_dumpall \
        --username=bluerange \
        --database=bluerange \
        --file=backup/bluerange-${NOW}/postgresql.sql
else
    echo "PostgreSQL isn't running. Skipping backup. Start it, if you want to backup it, too."; echo
fi

IS_RUNNING_MARIADB=$(./bluerange-compose.sh ps --services --filter "status=running" | grep database || true)
if [ -n "$IS_RUNNING_MARIADB" ]; then
    # backup of mariadb
    echo "$ mysqldump --compress --single-transaction --all-databases >backup/bluerange-${NOW}/mariadb.sql"
    MYSQL_ROOT_PASSWORD=$(./bluerange-compose.sh exec -T database printenv MYSQL_ROOT_PASSWORD | tr -d [:space:])
    ./bluerange-compose.sh exec -T database mysqldump \
        --password=${MYSQL_ROOT_PASSWORD} \
        --compress \
        --single-transaction \
        --all-databases \
        --max_allowed_packet=1073741824 \
        >backup/bluerange-${NOW}/mariadb.sql
else
    echo "MariaDB isn't running. Skipping backup. Start it, if you want to backup it, too."; echo
fi

IS_RUNNING_MONGODB=$(./bluerange-compose.sh ps --services --filter "status=running" | grep mongodb || true)
if [ -n "$IS_RUNNING_MONGODB" ]; then
    # backup of mongodb
    echo "$ mongodump --out=backup/bluerange-${NOW}/mongodb"
    MONGO_INITDB_ROOT_USERNAME=$(./bluerange-compose.sh exec -T mongodb printenv MONGO_INITDB_ROOT_USERNAME | tr -d [:space:])
    MONGO_INITDB_ROOT_PASSWORD=$(./bluerange-compose.sh exec -T mongodb printenv MONGO_INITDB_ROOT_PASSWORD | tr -d [:space:])
    ./bluerange-compose.sh exec -T mongodb mongodump \
        --username="${MONGO_INITDB_ROOT_USERNAME}" \
        --password="${MONGO_INITDB_ROOT_PASSWORD}" \
        --out=backup/bluerange-${NOW}/mongodb
    pushd backup/bluerange-${NOW}
    tar -cvf mongodb.tar mongodb
    rm -rf mongodb
    popd
else
    echo "MongoDB isn't running. Skipping backup. Start it, if you want to backup it, too."; echo
fi


# server configuration
echo "$ tar -cvf backup/bluerange-${NOW}/server.tar application.yml server.* certs/*"
tar -cvf backup/bluerange-${NOW}/server.tar \
    application.yml \
    server.* \
    certs/*

# tar it all up
echo "$ cd backup && tar -gzip -cvf bluerange-${NOW}.tar.gz bluerange-${NOW}"
pushd backup
tar --gzip -cvf bluerange-${NOW}.tar.gz bluerange-${NOW}
rm -rf bluerange-${NOW}
popd
echo "$ chmod go-r backup/bluerange-${NOW}.tar.gz"
chmod go-r backup/bluerange-${NOW}.tar.gz
echo "* backup/bluerange-${NOW}.tar.gz"

