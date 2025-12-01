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

# Exchange with Tailscale for access token
TAILSCALE_RESPONSE=$(curl -s -X POST "https://api.tailscale.com/api/v2/oauth/token-exchange" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${tailscale_client_id}" \
    -d "jwt=${WEB_IDENTITY_TOKEN}")

ACCESS_TOKEN=$(echo "$TAILSCALE_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: Failed to obtain Tailscale access token" >&2
    echo "$TAILSCALE_RESPONSE" | jq . >&2
    exit 1
fi

# Output the raw token
echo "$ACCESS_TOKEN"
