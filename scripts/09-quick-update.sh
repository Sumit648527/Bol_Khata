#!/bin/bash

# Quick update script for development
# Deploys only changed files without full rebuild

set -e

echo "=========================================="
echo "Quick Update - Bol Khata EC2"
echo "=========================================="

# Configuration
EC2_IP="${1:-}"
KEY_FILE="${2:-bolkhata-key.pem}"
COMPONENT="${3:-all}"  # all, banking, voice, frontend

if [ -z "$EC2_IP" ]; then
    echo "Error: EC2 IP address required"
    echo "Usage: ./09-quick-update.sh <EC2_IP> [KEY_FILE] [COMPONENT]"
    echo ""
    echo "Components:"
    echo "  all       - Update everything (default)"
    echo "  banking   - Update only Banking Service"
    echo "  voice     - Update only Voice Service"
    echo "  frontend  - Update only Frontend"
    echo ""
    echo "Example: ./09-quick-update.sh 54.123.45.67 bolkhata-key.pem banking"
    exit 1
fi

echo "EC2 IP: $EC2_IP"
echo "Component: $COMPONENT"
echo ""

# Function to update Banking Service
update_banking() {
    echo "📦 Updating Banking Service..."
    
    # Create temp package
    tar -czf /tmp/banking-update.tar.gz banking-service/
    
    # Upload
    scp -i $KEY_FILE -o StrictHostKeyChecking=no /tmp/banking-update.tar.gz ec2-user@$EC2_IP:/tmp/
    
    # Deploy
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$EC2_IP << 'EOF'
cd /opt/bolkhata
tar -xzf /tmp/banking-update.tar.gz
cd banking-service
mvn clean package -DskipTests
sudo systemctl restart bolkhata-banking
echo "✓ Banking Service updated and restarted"
sudo systemctl status bolkhata-banking --no-pager | head -n 5
EOF
    
    rm /tmp/banking-update.tar.gz
    echo "✅ Banking Service update complete"
}

# Function to update Voice Service
update_voice() {
    echo "📦 Updating Voice Service..."
    
    # Create temp package
    tar -czf /tmp/voice-update.tar.gz voice-service/
    
    # Upload
    scp -i $KEY_FILE -o StrictHostKeyChecking=no /tmp/voice-update.tar.gz ec2-user@$EC2_IP:/tmp/
    
    # Deploy
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$EC2_IP << 'EOF'
cd /opt/bolkhata
tar -xzf /tmp/voice-update.tar.gz
sudo systemctl restart bolkhata-voice
echo "✓ Voice Service updated and restarted"
sudo systemctl status bolkhata-voice --no-pager | head -n 5
EOF
    
    rm /tmp/voice-update.tar.gz
    echo "✅ Voice Service update complete"
}

# Function to update Frontend
update_frontend() {
    echo "📦 Updating Frontend..."
    
    # Create temp package
    tar -czf /tmp/frontend-update.tar.gz web-ui/
    
    # Upload
    scp -i $KEY_FILE -o StrictHostKeyChecking=no /tmp/frontend-update.tar.gz ec2-user@$EC2_IP:/tmp/
    
    # Deploy
    ssh -i $KEY_FILE -o StrictHostKeyChecking=no ec2-user@$EC2_IP << EOF
cd /opt/bolkhata
tar -xzf /tmp/frontend-update.tar.gz

# Update API endpoints
cd web-ui
sed -i "s|http://localhost:8080|http://$EC2_IP|g" *.js || true
sed -i "s|http://localhost:8000|http://$EC2_IP/voice|g" *.js || true

sudo systemctl reload nginx
echo "✓ Frontend updated"
EOF
    
    rm /tmp/frontend-update.tar.gz
    echo "✅ Frontend update complete"
}

# Execute based on component
case $COMPONENT in
    banking)
        update_banking
        ;;
    voice)
        update_voice
        ;;
    frontend)
        update_frontend
        ;;
    all)
        update_banking
        echo ""
        update_voice
        echo ""
        update_frontend
        ;;
    *)
        echo "Error: Unknown component '$COMPONENT'"
        echo "Valid components: all, banking, voice, frontend"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Update Complete!"
echo "=========================================="
echo ""
echo "Test your changes:"
echo "  Frontend: http://${EC2_IP}"
echo "  Banking API: http://${EC2_IP}/api/health"
echo "  Voice API: http://${EC2_IP}/voice/health"
echo ""
echo "View logs:"
echo "  ssh -i $KEY_FILE ec2-user@$EC2_IP"
echo "  sudo journalctl -u bolkhata-banking -f"
echo "  sudo journalctl -u bolkhata-voice -f"
echo ""
