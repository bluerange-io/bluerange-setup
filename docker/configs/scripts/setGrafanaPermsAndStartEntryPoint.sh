#!/bin/bash
CONFIG_FILE=/home/grafana/grafana.ini
CONFIG_FILE_TEMPLATE=${CONFIG_FILE}.template
CONFIG_FILE_RESOLVED=${CONFIG_FILE}.resolved

# resolve password env variables in ini file
cp ${CONFIG_FILE_TEMPLATE} ${CONFIG_FILE_RESOLVED} 
sed -i 's/$SYSTEM_ADMIN_PASSWORD/'"${SYSTEM_ADMIN_PASSWORD}"'/g' ${CONFIG_FILE_RESOLVED}
sed -i 's/${SYSTEM_ADMIN_PASSWORD}/'"${SYSTEM_ADMIN_PASSWORD}"'/g' ${CONFIG_FILE_RESOLVED}
sed -i 's/$DATABASE_PWD/'"${DATABASE_PWD}"'/g' ${CONFIG_FILE_RESOLVED}
sed -i 's/${DATABASE_PWD}/'"${DATABASE_PWD}"'/g' ${CONFIG_FILE_RESOLVED}

export GF_PATHS_CONFIG=${CONFIG_FILE_RESOLVED}

# sleep infinite
# run grafana (Dockerfile) entrypoint
# ENTRYPOINT [ "/run.sh" ]
exec /run.sh
