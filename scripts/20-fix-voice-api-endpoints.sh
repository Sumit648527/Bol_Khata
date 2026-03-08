#!/bin/bash

# Fix Voice API Endpoints for Production
# This script updates the frontend to use relative URLs instead of localhost

echo "=========================================="
echo "Fixing Voice API Endpoints"
echo "=========================================="

# Check voice service status
echo ""
echo "1. Checking voice service status..."
sudo systemctl status bolkhata-voice --no-pager | head -20

echo ""
echo "2. Checking voice service logs..."
sudo journalctl -u bolkhata-voice -n 50 --no-pager

echo ""
echo "3. Testing voice service health..."
curl -s http://localhost:8000/health || echo "Voice service not responding"

echo ""
echo "4. Updating frontend API endpoints..."

# Update app-final.js in source
cd /opt/bolkhata/banking-service/src/main/resources/static

# Backup original
cp app-final.js app-final.js.backup

# Replace localhost URLs with relative URLs
sed -i "s|const API_BASE = 'http://localhost:8081/api';|const API_BASE = '/api';|g" app-final.js
sed -i "s|const VOICE_API = 'http://localhost:8000';|const VOICE_API = '/voice';|g" app-final.js

echo "Updated source file"

# Rebuild and deploy
echo ""
echo "5. Rebuilding application..."
cd /opt/bolkhata/banking-service
mvn clean package -DskipTests

echo ""
echo "6. Restarting banking service..."
sudo systemctl restart bolkhata-banking

echo ""
echo "7. Waiting for service to start..."
sleep 10

echo ""
echo "8. Checking banking service status..."
sudo systemctl status bolkhata-banking --no-pager | head -20

echo ""
echo "9. Testing API endpoints..."
echo "Banking API:"
curl -s https://bolkhata.com/api/health || echo "Banking API not responding"

echo ""
echo "Voice API:"
curl -s https://bolkhata.com/voice/health || echo "Voice API not responding"

echo ""
echo "=========================================="
echo "✅ Fix complete!"
echo "=========================================="
echo ""
echo "Test your app at: https://bolkhata.com"
echo ""
