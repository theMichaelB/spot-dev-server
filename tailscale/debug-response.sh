#!/bin/bash

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/tailscale.env"

TOKEN_RESPONSE=$(aws sts get-web-identity-token \
    --audience "${tailscale_audience}" \
    --signing-algorithm ES384 \
    --duration-seconds 60)

WEB_IDENTITY_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.WebIdentityToken')

echo "=== Full HTTP Response ==="
curl -i -s -X POST "https://api.tailscale.com/api/v2/oauth/token-exchange" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${tailscale_client_id}" \
    -d "jwt=${WEB_IDENTITY_TOKEN}"
