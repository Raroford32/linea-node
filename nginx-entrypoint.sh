#!/bin/bash

# Script to configure nginx with domain support
# This script processes the nginx.conf template with environment variables

set -e

# Default values
DOMAIN_NAME="${DOMAIN_NAME:-localhost}"
PUBLIC_IP="${PUBLIC_IP:-127.0.0.1}"

echo "Configuring nginx with domain: $DOMAIN_NAME"

# Create the nginx configuration from template
envsubst '${DOMAIN_NAME}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# Test nginx configuration
nginx -t

# Start nginx
exec nginx -g 'daemon off;'