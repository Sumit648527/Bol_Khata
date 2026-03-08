#!/bin/bash

# Script to deploy Bol Khata application to EC2
# Run this locally after EC2 instance is created

set -e

echo "=========================================="
echo "Deploying Bol Khata to EC2"
echo "=========================================="

# Configuration - UPDATE THESE VALUES
EC2_IP="${1:-}"  # Pass as first argument or set here
KEY_FILE="${2:-bolkhata-key.pem}"  # Pass as second argument or set here

if [ -z "$EC2_IP" ]; then
    echo "Error: EC2 IP address required"
    echo "Usage: ./08-deploy-to-ec2.sh <EC2_IP> [KEY_FILE]"
    echo "Example: ./08-deploy-to-ec2.sh 54.123.45.67 bolkhata-key.pem"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "Error: Key file $KEY_FILE not found"
    exit 1
fi

echo "EC2 IP: $EC2_IP"
echo "Key File: $KEY_FILE"
echo ""

# Test SSH connection
echo "1. Testing SSH connection..."
ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=10 ec2-user@$EC2_IP "echo 'SSH connection successful'" || {
    echo "Error: Cannot connect to EC2 instance"
    echo "Make sure:"
    echo "  - Instance is running"
    echo "  - Security group allows SSH from your IP"
    echo "  - Key file has correct permissions (chmod 400 $KEY_FILE)"
    exit 1
}
echo "✓ SSH connection successful"
echo ""

# 2. Create deployment package
echo "2. Creating deployment package..."
rm -rf deploy-package
mkdir -p deploy-package

# Copy application files
cp -r banking-service deploy-package/
cp -r voice-service deploy-package/
cp -r web-ui deploy-package/
cp -r database deploy-package/

# Create deployment archive
tar -czf bolkhata-app.tar.gz -C deploy-package .
echo "✓ Deployment package created"
echo ""

# 3. Upload to EC2
echo "3. Uploading application to EC2..."
scp -i $KEY_FILE -o StrictHostKeyChecking=no bolkhata-app.tar.gz ec2-user@$EC2_IP:/tmp/
echo "✓ Upload complete"
echo ""

# 4. Deploy on EC2
echo "4. Deploying application on EC2..."
ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$EC2_IP << 'ENDSSH'
set -e

echo "=========================================="
echo "Setting up application on EC2"
echo "=========================================="

# Extract application
echo "Extracting application..."
cd /opt/bolkhata
sudo tar -xzf /tmp/bolkhata-app.tar.gz
sudo chown -R ec2-user:ec2-user /opt/bolkhata

# Get secrets from AWS Secrets Manager
echo "Fetching secrets from AWS Secrets Manager..."
REGION="us-east-1"

# Get database credentials
DB_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id bolkhata/db-credentials \
    --region $REGION \
    --query SecretString \
    --output text)

DB_HOST=$(echo $DB_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['host'])")
DB_PORT=$(echo $DB_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['port'])")
DB_NAME=$(echo $DB_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['database'])")
DB_USER=$(echo $DB_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['username'])")
DB_PASS=$(echo $DB_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")

# Get API keys
API_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id bolkhata/api-keys \
    --region $REGION \
    --query SecretString \
    --output text)

SARVAM_KEY=$(echo $API_SECRET | python3 -c "import sys, json; print(json.load(sys.stdin)['sarvam'])")

# Get JWT secret
JWT_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id bolkhata/jwt-secret \
    --region $REGION \
    --query SecretString \
    --output text | python3 -c "import sys, json; print(json.load(sys.stdin)['secret'])")

S3_BUCKET="bolkhata-audio-files-727207463156"

echo "✓ Secrets retrieved"

# Initialize database schema
echo "Initializing database schema..."
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f /opt/bolkhata/database/init-schema.sql || echo "Schema already exists"
echo "✓ Database initialized"

# Configure Banking Service
echo "Configuring Banking Service..."
cd /opt/bolkhata/banking-service

# Create application-aws.properties
cat > src/main/resources/application-aws.properties << EOF
# Database Configuration
spring.datasource.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASS}
spring.datasource.driver-class-name=org.postgresql.Driver

# JPA Configuration
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect

# Server Configuration
server.port=8080

# JWT Configuration
jwt.secret=${JWT_SECRET}
jwt.expiration=86400000

# AWS Configuration
aws.region=${REGION}
aws.s3.bucket=${S3_BUCKET}

# File Upload
spring.servlet.multipart.max-file-size=50MB
spring.servlet.multipart.max-request-size=50MB

# Audio Storage
audio.storage.path=/opt/bolkhata/audio-files
audio.storage.type=s3
EOF

# Build Banking Service
echo "Building Banking Service..."
mvn clean package -DskipTests
echo "✓ Banking Service built"

# Configure Voice Service
echo "Configuring Voice Service..."
cd /opt/bolkhata/voice-service

# Create .env file
cat > .env << EOF
# Database Configuration
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}

# Sarvam AI Configuration
SARVAM_API_KEY=${SARVAM_KEY}
SARVAM_API_URL=https://api.sarvam.ai/speech-to-text

# AWS Configuration
AWS_REGION=${REGION}
S3_BUCKET=${S3_BUCKET}

# Server Configuration
PORT=8000
EOF

# Install Python dependencies
echo "Installing Python dependencies..."
python3.11 -m pip install --user -r requirements.txt
echo "✓ Voice Service configured"

# Update frontend configuration
echo "Configuring frontend..."
cd /opt/bolkhata/web-ui

# Update API endpoints in JavaScript files
sed -i "s|http://localhost:8080|http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)|g" *.js || true
sed -i "s|http://localhost:8000|http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/voice|g" *.js || true

echo "✓ Frontend configured"

# Start services
echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl restart bolkhata-banking
sudo systemctl restart bolkhata-voice
sudo systemctl restart nginx

# Enable services to start on boot
sudo systemctl enable bolkhata-banking
sudo systemctl enable bolkhata-voice
sudo systemctl enable nginx

echo "✓ Services started"

# Wait a moment for services to start
sleep 5

# Check service status
echo ""
echo "Service Status:"
sudo systemctl status bolkhata-banking --no-pager | head -n 10
sudo systemctl status bolkhata-voice --no-pager | head -n 10
sudo systemctl status nginx --no-pager | head -n 10

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
ENDSSH

echo ""
echo "=========================================="
echo "Deployment Successful!"
echo "=========================================="
echo ""
echo "Application URLs:"
echo "  Frontend: http://${EC2_IP}"
echo "  Banking API: http://${EC2_IP}/api"
echo "  Voice API: http://${EC2_IP}/voice"
echo ""
echo "Test the application:"
echo "  curl http://${EC2_IP}/api/health"
echo "  curl http://${EC2_IP}/voice/health"
echo ""
echo "View logs:"
echo "  ssh -i $KEY_FILE ec2-user@$EC2_IP"
echo "  sudo journalctl -u bolkhata-banking -f"
echo "  sudo journalctl -u bolkhata-voice -f"
echo ""
echo "Clean up deployment package:"
rm -rf deploy-package bolkhata-app.tar.gz
echo "✓ Cleanup complete"
echo ""
