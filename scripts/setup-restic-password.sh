#!/bin/bash

set -euo pipefail

REGION="eu-west-2"
BUCKET="dvp-devbox"

echo "Setting up Restic password in SSM Parameter Store..."

# Generate or prompt for password
read -p "Enter Restic password (leave blank to generate): " RESTIC_PASSWORD

if [ -z "$RESTIC_PASSWORD" ]; then
    RESTIC_PASSWORD=$(openssl rand -base64 32)
    echo "Generated password: ${RESTIC_PASSWORD}"
    echo "SAVE THIS PASSWORD - you will need it for recovery!"
fi

# Store password in SSM
aws ssm put-parameter \
    --name "/devbox/restic/password" \
    --value "${RESTIC_PASSWORD}" \
    --type "SecureString" \
    --region "${REGION}" \
    --overwrite

echo "Created /devbox/restic/password"

# Store bucket name
aws ssm put-parameter \
    --name "/devbox/restic/bucket" \
    --value "${BUCKET}" \
    --type "String" \
    --region "${REGION}" \
    --overwrite

echo "Created /devbox/restic/bucket"

echo ""
echo "Restic configuration stored in SSM."
echo ""
echo "To verify:"
echo "  aws ssm get-parameter --name /devbox/restic/password --with-decryption --region ${REGION}"
echo ""
echo "Backup locations in s3://${BUCKET}:"
echo "  - restic/config  (user configuration files)"
echo "  - restic/data    (user data files)"
