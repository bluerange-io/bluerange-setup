#!/bin/bash
CONFIG_FILE=/home/grafana/grafana.ini
CONFIG_FILE_TEMPLATE=${CONFIG_FILE}.template
CONFIG_FILE_RESOLVED=${CONFIG_FILE}.resolved

cp /home/grafana/server.pem.copy /home/grafana/server.pem
cp /home/grafana/server.key.copy /home/grafana/server.key
chown grafana /home/grafana/server.pem /home/grafana/server.key
chmod 600 /home/grafana/server.pem /home/grafana/server.key

# resolve password env variables in ini file
cp ${CONFIG_FILE_TEMPLATE} ${CONFIG_FILE_RESOLVED} 
sed -i 's/$SYSTEM_ADMIN_PASSWORD/'"${SYSTEM_ADMIN_PASSWORD}"'/g' ${CONFIG_FILE_RESOLVED}
sed -i 's/${SYSTEM_ADMIN_PASSWORD}/'"${SYSTEM_ADMIN_PASSWORD}"'/g' ${CONFIG_FILE_RESOLVED}
sed -i 's/$GRAFANA_DB_PASSWORD/'"${GRAFANA_DB_PASSWORD}"'/g' ${CONFIG_FILE_RESOLVED}
sed -i 's/${GRAFANA_DB_PASSWORD}/'"${GRAFANA_DB_PASSWORD}"'/g' ${CONFIG_FILE_RESOLVED}

export GF_PATHS_CONFIG=${CONFIG_FILE_RESOLVED}

# run grafana (Dockerfile) entrypoint
# ENTRYPOINT [ "/run.sh" ]
exec /run.sh
