#!/bin/bash
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-eu-west-2}"
BUCKET=$(aws ssm get-parameter --name "/devbox/restic/bucket" --region "${REGION}" --query 'Parameter.Value' --output text)
REPO="s3:s3.${REGION}.amazonaws.com/${BUCKET}/restic/data"

# Get restic password from SSM
export RESTIC_PASSWORD=$(aws ssm get-parameter --name "/devbox/restic/password" --with-decryption --region "${REGION}" --query 'Parameter.Value' --output text)
export RESTIC_REPOSITORY="${REPO}"

DATA_DIR="${HOME}/data"

if [ ! -d "${DATA_DIR}" ]; then
    echo "No ~/data directory found"
    exit 0
fi

# Initialize repo if needed
if ! restic snapshots &>/dev/null; then
    echo "Initializing restic repository..."
    restic init
fi

echo "Backing up ~/data..."
restic backup "${DATA_DIR}" --tag data --verbose

echo "Cleaning up old snapshots..."
restic forget --tag data --keep-last 10 --keep-daily 7 --keep-weekly 4 --prune

echo "Data backup complete"
restic snapshots --tag data
