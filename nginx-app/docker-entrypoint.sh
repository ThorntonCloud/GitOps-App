#!/bin/sh
envsubst < /tmp/index.html.template > /usr/share/nginx/html/index.html
exec "$@"