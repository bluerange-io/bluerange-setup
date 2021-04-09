#!/bin/sh
set -e
cd $(dirname ${BASH_SOURCE:-$0})

export NOW=$(date +%s)
mkdir backup/bluerange-${NOW}

# backup of mongodb
MONGO_INITDB_ROOT_USERNAME=$(./bluerange-compose.sh exec mongodb printenv MONGO_INITDB_ROOT_USERNAME | tr -d [:space:])
MONGO_INITDB_ROOT_PASSWORD=$(./bluerange-compose.sh exec mongodb printenv MONGO_INITDB_ROOT_PASSWORD | tr -d [:space:])
./bluerange-compose.sh exec -T mongodb \
    mongodump \
    --username="${MONGO_INITDB_ROOT_USERNAME}" \
    --password="${MONGO_INITDB_ROOT_PASSWORD}" \
    --out=backup/bluerange-${NOW}/mongodb
pushd backup/bluerange-${NOW}
tar --gzip -cvf mongodb.tar.gz mongodb
rm -rf mongodb
popd
