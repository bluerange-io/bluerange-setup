#!/bin/bash

set -e
cd $(dirname ${BASH_SOURCE:-$0})

set -a
. ./.env
if [ -f ./server.env ] ; then
  . ./server.env
  export HOST
fi

if [ ! -f ./application.yml ] ; then
  cat > application.yml << EOF
# advanced configuration goes here

EOF
fi

if [ ! -f ./configs/traefik/dynamic.yml ] ; then
  cat > configs/traefik/dynamic.yml << EOF
# dynamic configuration for traefik goes here

EOF
fi

# due to compatibility reasons (use former BlueRange DB password variable 'DATABASE_PWD' if set)
if [ ! -z "$DATABASE_PWD" ] ; then
  export BLUERANGE_DATABASE_PASSWORD=${DATABASE_PWD}
  echo "Note: Deprecated env variable 'DATABASE_PWD' is set. Use 'BLUERANGE_DATABASE_PASSWORD' env variable instead !!"
fi

set +a
if [ -z "$HOST" ] ; then
  echo "HOST environment variable not found!"
  echo ""
  echo "Please follow instructions given in README.md for setting up your environment."
  exit 1
fi

if docker compose version >/dev/null 2>&1 ; then
  DOCKER_COMPOSE="docker compose"
elif docker-compose version >/dev/null 2>&1 ; then
  DOCKER_COMPOSE="docker-compose"
else
  echo "docker compose not present!" >&2
  exit 1
fi

DOCKER_COMPOSE="$DOCKER_COMPOSE -p ${COMPOSE_PROJECT_NAME}"

export BLUERANGE_COMPOSE_SH=1

exec $DOCKER_COMPOSE "$@"
