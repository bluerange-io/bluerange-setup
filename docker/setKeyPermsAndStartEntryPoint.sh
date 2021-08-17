#!/bin/bash
cp /usr/share/elasticsearch/config/server.pem.copy /usr/share/elasticsearch/config/server.pem
cp /usr/share/elasticsearch/config/server.key.copy /usr/share/elasticsearch/config/server.key
chown elasticsearch:elasticsearch /usr/share/elasticsearch/config/server.pem /usr/share/elasticsearch/config/server.key
chmod 640 /usr/share/elasticsearch/config/server.pem /usr/share/elasticsearch/config/server.key

# run elasticsearch (Dockerfile) entrypoint 
# ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
exec /usr/local/bin/docker-entrypoint.sh $*
