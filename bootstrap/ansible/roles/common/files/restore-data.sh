#!/bin/bash
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-eu-west-2}"
BUCKET=$(aws ssm get-parameter --name "/devbox/restic/bucket" --region "${REGION}" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
REPO="s3:s3.${REGION}.amazonaws.com/${BUCKET}/restic/data"

if [ -z "$BUCKET" ]; then
    echo "No restic bucket configured in SSM, skipping data restore"
    exit 0
fi

# Get restic password from SSM
export RESTIC_PASSWORD=$(aws ssm get-parameter --name "/devbox/restic/password" --with-decryption --region "${REGION}" --query 'Parameter.Value' --output text 2>/dev/null || echo "")
export RESTIC_REPOSITORY="${REPO}"

if [ -z "$RESTIC_PASSWORD" ]; then
    echo "No restic password configured in SSM, skipping data restore"
    exit 0
fi

# Check if repo exists
if ! restic snapshots &>/dev/null; then
    echo "No data backup repository found, skipping restore"
    exit 0
fi

# Check for snapshots
SNAPSHOT_COUNT=$(restic snapshots --tag data --json 2>/dev/null | jq length)
if [ "$SNAPSHOT_COUNT" -eq 0 ]; then
    echo "No data snapshots found, skipping restore"
    exit 0
fi

echo "Restoring data files from latest snapshot..."
restic restore latest --tag data --target / --verbose

echo "Data restore complete"
