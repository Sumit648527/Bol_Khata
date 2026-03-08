#!/bin/bash
# Script to create VPC and network infrastructure for Bol Khata deployment
# Run this in AWS CloudShell

set -e  # Exit on error

echo "=========================================="
echo "Creating VPC and Network Infrastructure"
echo "=========================================="

# Variables
REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"
PUBLIC_SUBNET_CIDR="10.0.1.0/24"
PRIVATE_SUBNET_1_CIDR="10.0.2.0/24"
PRIVATE_SUBNET_2_CIDR="10.0.3.0/24"
PROJECT_NAME="bolkhata"

echo "Region: $REGION"
echo "VPC CIDR: $VPC_CIDR"

# Create VPC
echo -e "\n[1/10] Creating VPC..."
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block $VPC_CIDR \
    --region $REGION \
    --tag-specifications "ResourceType=vpc,Tags=[{Key=Name,Value=${PROJECT_NAME}-vpc},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'Vpc.VpcId' \
    --output text)

echo "VPC created: $VPC_ID"

# Enable DNS hostnames
echo -e "\n[2/10] Enabling DNS hostnames..."
aws ec2 modify-vpc-attribute \
    --vpc-id $VPC_ID \
    --enable-dns-hostnames \
    --region $REGION

# Create Internet Gateway
echo -e "\n[3/10] Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --region $REGION \
    --tag-specifications "ResourceType=internet-gateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-igw},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

echo "Internet Gateway created: $IGW_ID"

# Attach Internet Gateway to VPC
echo -e "\n[4/10] Attaching Internet Gateway to VPC..."
aws ec2 attach-internet-gateway \
    --vpc-id $VPC_ID \
    --internet-gateway-id $IGW_ID \
    --region $REGION

# Create Public Subnet (us-east-1a)
echo -e "\n[5/10] Creating Public Subnet..."
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PUBLIC_SUBNET_CIDR \
    --availability-zone ${REGION}a \
    --region $REGION \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-subnet},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Public Subnet created: $PUBLIC_SUBNET_ID"


# Create Private Subnet 1 (us-east-1a)
echo -e "\n[6/10] Creating Private Subnet 1..."
PRIVATE_SUBNET_1_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PRIVATE_SUBNET_1_CIDR \
    --availability-zone ${REGION}a \
    --region $REGION \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-subnet-1a},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Private Subnet 1 created: $PRIVATE_SUBNET_1_ID"

# Create Private Subnet 2 (us-east-1b) for Multi-AZ
echo -e "\n[7/10] Creating Private Subnet 2..."
PRIVATE_SUBNET_2_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --cidr-block $PRIVATE_SUBNET_2_CIDR \
    --availability-zone ${REGION}b \
    --region $REGION \
    --tag-specifications "ResourceType=subnet,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-subnet-1b},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'Subnet.SubnetId' \
    --output text)

echo "Private Subnet 2 created: $PRIVATE_SUBNET_2_ID"

# Allocate Elastic IP for NAT Gateway
echo -e "\n[8/10] Allocating Elastic IP for NAT Gateway..."
EIP_ALLOC_ID=$(aws ec2 allocate-address \
    --domain vpc \
    --region $REGION \
    --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=${PROJECT_NAME}-nat-eip},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'AllocationId' \
    --output text)

echo "Elastic IP allocated: $EIP_ALLOC_ID"

# Create NAT Gateway in Public Subnet
echo -e "\n[9/10] Creating NAT Gateway (this may take 2-3 minutes)..."
NAT_GW_ID=$(aws ec2 create-nat-gateway \
    --subnet-id $PUBLIC_SUBNET_ID \
    --allocation-id $EIP_ALLOC_ID \
    --region $REGION \
    --tag-specifications "ResourceType=natgateway,Tags=[{Key=Name,Value=${PROJECT_NAME}-nat-gw},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'NatGateway.NatGatewayId' \
    --output text)

echo "NAT Gateway created: $NAT_GW_ID"
echo "Waiting for NAT Gateway to become available..."

aws ec2 wait nat-gateway-available \
    --nat-gateway-ids $NAT_GW_ID \
    --region $REGION

echo "NAT Gateway is now available!"

# Create Route Table for Public Subnet
echo -e "\n[10/10] Creating Route Tables..."
PUBLIC_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --region $REGION \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-public-rt},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

echo "Public Route Table created: $PUBLIC_RT_ID"

# Add route to Internet Gateway
aws ec2 create-route \
    --route-table-id $PUBLIC_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id $IGW_ID \
    --region $REGION

# Associate Public Subnet with Public Route Table
aws ec2 associate-route-table \
    --subnet-id $PUBLIC_SUBNET_ID \
    --route-table-id $PUBLIC_RT_ID \
    --region $REGION

# Create Route Table for Private Subnets
PRIVATE_RT_ID=$(aws ec2 create-route-table \
    --vpc-id $VPC_ID \
    --region $REGION \
    --tag-specifications "ResourceType=route-table,Tags=[{Key=Name,Value=${PROJECT_NAME}-private-rt},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'RouteTable.RouteTableId' \
    --output text)

echo "Private Route Table created: $PRIVATE_RT_ID"

# Add route to NAT Gateway
aws ec2 create-route \
    --route-table-id $PRIVATE_RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_ID \
    --region $REGION

# Associate Private Subnets with Private Route Table
aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_1_ID \
    --route-table-id $PRIVATE_RT_ID \
    --region $REGION

aws ec2 associate-route-table \
    --subnet-id $PRIVATE_SUBNET_2_ID \
    --route-table-id $PRIVATE_RT_ID \
    --region $REGION

# Create Security Groups
echo -e "\nCreating Security Groups..."

# Security Group for Lambda to RDS
LAMBDA_TO_RDS_SG=$(aws ec2 create-security-group \
    --group-name ${PROJECT_NAME}-lambda-to-rds \
    --description "Allow Lambda functions to access RDS" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-lambda-to-rds},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'GroupId' \
    --output text)

echo "Lambda-to-RDS Security Group created: $LAMBDA_TO_RDS_SG"

# Security Group for RDS
RDS_SG=$(aws ec2 create-security-group \
    --group-name ${PROJECT_NAME}-rds \
    --description "Allow RDS access from Lambda" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-rds},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'GroupId' \
    --output text)

echo "RDS Security Group created: $RDS_SG"

# Allow Lambda to access RDS on port 5432
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG \
    --protocol tcp \
    --port 5432 \
    --source-group $LAMBDA_TO_RDS_SG \
    --region $REGION

# Security Group for Lambda to Internet
LAMBDA_TO_INTERNET_SG=$(aws ec2 create-security-group \
    --group-name ${PROJECT_NAME}-lambda-to-internet \
    --description "Allow Lambda to access internet" \
    --vpc-id $VPC_ID \
    --region $REGION \
    --tag-specifications "ResourceType=security-group,Tags=[{Key=Name,Value=${PROJECT_NAME}-lambda-to-internet},{Key=Project,Value=${PROJECT_NAME}}]" \
    --query 'GroupId' \
    --output text)

echo "Lambda-to-Internet Security Group created: $LAMBDA_TO_INTERNET_SG"

# Allow outbound HTTPS traffic
aws ec2 authorize-security-group-egress \
    --group-id $LAMBDA_TO_INTERNET_SG \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0 \
    --region $REGION

echo -e "\n=========================================="
echo "VPC Infrastructure Created Successfully!"
echo "=========================================="
echo ""
echo "Save these values for next steps:"
echo "VPC_ID=$VPC_ID"
echo "PUBLIC_SUBNET_ID=$PUBLIC_SUBNET_ID"
echo "PRIVATE_SUBNET_1_ID=$PRIVATE_SUBNET_1_ID"
echo "PRIVATE_SUBNET_2_ID=$PRIVATE_SUBNET_2_ID"
echo "LAMBDA_TO_RDS_SG=$LAMBDA_TO_RDS_SG"
echo "RDS_SG=$RDS_SG"
echo "LAMBDA_TO_INTERNET_SG=$LAMBDA_TO_INTERNET_SG"
echo ""
echo "Copy these values to a file for use in subsequent scripts!"
