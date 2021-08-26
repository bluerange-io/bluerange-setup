#!/bin/bash
CONFIG_FILE=/etc/prometheus/prometheus.yml
CONFIG_FILE_RESOLVED=${CONFIG_FILE}.resolved
DB_WORK_DIR=/prometheus/

# resolve env variables in config file
( echo "cat <<EOF" ; cat ${CONFIG_FILE} ; echo EOF ) | sh > ${CONFIG_FILE_RESOLVED} 

# run prometheus (Dockerfile) entrypoint
# ENTRYPOINT [ "/bin/prometheus" ]
# CMD        [ "--config.file=/etc/prometheus/prometheus.yml", \
#              "--storage.local.path=/prometheus", \
#              "--web.console.libraries=/etc/prometheus/console_libraries", \
#              "--web.console.templates=/etc/prometheus/consoles" ]
exec /bin/prometheus --config.file=${CONFIG_FILE_RESOLVED} --storage.tsdb.path=${DB_WORK_DIR}
