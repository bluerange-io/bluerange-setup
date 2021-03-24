#!/bin/sh

set -e

# workaround for IOT-4680 to disable http2 in nginx config
sed -i 's/listen 443 ssl http2;/listen 443 ssl;/' /usr/local/openresty/nginx/conf/nginx.conf && \
    # and call default entrypoint
    exec /entrypoint.sh