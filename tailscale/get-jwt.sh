#!/bin/bash

set -e

# Source environment variables
source /home/admin/tailscale/tailscale.env

# Get AWS web identity token
TOKEN_RESPONSE=$(aws sts get-web-identity-token \
    --audience "${tailscale_audience}" \
    --signing-algorithm ES384 \
    --duration-seconds 60)

WEB_IDENTITY_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.WebIdentityToken')

if [ -z "$WEB_IDENTITY_TOKEN" ] || [ "$WEB_IDENTITY_TOKEN" = "null" ]; then
    echo "Error: Failed to obtain web identity token" >&2
    exit 1
fi


# Output the raw token
echo "$WEB_IDENTITY_TOKEN"
