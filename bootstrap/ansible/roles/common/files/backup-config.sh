#!/bin/bash
set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-eu-west-2}"
BUCKET=$(aws ssm get-parameter --name "/devbox/restic/bucket" --region "${REGION}" --query 'Parameter.Value' --output text)
REPO="s3:s3.${REGION}.amazonaws.com/${BUCKET}/restic/config"

# Get restic password from SSM
export RESTIC_PASSWORD=$(aws ssm get-parameter --name "/devbox/restic/password" --with-decryption --region "${REGION}" --query 'Parameter.Value' --output text)
export RESTIC_REPOSITORY="${REPO}"

# Initialize repo if needed
if ! restic snapshots &>/dev/null; then
    echo "Initializing restic repository..."
    restic init
fi

# Config files to backup
CONFIG_FILES=(
    ".bashrc"
    ".bash_profile"
    ".profile"
    ".zshrc"
    ".vimrc"
    ".gitconfig"
    ".ssh"
    ".config"
    ".local/share/claude"
    ".claude"
)

# Build list of existing files to backup
FILES_TO_BACKUP=()
for file in "${CONFIG_FILES[@]}"; do
    if [ -e "${HOME}/${file}" ]; then
        FILES_TO_BACKUP+=("${HOME}/${file}")
    fi
done

if [ ${#FILES_TO_BACKUP[@]} -eq 0 ]; then
    echo "No config files found to backup"
    exit 0
fi

echo "Backing up configuration files..."
restic backup --tag config --verbose -e ~/data/* ~/

echo "Cleaning up old snapshots..."
restic forget --tag config --keep-last 10 --keep-daily 7 --keep-weekly 4 --prune

echo "Config backup complete"
restic snapshots --tag config
