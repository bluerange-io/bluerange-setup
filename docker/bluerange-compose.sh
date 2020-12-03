#!/bin/sh
set -e
cd $(dirname ${BASH_SOURCE:-$0})

DOCKER_COMPOSE="docker-compose -p bluerange -f docker-compose.yml -f docker-compose.elasticsearch.yml -f docker-compose.mender.yml"

. ./server.env
export HOST

if [ $# -eq 0 ] ; then
  echo "$" $DOCKER_COMPOSE up -d
  $DOCKER_COMPOSE up -d
  echo ""
  echo "mender-useradm$" useradm create-user --username=admin@${HOST} --password=admin123
  $DOCKER_COMPOSE exec -T mender-useradm useradm create-user --username=admin@${HOST} --password=admin123 || true
  echo ""
  echo "    BlueRange: https://${HOST}:443  (admin / admin123)"
  echo "       Mender: https://${HOST}:444  (admin@${HOST} / admin123)"
  echo "       Kibana: https://${HOST}:5602 (admin / admin)"
  echo "ElasticSearch: https://${HOST}:9201 (admin / admin)"
  exit 0
fi

exec $DOCKER_COMPOSE $*