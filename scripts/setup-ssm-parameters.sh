#!/bin/bash

set -euo pipefail

REGION="eu-west-2"

# Tailscale OIDC configuration
read -p "Enter Tailscale Client ID: " TAILSCALE_CLIENT_ID
read -p "Enter Tailscale Audience (e.g., api.tailscale.com/<client_id>): " TAILSCALE_AUDIENCE

echo "Creating SSM parameters in ${REGION}..."

# Tailscale client ID
aws ssm put-parameter \
    --name "/devbox/tailscale/client_id" \
    --value "${TAILSCALE_CLIENT_ID}" \
    --type "SecureString" \
    --region "${REGION}" \
    --overwrite

echo "Created /devbox/tailscale/client_id"

# Tailscale audience
aws ssm put-parameter \
    --name "/devbox/tailscale/audience" \
    --value "${TAILSCALE_AUDIENCE}" \
    --type "SecureString" \
    --region "${REGION}" \
    --overwrite

echo "Created /devbox/tailscale/audience"

echo ""
echo "SSM parameters created successfully!"
echo ""
echo "To verify:"
echo "  aws ssm get-parameters-by-path --path /devbox/tailscale --region ${REGION}"
