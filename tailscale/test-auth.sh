#!/bin/bash

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/tailscale.env"

echo "Step 1: Obtaining AWS web identity token..."

# Get web identity token from AWS STS
TOKEN_RESPONSE=$(aws sts get-web-identity-token \
    --audience "${tailscale_audience}" \
    --signing-algorithm ES384 \
    --duration-seconds 60)

WEB_IDENTITY_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.WebIdentityToken')

if [ -z "$WEB_IDENTITY_TOKEN" ] || [ "$WEB_IDENTITY_TOKEN" = "null" ]; then
    echo "Error: Failed to obtain web identity token"
    exit 1
fi

echo "✓ Successfully obtained web identity token"

# Decode and display token claims (for debugging)
echo ""
echo "Token claims:"
echo "$WEB_IDENTITY_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq . || echo "(Could not decode token)"
echo ""

echo "Step 2: Exchanging token with Tailscale..."

# Exchange the token with Tailscale for an access token
TAILSCALE_RESPONSE=$(curl -s -X POST "https://api.tailscale.com/api/v2/oauth/token-exchange" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=${tailscale_client_id}" \
    -d "jwt=${WEB_IDENTITY_TOKEN}")

echo "$TAILSCALE_RESPONSE" | jq .

ACCESS_TOKEN=$(echo "$TAILSCALE_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
    echo "Error: Failed to obtain Tailscale access token"
    echo "Response: $TAILSCALE_RESPONSE"
    exit 1
fi

echo "✓ Successfully obtained Tailscale access token"
