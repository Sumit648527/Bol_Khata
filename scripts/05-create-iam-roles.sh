#!/bin/bash

# Script to create IAM roles for Lambda functions
# Run this in AWS CloudShell

set -e

echo "=========================================="
echo "Creating IAM Roles for Lambda Functions"
echo "=========================================="

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "AWS Account ID: $ACCOUNT_ID"
echo ""

# 1. Create trust policy for Lambda
cat > /tmp/lambda-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# 2. Create Lambda execution role
echo "1. Creating Lambda execution role..."
aws iam create-role \
    --role-name BolKhataLambdaExecutionRole \
    --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
    --description "Execution role for Bol Khata Lambda functions" \
    2>/dev/null || echo "Role already exists, continuing..."

# 3. Attach AWS managed policies
echo "2. Attaching AWS managed policies..."

# Basic Lambda execution (CloudWatch Logs)
aws iam attach-role-policy \
    --role-name BolKhataLambdaExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# VPC access for Lambda
aws iam attach-role-policy \
    --role-name BolKhataLambdaExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole

echo "✓ AWS managed policies attached"
echo ""

# 4. Create custom policy for application-specific permissions
echo "3. Creating custom policy for application permissions..."
cat > /tmp/bolkhata-lambda-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SecretsManagerAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:bolkhata/*"
      ]
    },
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::bolkhata-audio-files-${ACCOUNT_ID}",
        "arn:aws:s3:::bolkhata-audio-files-${ACCOUNT_ID}/*"
      ]
    },
    {
      "Sid": "BedrockAccess",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": [
        "arn:aws:bedrock:${REGION}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
      ]
    },
    {
      "Sid": "CloudWatchMetrics",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
    --policy-name BolKhataLambdaApplicationPolicy \
    --policy-document file:///tmp/bolkhata-lambda-policy.json \
    --description "Application-specific permissions for Bol Khata Lambda functions" \
    2>/dev/null || echo "Policy already exists, continuing..."

# Attach custom policy
aws iam attach-role-policy \
    --role-name BolKhataLambdaExecutionRole \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/BolKhataLambdaApplicationPolicy

echo "✓ Custom policy created and attached"
echo ""

# Wait for role to be available
echo "4. Waiting for IAM role to propagate..."
sleep 10

# Get role ARN
ROLE_ARN=$(aws iam get-role \
    --role-name BolKhataLambdaExecutionRole \
    --query 'Role.Arn' \
    --output text)

echo ""
echo "=========================================="
echo "IAM Roles Created Successfully!"
echo "=========================================="
echo ""
echo "Role ARN: $ROLE_ARN"
echo ""
echo "Permissions granted:"
echo "  ✓ CloudWatch Logs (logging)"
echo "  ✓ VPC Access (connect to RDS)"
echo "  ✓ Secrets Manager (read credentials)"
echo "  ✓ S3 (audio file storage)"
echo "  ✓ Amazon Bedrock (Claude 3 Haiku AI)"
echo "  ✓ CloudWatch Metrics (monitoring)"
echo ""
echo "Save this for Lambda creation:"
echo "LAMBDA_ROLE_ARN=$ROLE_ARN"
echo ""
