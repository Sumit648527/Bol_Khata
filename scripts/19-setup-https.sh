#!/bin/bash

# Setup HTTPS with Let's Encrypt for bolkhata.com
# Run this AFTER your domain is working on HTTP

set -e

DOMAIN="${1:-bolkhata.com}"
EMAIL="${2:-your-email@example.com}"

echo "=========================================="
echo "Setting up HTTPS for $DOMAIN"
echo "=========================================="
echo ""

# Check if domain is provided
if [ "$EMAIL" == "your-email@example.com" ]; then
    echo "⚠️  Please provide your email address:"
    echo "Usage: $0 bolkhata.com your@email.com"
    exit 1
fi

# Step 1: Install Certbot
echo "Step 1: Installing Certbot..."
sudo yum install -y certbot python3-certbot-nginx

# Step 2: Test Nginx configuration
echo ""
echo "Step 2: Testing Nginx configuration..."
sudo nginx -t

if [ $? -ne 0 ]; then
    echo "❌ Nginx configuration has errors. Please fix them first."
    exit 1
fi

# Step 3: Get SSL certificate
echo ""
echo "Step 3: Getting SSL certificate from Let's Encrypt..."
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo ""

sudo certbot --nginx \
  -d $DOMAIN \
  -d www.$DOMAIN \
  --non-interactive \
  --agree-tos \
  --email $EMAIL \
  --redirect

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ HTTPS Setup Complete!"
    echo "=========================================="
    echo ""
    echo "Your site is now secure:"
    echo "  https://$DOMAIN"
    echo "  https://www.$DOMAIN"
    echo ""
    echo "Certificate details:"
    sudo certbot certificates
    echo ""
    echo "📋 Certificate auto-renewal:"
    echo "  - Certificates expire in 90 days"
    echo "  - Auto-renewal is configured via systemd timer"
    echo "  - Test renewal: sudo certbot renew --dry-run"
    echo ""
    echo "🔒 Security features enabled:"
    echo "  - TLS 1.2 and 1.3"
    echo "  - HTTP to HTTPS redirect"
    echo "  - Secure SSL configuration"
    echo ""
else
    echo ""
    echo "❌ Certificate installation failed!"
    echo ""
    echo "Common issues:"
    echo "1. Domain not resolving yet - wait 5-10 minutes"
    echo "2. Port 80 not accessible - check security group"
    echo "3. Nginx not configured correctly"
    echo ""
    echo "Check logs:"
    echo "  sudo tail -f /var/log/letsencrypt/letsencrypt.log"
    exit 1
fi

# Step 4: Verify HTTPS is working
echo "Step 4: Verifying HTTPS..."
sleep 2

if curl -s -o /dev/null -w "%{http_code}" https://$DOMAIN | grep -q "200\|301\|302"; then
    echo "✅ HTTPS is working!"
else
    echo "⚠️  HTTPS verification failed. Please check manually."
fi

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Test your site: https://$DOMAIN"
echo "2. Check SSL rating: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo "3. Update any hardcoded HTTP URLs in your app to HTTPS"
echo ""
