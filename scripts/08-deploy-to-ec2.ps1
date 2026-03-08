# PowerShell deployment script for Windows
# Deploy Bol Khata to EC2

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2_IP,
    
    [Parameter(Mandatory=$false)]
    [string]$KEY_FILE = "bolkhata-key.pem"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deploying Bol Khata to EC2" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "EC2 IP: $EC2_IP"
Write-Host "Key File: $KEY_FILE"
Write-Host ""

# Test SSH connection
Write-Host "1. Testing SSH connection..." -ForegroundColor Yellow
try {
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$EC2_IP "echo 'SSH connection successful'" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ SSH connection successful" -ForegroundColor Green
    } else {
        throw "SSH connection failed"
    }
} catch {
    Write-Host "Error: Cannot connect to EC2 instance" -ForegroundColor Red
    Write-Host "Make sure:" -ForegroundColor Yellow
    Write-Host "  - Instance is running"
    Write-Host "  - Security group allows SSH from your IP"
    Write-Host "  - Key file path is correct"
    exit 1
}
Write-Host ""

# Create deployment package
Write-Host "2. Creating deployment package..." -ForegroundColor Yellow
if (Test-Path "deploy-package") {
    Remove-Item -Recurse -Force deploy-package
}
New-Item -ItemType Directory -Path deploy-package | Out-Null

# Copy application files
Copy-Item -Recurse banking-service deploy-package/
Copy-Item -Recurse voice-service deploy-package/
Copy-Item -Recurse web-ui deploy-package/
Copy-Item -Recurse database deploy-package/

# Create tar.gz using tar (available in Windows 10+)
tar -czf bolkhata-app.tar.gz -C deploy-package .
Write-Host "✓ Deployment package created" -ForegroundColor Green
Write-Host ""

# Upload to EC2
Write-Host "3. Uploading application to EC2..." -ForegroundColor Yellow
scp -i $KEY_FILE -o StrictHostKeyChecking=no bolkhata-app.tar.gz ec2-user@${EC2_IP}:/tmp/
Write-Host "✓ Upload complete" -ForegroundColor Green
Write-Host ""

# Deploy on EC2
Write-Host "4. Deploying application on EC2..." -ForegroundColor Yellow
Write-Host "   This will take 10-15 minutes..." -ForegroundColor Yellow
Write-Host ""

$deployScript = @'
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
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f /opt/bolkhata/database/init-schema.sql 2>&1 | grep -v "already exists" || echo "✓ Schema initialized"

# Configure Banking Service
echo "Configuring Banking Service..."
cd /opt/bolkhata/banking-service

# Create application-aws.properties
cat > src/main/resources/application-aws.properties << EOF
spring.datasource.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASS}
spring.datasource.driver-class-name=org.postgresql.Driver
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
server.port=8080
jwt.secret=${JWT_SECRET}
jwt.expiration=86400000
aws.region=${REGION}
aws.s3.bucket=${S3_BUCKET}
spring.servlet.multipart.max-file-size=50MB
spring.servlet.multipart.max-request-size=50MB
audio.storage.path=/opt/bolkhata/audio-files
audio.storage.type=s3
EOF

# Build Banking Service
echo "Building Banking Service (this takes 5-10 minutes)..."
mvn clean package -DskipTests
echo "✓ Banking Service built"

# Configure Voice Service
echo "Configuring Voice Service..."
cd /opt/bolkhata/voice-service

cat > .env << EOF
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASS}
SARVAM_API_KEY=${SARVAM_KEY}
SARVAM_API_URL=https://api.sarvam.ai/speech-to-text
AWS_REGION=${REGION}
S3_BUCKET=${S3_BUCKET}
PORT=8000
EOF

# Install Python dependencies
echo "Installing Python dependencies..."
python3.11 -m pip install --user -r requirements.txt
echo "✓ Voice Service configured"

# Update frontend configuration
echo "Configuring frontend..."
cd /opt/bolkhata/web-ui
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
find . -name "*.js" -type f -exec sed -i "s|http://localhost:8080|http://${PUBLIC_IP}|g" {} \;
find . -name "*.js" -type f -exec sed -i "s|http://localhost:8000|http://${PUBLIC_IP}/voice|g" {} \;
echo "✓ Frontend configured"

# Start services
echo "Starting services..."
sudo systemctl daemon-reload
sudo systemctl restart bolkhata-banking
sudo systemctl restart bolkhata-voice
sudo systemctl restart nginx
sudo systemctl enable bolkhata-banking
sudo systemctl enable bolkhata-voice
sudo systemctl enable nginx

sleep 5

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Service Status:"
sudo systemctl is-active bolkhata-banking && echo "✓ Banking Service: Running" || echo "✗ Banking Service: Failed"
sudo systemctl is-active bolkhata-voice && echo "✓ Voice Service: Running" || echo "✗ Voice Service: Failed"
sudo systemctl is-active nginx && echo "✓ Nginx: Running" || echo "✗ Nginx: Failed"
echo ""
'@

# Execute deployment script on EC2
ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$EC2_IP $deployScript

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deployment Successful!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Application URLs:" -ForegroundColor Yellow
Write-Host "  Frontend: http://${EC2_IP}" -ForegroundColor Cyan
Write-Host "  Banking API: http://${EC2_IP}/api" -ForegroundColor Cyan
Write-Host "  Voice API: http://${EC2_IP}/voice" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test the application:" -ForegroundColor Yellow
Write-Host "  curl http://${EC2_IP}/api/health"
Write-Host "  curl http://${EC2_IP}/voice/health"
Write-Host ""
Write-Host "View logs:" -ForegroundColor Yellow
Write-Host "  ssh -i $KEY_FILE ec2-user@$EC2_IP"
Write-Host "  sudo journalctl -u bolkhata-banking -f"
Write-Host "  sudo journalctl -u bolkhata-voice -f"
Write-Host ""

# Clean up
Write-Host "Cleaning up deployment package..." -ForegroundColor Yellow
Remove-Item -Recurse -Force deploy-package
Remove-Item -Force bolkhata-app.tar.gz
Write-Host "✓ Cleanup complete" -ForegroundColor Green
Write-Host ""
