#!/bin/bash

# Script to create S3 bucket for Bol Khata audio files
# Run this in AWS CloudShell

set -e

echo "=========================================="
echo "Creating S3 Bucket for Audio Files"
echo "=========================================="

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Define bucket name (must be globally unique)
BUCKET_NAME="bolkhata-audio-files-${ACCOUNT_ID}"
REGION="us-east-1"

echo "Bucket name: $BUCKET_NAME"
echo "Region: $REGION"
echo ""

# Create the bucket
echo "Creating S3 bucket..."
aws s3 mb s3://${BUCKET_NAME} --region ${REGION}

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled

# Enable encryption (AES256)
echo "Enabling encryption..."
aws s3api put-bucket-encryption \
    --bucket ${BUCKET_NAME} \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }'

# Block all public access
echo "Blocking public access..."
aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration \
        "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create lifecycle policy for cost optimization
echo "Creating lifecycle policy..."
cat > /tmp/lifecycle-policy.json << 'EOF'
{
    "Rules": [
        {
            "Id": "archive-old-audio",
            "Status": "Enabled",
            "Filter": {
                "Prefix": ""
            },
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "INTELLIGENT_TIERING"
                }
            ],
            "Expiration": {
                "Days": 365
            }
        }
    ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
    --bucket ${BUCKET_NAME} \
    --lifecycle-configuration file:///tmp/lifecycle-policy.json

# Add tags
echo "Adding tags..."
aws s3api put-bucket-tagging \
    --bucket ${BUCKET_NAME} \
    --tagging 'TagSet=[{Key=Project,Value=BolKhata},{Key=Environment,Value=Production},{Key=Purpose,Value=AudioStorage}]'

echo ""
echo "=========================================="
echo "S3 Bucket Created Successfully!"
echo "=========================================="
echo ""
echo "Bucket Details:"
echo "  Name: ${BUCKET_NAME}"
echo "  Region: ${REGION}"
echo "  Versioning: Enabled"
echo "  Encryption: AES256"
echo "  Public Access: Blocked"
echo "  Lifecycle: Archive after 30 days, delete after 365 days"
echo ""
echo "Save this bucket name for next steps:"
echo "S3_BUCKET_NAME=${BUCKET_NAME}"
echo ""
