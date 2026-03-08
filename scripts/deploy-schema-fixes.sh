#!/bin/bash

# Complete deployment script to fix all schema issues
# Run this from AWS CloudShell

set -e

EC2_IP="54.225.178.7"
KEY_FILE="bolkhata-key.pem"

echo "=========================================="
echo "Deploying Schema Fixes to EC2"
echo "=========================================="

# Upload the fix script
echo "1. Uploading fix script to EC2..."
scp -i $KEY_FILE scripts/15-fix-all-schema-issues.sh ec2-user@$EC2_IP:/tmp/

# Make it executable and run it
echo "2. Running fix script on EC2..."
ssh -i $KEY_FILE ec2-user@$EC2_IP << 'ENDSSH'
chmod +x /tmp/15-fix-all-schema-issues.sh
sudo /tmp/15-fix-all-schema-issues.sh
ENDSSH

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "All schema issues have been fixed."
echo "The application should now work correctly with RDS."
echo ""
echo "Test the application at: http://54.225.178.7"
