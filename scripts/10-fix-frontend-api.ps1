# Fix Frontend API Configuration
# This script updates the frontend to use relative paths for API calls

$EC2_IP = "54.225.178.7"
$SSH_KEY = "bolkhata-key.pem"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Fixing Frontend API Configuration" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Create the SSH command
$sshCommand = @"
echo 'Updating frontend API endpoints...'

# Update app-final.js to use relative paths
sudo sed -i "s|const API_BASE = 'http://localhost:8081/api';|const API_BASE = '/api';|g" /opt/bolkhata/web-ui/app-final.js
sudo sed -i "s|const VOICE_API = 'http://localhost:8000';|const VOICE_API = '/voice';|g" /opt/bolkhata/web-ui/app-final.js

# Copy updated files to Nginx directory
sudo cp /opt/bolkhata/web-ui/* /usr/share/nginx/html/

echo 'Frontend updated successfully!'

# Restart Nginx
sudo systemctl restart nginx

echo ''
echo '=========================================='
echo 'Frontend API Configuration Fixed!'
echo '=========================================='
echo ''
echo 'API endpoints now use relative paths:'
echo '  API_BASE = /api'
echo '  VOICE_API = /voice'
echo ''
echo 'Nginx will proxy these to:'
echo '  /api -> http://localhost:8080/api'
echo '  /voice -> http://localhost:8000'
echo ''
"@

# Execute via SSH
ssh -i $SSH_KEY -o StrictHostKeyChecking=no ec2-user@$EC2_IP $sshCommand

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Done! Refresh your browser to see changes" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "URL: http://$EC2_IP" -ForegroundColor Yellow
Write-Host ""
