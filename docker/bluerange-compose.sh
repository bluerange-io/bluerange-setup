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
# advanced configuration goes here, e.g. LDAP

EOF
fi

# due to compatibility reasons (use former BlueRange DB password variable 'DATABASE_PWD' if set)
if [ ! -z "$DATABASE_PWD" ] ; then
  export BLUERANGE_DATABASE_PASSWORD=${DATABASE_PWD}
  echo "Note: Deprecated env variable 'DATABASE_PWD' is set. Use 'BLUERANGE_DATABASE_PASSWORD' env variable instead !!"
fi

set +a
if [ -z "$HOST" ] ; then
  echo "server.env not found!"
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
DOCKER_COMPOSE="$DOCKER_COMPOSE -p ${COMPOSE_PROJECT_NAME} -f docker-compose.yml -f docker-compose.elasticsearch.yml -f docker-compose.mender.yml -f docker-compose.monitoring.yml"
if [ -f "docker-compose.override.yml" ]; then
 DOCKER_COMPOSE="$DOCKER_COMPOSE -f docker-compose.override.yml"
fi
export BLUERANGE_COMPOSE_SH=1

mkdir -p certs/anchors
if [ $# -eq 0 ] ; then
  # maybe move self-signed files to certs folder
  if [ ! -e certs/server.key ] && [ -e ./server.key ] ; then
    mv -v \
       anchors \
       ca.conf ca.crt ca.key ca.pem \
       cert.conf cert.crt cert.csr cert.key cert.pem \
       fullchain.pem \
       index.txt index.txt.attr index.txt.old \
       newcerts \
       serial serial.old \
       server.key server.pem server.rsa \
       certs/
  fi

  pushd certs

  # HTTPS setup using self-signed certificates
  if [ ! -f ./server.key ] && [ ! -L ./server.key ] ; then
    if [ ! -f ./ca.pem ] ; then
      # initialize CA
      echo "$" openssl genrsa -out ca.key 2048
      openssl genrsa -out ca.key 2048
      echo "$" openssl req -new -x509 -key ca.key -out ca.crt
      openssl req -new -x509 -key ca.key -out ca.crt -days 10950
      echo "$" openssl x509 -in ca.crt -out ca.pem
      openssl x509 -in ca.crt -out ca.pem
    fi

    # create CSR
    if [ ! -f cert.csr ] ; then
      export CA_SUBJECT_LINE="$(openssl x509 -in ca.crt -noout -subject -nameopt compat)"
      eval $(echo $CA_SUBJECT_LINE | awk -F '/' '{ for (i=2; i<=NF; i++) { p=index($i,"=");print "export CA_SUBJECT_LINE__"substr($i,1,p)"\""substr($i,p+1)"\"" } }')
      export HOST__DNS=host.that.does.not.match
      export HOST__IP=240.0.0.0 # see <https://superuser.com/questions/698244/ip-address-that-is-the-equivalent-of-dev-null>
      eval $(echo $HOST | awk '{ print "export HOST__"(($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/)?"IP":"DNS")"="$0 }')
      cat > cert.conf << EOF
# see https://gist.github.com/Soarez/9688998
# and https://www.thomas-krenn.com/de/wiki/Openssl_Multi-Domain_CSR_erstellen

# The main section is named req because the command we are using is req
# (openssl req ...)
[ req ]
# This specifies the default key size in bits. If not specified then 512 is
# used. It is used if the -new option is used. It can be overridden by using
# the -newkey option.
default_bits = 2048

# This is the default filename to write a private key to. If not specified the
# key is written to standard output. This can be overridden by the -keyout
# option.
default_keyfile = cert.key

# If this is set to no then if a private key is generated it is not encrypted.
# This is equivalent to the -nodes command line option. For compatibility
# encrypt_rsa_key is an equivalent option.
encrypt_key = no

# This option specifies the digest algorithm to use. Possible values include
# md5 sha1 mdc2. If not present then MD5 is used. This option can be overridden
# on the command line.
default_md = sha256

# if set to the value no this disables prompting of certificate fields and just
# takes values from the config file directly. It also changes the expected
# format of the distinguished_name and attributes sections.
prompt = no

# if set to the value yes then field values to be interpreted as UTF8 strings,
# by default they are interpreted as ASCII. This means that the field values,
# whether prompted from a terminal or obtained from a configuration file, must
# be valid UTF8 strings.
utf8 = yes

# This specifies the section containing the distinguished name fields to
# prompt for when generating a certificate or certificate request.
distinguished_name = req_distinguished_name

# this specifies the configuration file section containing a list of extensions
# to add to the certificate request. It can be overridden by the -reqexts
# command line switch. See the x509v3_config(5) manual page for details of the
# extension section format.
req_extensions = v3_req

[ req_distinguished_name ]
C = $CA_SUBJECT_LINE__C
ST = $CA_SUBJECT_LINE__ST
L = $CA_SUBJECT_LINE__L
O = $CA_SUBJECT_LINE__O
OU = $CA_SUBJECT_LINE__OU
CN = $HOST

[ v3_req ]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth
subjectAltName=@alt_names

[ alt_names ]
DNS.1 = $HOST__DNS
DNS.2 = nginx
DNS.3 = mosquitto
IP.1 = $HOST__IP
EOF
      echo "$" openssl req -new -out cert.csr -config cert.conf
      openssl req -new -out cert.csr -config cert.conf
    else
      echo "$" openssl x509 -in cert.crt -signkey cert.key -x509toreq -out cert.csr
      openssl x509 -in cert.crt -signkey cert.key -x509toreq -out cert.csr
    fi

    # sign CSR, export and verify PE
    cat > ca.conf << EOF
# we use 'ca' as the default section because we're using the ca command
[ ca ]
default_ca = my_ca

[ my_ca ]
#  a text file containing the next serial number to use in hex. Mandatory.
#  This file must be present and contain a valid serial number.
serial = ./serial

# the text database file to use. Mandatory. This file must be present though
# initially it will be empty.
database = ./index.txt

# specifies the directory where new certificates will be placed. Mandatory.
new_certs_dir = ./newcerts

# the file containing the CA certificate. Mandatory
certificate = ./ca.crt

# the file contaning the CA private key. Mandatory
private_key = ./ca.key

# the message digest algorithm. Remember to not use MD5
default_md = sha256

# for how many days will the signed certificate be valid
default_days = 365

# a section with a set of variables corresponding to DN fields
policy = my_policy

# see https://stackoverflow.com/questions/30977264/subject-alternative-name-not-present-in-certificate
copy_extensions = copy

[ my_policy ]
# if the value is "match" then the field value must match the same field in the
# CA certificate. If the value is "supplied" then it must be present.
# Optional means it may be present. Any fields not mentioned are silently
# deleted.
countryName = optional
stateOrProvinceName = optional
organizationName = optional
organizationalUnitName = optional
commonName = supplied
emailAddress = optional
EOF
    mkdir -p newcerts
    if [ ! -f index.txt ] ; then touch index.txt; fi
    if [ ! -f serial ] ; then echo '01' > serial; fi
    SERIAL=$(cat serial)
    echo "$" openssl ca -config ca.conf -extfile cert.conf -out cert.crt -infiles cert.csr
    openssl ca -config ca.conf -extfile cert.conf -out cert.crt -infiles cert.csr
    echo "$" openssl x509 -in newcerts/${SERIAL}.pem -out cert.pem
    openssl x509 -in newcerts/${SERIAL}.pem -out cert.pem
    echo "$" openssl verify -CAfile ca.crt cert.crt
    openssl verify -CAfile ca.crt cert.crt

    # resulting PEMs
    rm -df fullchain.pem
    cp cert.pem server.pem
    rm -df server.key server.rsa
    cp cert.key server.key
  fi
  if [ -f ca.pem ] ; then
    # workaround <https://github.com/docker/compose/issues/5066> by mounting containing folder instead of file
    cp ca.pem anchors
    if [ ! -f fullchain.pem ] ; then
      cat server.pem ca.pem > fullchain.pem
    fi
  fi
  if [ ! -f server.rsa ] ; then
    echo "$" openssl rsa -inform PEM -in server.key -out server.rsa
    openssl rsa -inform PEM -in server.key -out server.rsa
  fi

  popd

  echo "->" $DOCKER_COMPOSE up -d
  $DOCKER_COMPOSE up -d
  echo ""
  echo "-> mender-useradm$" useradm create-user --username=admin@${HOST} --password=${SYSTEM_ADMIN_PASSWORD}
  $DOCKER_COMPOSE exec -T mender-useradm useradm create-user --username=admin@${HOST} --password=${SYSTEM_ADMIN_PASSWORD} || true

  MINIO_ACCESS_KEY=$($DOCKER_COMPOSE exec minio printenv MINIO_ACCESS_KEY | tr -d [:space:] || echo ?)
  MINIO_SECRET_KEY=$($DOCKER_COMPOSE exec minio printenv MINIO_SECRET_KEY | tr -d [:space:] || echo ?)

  echo ""
  echo "    BlueRange: https://${HOST}:${PORT_BLUERANGE:-443}  (admin / ${SYSTEM_ADMIN_PASSWORD})"
  echo "       Mender: https://${HOST}:${PORT_MENDER:-444}  (admin@${HOST} / ${SYSTEM_ADMIN_PASSWORD})"
  echo "      Grafana: https://${HOST}:${PORT_GRAFANA:-3000} (admin / ${SYSTEM_ADMIN_PASSWORD})"
  echo "       Kibana: https://${HOST}:${PORT_KIBANA:-5601} (admin / admin)"
  echo "        Minio: https://${HOST}:${PORT_MINIO:-9000} (${MINIO_ACCESS_KEY} / ${MINIO_SECRET_KEY})"
  echo "     Graphite: http://${HOST}:${PORT_GRAPHITE_9780:-9780}"
  echo "   Prometheus: http://${HOST}:${PORT_PROMETHEUS:-9090}"
  echo "ElasticSearch: https://${HOST}:${PORT_ELASTICSEARCH:-9200} (admin / admin)"
  exit 0
fi

exec $DOCKER_COMPOSE "$@"
