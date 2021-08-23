#!/bin/bash
SQL_INIT_FILE=/docker-entrypoint-initdb.d/initdb.sql
SQL_INIT_FILE_TEMPLATE=${SQL_INIT_FILE}.template

# resolve DB password env variables in SQL init file
cp ${SQL_INIT_FILE_TEMPLATE} ${SQL_INIT_FILE}
sed -i 's/$DATABASE_PWD/'"${DATABASE_PWD}"'/g' ${SQL_INIT_FILE}
sed -i 's/${DATABASE_PWD}/'"${DATABASE_PWD}"'/g' ${SQL_INIT_FILE}

# run mariadb (Dockerfile) entrypoint
# ENTRYPOINT ["docker-entrypoint.sh"]
# CMD ["mysqld"]
# sleep 1d
exec /usr/local/bin/docker-entrypoint.sh mysqld
