#!/bin/bash
set -euo pipefail

REGION="${REGION:-eu-west-2}"
SSM_PREFIX="/devbox/tailscale"
HOSTED_ZONE_ID="Z05005861OEGFVGL0OT2I"
DNS_NAME="aws-devbox.dvp.sh"

echo "Fetching Tailscale OIDC configuration from SSM..."
TAILSCALE_CLIENT_ID=$(aws ssm get-parameter \
    --name "${SSM_PREFIX}/client_id" \
    --with-decryption \
    --region "${REGION}" \
    --query 'Parameter.Value' \
    --output text)

TAILSCALE_AUDIENCE=$(aws ssm get-parameter \
    --name "${SSM_PREFIX}/audience" \
    --with-decryption \
    --region "${REGION}" \
    --query 'Parameter.Value' \
    --output text)

echo "Generating AWS web identity token..."
TOKEN_RESPONSE=$(aws sts get-web-identity-token \
    --audience "${TAILSCALE_AUDIENCE}" \
    --signing-algorithm ES384 \
    --duration-seconds 60)

WEB_IDENTITY_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.WebIdentityToken')

if [ -z "$WEB_IDENTITY_TOKEN" ] || [ "$WEB_IDENTITY_TOKEN" = "null" ]; then
    echo "Error: Failed to obtain web identity token" >&2
    exit 1
fi

echo "Authenticating Tailscale with OIDC..."
tailscale up \
    --client-id="${TAILSCALE_CLIENT_ID}" \
    --id-token="${WEB_IDENTITY_TOKEN}" \
    --advertise-tags="tag:aws" \
    --accept-routes \
    --ssh 

echo "Tailscale authenticated successfully"
tailscale status

# Get Tailscale IP address
TAILSCALE_IP=$(tailscale ip -4)

if [ -z "$TAILSCALE_IP" ]; then
    echo "Error: Failed to get Tailscale IP address" >&2
    exit 1
fi

echo "Tailscale IP: ${TAILSCALE_IP}"

# Update Route53 record
echo "Updating Route53 record ${DNS_NAME} -> ${TAILSCALE_IP}..."
aws route53 change-resource-record-sets \
    --hosted-zone-id "${HOSTED_ZONE_ID}" \
    --change-batch '{
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'"${DNS_NAME}"'",
                "Type": "A",
                "TTL": 60,
                "ResourceRecords": [{"Value": "'"${TAILSCALE_IP}"'"}]
            }
        }]
    }'

echo "Route53 record updated successfully"
