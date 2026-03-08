#!/bin/bash

# Script to package and deploy Voice Service Lambda
# Run this locally (not in CloudShell) as it requires Docker

set -e

echo "=========================================="
echo "Deploying Voice Service Lambda"
echo "=========================================="

# Configuration
FUNCTION_NAME="bolkhata-voice-service"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/BolKhataLambdaExecutionRole"

# VPC Configuration
VPC_SUBNET_IDS="subnet-04633796d907065d4,subnet-0510d6523d3d0d03a"
VPC_SECURITY_GROUP_IDS="sg-0c1a8c0a13b60da51,sg-01435e8b83104a0a7"

# Secrets ARNs
DB_SECRET_ARN="arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:bolkhata/db-credentials-XrC6vd"
API_SECRET_ARN="arn:aws:secretsmanager:${REGION}:${ACCOUNT_ID}:secret:bolkhata/api-keys-csMpGk"
S3_BUCKET="bolkhata-audio-files-${ACCOUNT_ID}"

echo "Account ID: $ACCOUNT_ID"
echo "Function: $FUNCTION_NAME"
echo ""

# Create deployment package directory
echo "1. Preparing deployment package..."
rm -rf lambda/voice-service/package
mkdir -p lambda/voice-service/package

# Copy application code
cp -r voice-service/app lambda/voice-service/package/
cp lambda/voice-service/lambda_handler.py lambda/voice-service/package/

# Install dependencies using Docker (for Lambda compatibility)
echo "2. Installing dependencies (this may take a few minutes)..."
docker run --rm \
    -v "$(pwd)/lambda/voice-service":/var/task \
    public.ecr.aws/lambda/python:3.11 \
    pip install -r requirements.txt -t package/

# Create deployment ZIP
echo "3. Creating deployment package..."
cd lambda/voice-service/package
zip -r ../voice-service-lambda.zip . -q
cd ../../..

PACKAGE_SIZE=$(du -h lambda/voice-service/voice-service-lambda.zip | cut -f1)
echo "✓ Package created: $PACKAGE_SIZE"
echo ""

# Check if function exists
echo "4. Checking if Lambda function exists..."
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION 2>/dev/null; then
    echo "Function exists, updating code..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://lambda/voice-service/voice-service-lambda.zip \
        --region $REGION
    
    echo "Waiting for update to complete..."
    aws lambda wait function-updated --function-name $FUNCTION_NAME --region $REGION
    
    echo "Updating configuration..."
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --environment "Variables={
            DB_SECRET_ARN=${DB_SECRET_ARN},
            API_SECRET_ARN=${API_SECRET_ARN},
            S3_BUCKET=${S3_BUCKET},
            AWS_REGION=${REGION}
        }" \
        --region $REGION
else
    echo "Creating new Lambda function..."
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime python3.11 \
        --role $LAMBDA_ROLE_ARN \
        --handler lambda_handler.lambda_handler \
        --zip-file fileb://lambda/voice-service/voice-service-lambda.zip \
        --timeout 30 \
        --memory-size 512 \
        --environment "Variables={
            DB_SECRET_ARN=${DB_SECRET_ARN},
            API_SECRET_ARN=${API_SECRET_ARN},
            S3_BUCKET=${S3_BUCKET},
            AWS_REGION=${REGION}
        }" \
        --vpc-config "SubnetIds=${VPC_SUBNET_IDS},SecurityGroupIds=${VPC_SECURITY_GROUP_IDS}" \
        --region $REGION
fi

echo ""
echo "5. Configuring provisioned concurrency (zero cold starts)..."
# Wait for function to be active
aws lambda wait function-active --function-name $FUNCTION_NAME --region $REGION

# Publish version
VERSION=$(aws lambda publish-version \
    --function-name $FUNCTION_NAME \
    --region $REGION \
    --query 'Version' \
    --output text)

echo "Published version: $VERSION"

# Create or update alias
aws lambda create-alias \
    --function-name $FUNCTION_NAME \
    --name production \
    --function-version $VERSION \
    --region $REGION \
    2>/dev/null || \
aws lambda update-alias \
    --function-name $FUNCTION_NAME \
    --name production \
    --function-version $VERSION \
    --region $REGION

# Set provisioned concurrency (1 instance always warm)
aws lambda put-provisioned-concurrency-config \
    --function-name $FUNCTION_NAME \
    --provisioned-concurrent-executions 1 \
    --qualifier production \
    --region $REGION \
    2>/dev/null || echo "Provisioned concurrency already configured"

echo ""
echo "=========================================="
echo "Voice Service Lambda Deployed!"
echo "=========================================="
echo ""
echo "Function Name: $FUNCTION_NAME"
echo "Version: $VERSION"
echo "Alias: production"
echo "Provisioned Concurrency: 1 (zero cold starts)"
echo "Memory: 512 MB"
echo "Timeout: 30 seconds"
echo ""
echo "Function ARN:"
FUNCTION_ARN=$(aws lambda get-function \
    --function-name $FUNCTION_NAME \
    --region $REGION \
    --query 'Configuration.FunctionArn' \
    --output text)
echo "$FUNCTION_ARN"
echo ""
echo "Next: Create API Gateway to expose this function"
echo ""
