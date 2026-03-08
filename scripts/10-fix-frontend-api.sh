#!/bin/bash

# Fix Frontend API Configuration
# This script updates the frontend to use the correct EC2 public IP

set -e

EC2_IP="54.225.178.7"

echo "=========================================="
echo "Fixing Frontend API Configuration"
echo "=========================================="

# SSH into EC2 and update the frontend files
ssh -i bolkhata-key.pem ec2-user@$EC2_IP << 'ENDSSH'

echo "Updating frontend API endpoints..."

# Update app-final.js
sudo sed -i "s|const API_BASE = 'http://localhost:8081/api';|const API_BASE = '/api';|g" /opt/bolkhata/web-ui/app-final.js
sudo sed -i "s|const VOICE_API = 'http://localhost:8000';|const VOICE_API = '/voice';|g" /opt/bolkhata/web-ui/app-final.js

# Copy updated files to Nginx directory
sudo cp /opt/bolkhata/web-ui/* /usr/share/nginx/html/

echo "Frontend updated successfully!"

# Restart Nginx to ensure changes take effect
sudo systemctl restart nginx

echo ""
echo "=========================================="
echo "Frontend API Configuration Fixed!"
echo "=========================================="
echo ""
echo "API endpoints now use relative paths:"
echo "  API_BASE = '/api'"
echo "  VOICE_API = '/voice'"
echo ""
echo "Nginx will proxy these to:"
echo "  /api -> http://localhost:8080/api"
echo "  /voice -> http://localhost:8000"
echo ""
echo "Please refresh your browser: http://54.225.178.7"
echo ""

ENDSSH

echo "Done! Refresh your browser to see the changes."
