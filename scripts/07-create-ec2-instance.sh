#!/bin/bash

# Script to create EC2 instance for Bol Khata application
# Run this in AWS CloudShell

set -e

echo "=========================================="
echo "Creating EC2 Instance for Bol Khata"
echo "=========================================="

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Configuration
INSTANCE_TYPE="t3.medium"  # 2 vCPU, 4 GB RAM - good for Java + Python
AMI_ID="ami-0c02fb55b34c3f4f0"  # Amazon Linux 2023 (latest)
KEY_NAME="bolkhata-key"
INSTANCE_NAME="bolkhata-app-server"

# Network configuration
VPC_ID="vpc-04889ded9339f23cf"
SUBNET_ID="subnet-027a2c548954841c7"  # Public subnet

echo "Configuration:"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  AMI: Amazon Linux 2023"
echo "  VPC: $VPC_ID"
echo "  Subnet: $SUBNET_ID (public)"
echo ""

# 1. Create key pair if it doesn't exist
echo "1. Creating SSH key pair..."
if aws ec2 describe-key-pairs --key-names $KEY_NAME --region $REGION 2>/dev/null; then
    echo "Key pair already exists"
else
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --query 'KeyMaterial' \
        --output text \
        --region $REGION > ${KEY_NAME}.pem
    
    chmod 400 ${KEY_NAME}.pem
    echo "✓ Key pair created and saved to ${KEY_NAME}.pem"
    echo "⚠️  IMPORTANT: Download this file from CloudShell!"
    echo "   Click Actions → Download file → ${KEY_NAME}.pem"
fi
echo ""

# 2. Create security group for EC2
echo "2. Creating security group..."
SG_ID=$(aws ec2 create-security-group \
    --group-name bolkhata-ec2-sg \
    --description "Security group for Bol Khata EC2 instance" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --query 'GroupId' \
    --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=bolkhata-ec2-sg" \
        --query 'SecurityGroups[0].GroupId' \
        --output text \
        --region $REGION)

echo "Security Group ID: $SG_ID"

# Add security group rules
echo "3. Configuring security group rules..."

# SSH access (port 22) - from anywhere (you can restrict this to your IP)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region $REGION \
    2>/dev/null || echo "SSH rule already exists"

# HTTP (port 80)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0 \
    --region $REGION \
    2>/dev/null || echo "HTTP rule already exists"

# HTTPS (port 443)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region $REGION \
    2>/dev/null || echo "HTTPS rule already exists"

# Banking Service (port 8080)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0 \
    --region $REGION \
    2>/dev/null || echo "Port 8080 rule already exists"

# Voice Service (port 8000)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 8000 \
    --cidr 0.0.0.0/0 \
    --region $REGION \
    2>/dev/null || echo "Port 8000 rule already exists"

# Allow EC2 to connect to RDS
aws ec2 authorize-security-group-ingress \
    --group-id sg-0a163d7742948c81e \
    --protocol tcp \
    --port 5432 \
    --source-group $SG_ID \
    --region $REGION \
    2>/dev/null || echo "RDS access rule already exists"

echo "✓ Security group configured"
echo ""

# 4. Create IAM role for EC2
echo "4. Creating IAM role for EC2..."

# Create trust policy
cat > /tmp/ec2-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create role
aws iam create-role \
    --role-name BolKhataEC2Role \
    --assume-role-policy-document file:///tmp/ec2-trust-policy.json \
    --description "IAM role for Bol Khata EC2 instance" \
    --region $REGION \
    2>/dev/null || echo "Role already exists"

# Attach policies
aws iam attach-role-policy \
    --role-name BolKhataEC2Role \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/BolKhataLambdaApplicationPolicy \
    2>/dev/null || echo "Policy already attached"

aws iam attach-role-policy \
    --role-name BolKhataEC2Role \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
    2>/dev/null || echo "CloudWatch policy already attached"

# Create instance profile
aws iam create-instance-profile \
    --instance-profile-name BolKhataEC2InstanceProfile \
    --region $REGION \
    2>/dev/null || echo "Instance profile already exists"

# Add role to instance profile
aws iam add-role-to-instance-profile \
    --instance-profile-name BolKhataEC2InstanceProfile \
    --role-name BolKhataEC2Role \
    2>/dev/null || echo "Role already in instance profile"

echo "✓ IAM role configured"
echo ""

# Wait for instance profile to be ready
echo "5. Waiting for IAM role to propagate..."
sleep 10

# 6. Create user data script for instance initialization
echo "6. Preparing instance initialization script..."
cat > /tmp/user-data.sh << 'USERDATA'
#!/bin/bash
set -e

# Log everything
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=========================================="
echo "Initializing Bol Khata Application Server"
echo "=========================================="

# Update system
echo "Updating system packages..."
dnf update -y

# Install Java 17
echo "Installing Java 17..."
dnf install -y java-17-amazon-corretto-devel

# Install Python 3.11
echo "Installing Python 3.11..."
dnf install -y python3.11 python3.11-pip python3.11-devel

# Install PostgreSQL client
echo "Installing PostgreSQL client..."
dnf install -y postgresql15

# Install Git
echo "Installing Git..."
dnf install -y git

# Install Maven
echo "Installing Maven..."
dnf install -y maven

# Install Nginx
echo "Installing Nginx..."
dnf install -y nginx

# Install AWS CLI (should be pre-installed, but ensure latest)
echo "Updating AWS CLI..."
dnf install -y aws-cli

# Create application directory
echo "Creating application directory..."
mkdir -p /opt/bolkhata
cd /opt/bolkhata

# Create systemd service files
echo "Creating systemd services..."

# Banking Service
cat > /etc/systemd/system/bolkhata-banking.service << 'EOF'
[Unit]
Description=Bol Khata Banking Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/bolkhata/banking-service
ExecStart=/usr/bin/java -jar /opt/bolkhata/banking-service/target/banking-service-0.0.1-SNAPSHOT.jar
Restart=always
RestartSec=10
Environment="SPRING_PROFILES_ACTIVE=aws"

[Install]
WantedBy=multi-user.target
EOF

# Voice Service
cat > /etc/systemd/system/bolkhata-voice.service << 'EOF'
[Unit]
Description=Bol Khata Voice Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/bolkhata/voice-service
ExecStart=/usr/bin/python3.11 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Configure Nginx
cat > /etc/nginx/conf.d/bolkhata.conf << 'EOF'
server {
    listen 80;
    server_name _;

    # Frontend
    location / {
        root /opt/bolkhata/web-ui;
        index app-final.html;
        try_files $uri $uri/ /app-final.html;
    }

    # Banking Service API
    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Voice Service API
    location /voice/ {
        proxy_pass http://localhost:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Set permissions
chown -R ec2-user:ec2-user /opt/bolkhata

# Enable services
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx

echo "=========================================="
echo "Server initialization complete!"
echo "=========================================="
echo "Ready for application deployment"
USERDATA

echo "✓ User data script prepared"
echo ""

# 7. Launch EC2 instance
echo "7. Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SG_ID \
    --subnet-id $SUBNET_ID \
    --iam-instance-profile Name=BolKhataEC2InstanceProfile \
    --user-data file:///tmp/user-data.sh \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Project,Value=BolKhata}]" \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":30,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
    --region $REGION \
    --query 'Instances[0].InstanceId' \
    --output text)

echo "Instance ID: $INSTANCE_ID"
echo ""

# Wait for instance to be running
echo "8. Waiting for instance to start (this may take 2-3 minutes)..."
aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $REGION

# Get public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

echo ""
echo "=========================================="
echo "EC2 Instance Created Successfully!"
echo "=========================================="
echo ""
echo "Instance Details:"
echo "  Instance ID: $INSTANCE_ID"
echo "  Instance Type: $INSTANCE_TYPE"
echo "  Public IP: $PUBLIC_IP"
echo "  Private IP: $PRIVATE_IP"
echo "  Security Group: $SG_ID"
echo ""
echo "SSH Access:"
echo "  ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
echo ""
echo "⚠️  IMPORTANT: Download the key file from CloudShell:"
echo "   Actions → Download file → ${KEY_NAME}.pem"
echo ""
echo "Application URLs (after deployment):"
echo "  Frontend: http://${PUBLIC_IP}"
echo "  Banking API: http://${PUBLIC_IP}/api"
echo "  Voice API: http://${PUBLIC_IP}/voice"
echo ""
echo "Next Steps:"
echo "  1. Download the SSH key (${KEY_NAME}.pem)"
echo "  2. Wait 2-3 minutes for instance initialization"
echo "  3. Run the deployment script (08-deploy-to-ec2.sh)"
echo ""
echo "Save these values:"
echo "EC2_INSTANCE_ID=$INSTANCE_ID"
echo "EC2_PUBLIC_IP=$PUBLIC_IP"
echo "EC2_PRIVATE_IP=$PRIVATE_IP"
echo "EC2_SECURITY_GROUP=$SG_ID"
echo ""
