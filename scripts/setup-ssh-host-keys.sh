#!/bin/bash

set -euo pipefail

REGION="eu-west-2"
SSM_PREFIX="/devbox/ssh"

echo "Setting up SSH host keys in SSM Parameter Store..."
echo "This ensures the devbox has consistent host keys across rebuilds."
echo ""

# Check if keys already exist
EXISTING=$(aws ssm get-parameters-by-path --path "${SSM_PREFIX}" --region "${REGION}" --query 'Parameters[].Name' --output text 2>/dev/null || echo "")

if [ -n "$EXISTING" ]; then
    read -p "SSH host keys already exist in SSM. Overwrite? (y/N): " OVERWRITE
    if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Create temporary directory
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Generating new SSH host keys..."

# Generate all key types
ssh-keygen -t rsa -b 4096 -f "${TMPDIR}/ssh_host_rsa_key" -N "" -C "aws-devbox"
ssh-keygen -t ecdsa -b 521 -f "${TMPDIR}/ssh_host_ecdsa_key" -N "" -C "aws-devbox"
ssh-keygen -t ed25519 -f "${TMPDIR}/ssh_host_ed25519_key" -N "" -C "aws-devbox"

echo "Uploading keys to SSM..."

# Upload private keys
for keytype in rsa ecdsa ed25519; do
    aws ssm put-parameter \
        --name "${SSM_PREFIX}/ssh_host_${keytype}_key" \
        --value "$(cat ${TMPDIR}/ssh_host_${keytype}_key)" \
        --type "SecureString" \
        --region "${REGION}" \
        --overwrite
    echo "  Uploaded ${SSM_PREFIX}/ssh_host_${keytype}_key"

    aws ssm put-parameter \
        --name "${SSM_PREFIX}/ssh_host_${keytype}_key.pub" \
        --value "$(cat ${TMPDIR}/ssh_host_${keytype}_key.pub)" \
        --type "String" \
        --region "${REGION}" \
        --overwrite
    echo "  Uploaded ${SSM_PREFIX}/ssh_host_${keytype}_key.pub"
done

echo ""
echo "SSH host keys stored in SSM successfully!"
echo ""
echo "Public key fingerprints:"
for keytype in rsa ecdsa ed25519; do
    ssh-keygen -lf "${TMPDIR}/ssh_host_${keytype}_key.pub"
done
echo ""
echo "Add these to your known_hosts for aws-devbox.dvp.sh"
