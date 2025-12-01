#!/bin/bash

set -euo pipefail

# Configuration
BUCKET_NAME="dvp-devbox"
TABLE_NAME="dvp-devbox-lock"
REGION="eu-west-2"

echo "Setting up Terraform backend infrastructure in ${REGION}..."

# Create S3 bucket for state storage
echo "Creating S3 bucket: ${BUCKET_NAME}"
aws s3api create-bucket \
    --bucket "${BUCKET_NAME}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}"

# Enable versioning on the bucket
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

# Enable server-side encryption by default
echo "Enabling default encryption..."
aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }
        ]
    }'

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration '{
        "BlockPublicAcls": true,
        "IgnorePublicAcls": true,
        "BlockPublicPolicy": true,
        "RestrictPublicBuckets": true
    }'

# Create DynamoDB table for state locking
echo "Creating DynamoDB table: ${TABLE_NAME}"
aws dynamodb create-table \
    --table-name "${TABLE_NAME}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

# Wait for table to be active
echo "Waiting for DynamoDB table to become active..."
aws dynamodb wait table-exists \
    --table-name "${TABLE_NAME}" \
    --region "${REGION}"

echo ""
echo "Terraform backend setup complete!"
echo ""
echo "Add this to your Terraform configuration:"
echo ""
cat <<'EOF'
terraform {
  backend "s3" {
    bucket         = "dvp-devbox"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "dvp-devbox-lock"
    encrypt        = true
  }
}
EOF
