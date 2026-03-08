#!/bin/bash

# Route 53 Domain Setup for Bol-Khata
# This script sets up a custom domain with Route 53

set -e

# Configuration
DOMAIN_NAME="${1:-bolkhata.click}"  # Default to .click domain
EC2_IP="54.225.178.7"
REGION="us-east-1"

echo "=========================================="
echo "Route 53 Domain Setup"
echo "=========================================="
echo "Domain: $DOMAIN_NAME"
echo "EC2 IP: $EC2_IP"
echo ""

# Step 1: Create Hosted Zone
echo "Step 1: Creating Route 53 Hosted Zone..."
ZONE_OUTPUT=$(aws route53 create-hosted-zone \
  --name "$DOMAIN_NAME" \
  --caller-reference "bolkhata-$(date +%s)" \
  --hosted-zone-config Comment="Bol Khata Banking App" \
  --region $REGION \
  --output json)

ZONE_ID=$(echo $ZONE_OUTPUT | jq -r '.HostedZone.Id' | cut -d'/' -f3)
echo "✅ Hosted Zone Created: $ZONE_ID"

# Get nameservers
NAMESERVERS=$(echo $ZONE_OUTPUT | jq -r '.DelegationSet.NameServers[]')
echo ""
echo "📋 Nameservers (update these at your domain registrar):"
echo "$NAMESERVERS"
echo ""

# Step 2: Create A Record for root domain
echo "Step 2: Creating A record for $DOMAIN_NAME..."
cat > /tmp/change-batch-root.json << EOF
{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "$DOMAIN_NAME",
      "Type": "A",
      "TTL": 300,
      "ResourceRecords": [{"Value": "$EC2_IP"}]
    }
  }]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file:///tmp/change-batch-root.json \
  --region $REGION

echo "✅ A record created for $DOMAIN_NAME -> $EC2_IP"

# Step 3: Create A Record for www subdomain
echo "Step 3: Creating A record for www.$DOMAIN_NAME..."
cat > /tmp/change-batch-www.json << EOF
{
  "Changes": [{
    "Action": "CREATE",
    "ResourceRecordSet": {
      "Name": "www.$DOMAIN_NAME",
      "Type": "A",
      "TTL": 300,
      "ResourceRecords": [{"Value": "$EC2_IP"}]
    }
  }]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch file:///tmp/change-batch-www.json \
  --region $REGION

echo "✅ A record created for www.$DOMAIN_NAME -> $EC2_IP"

# Step 4: Save configuration
cat > route53-config.txt << EOF
Domain: $DOMAIN_NAME
Hosted Zone ID: $ZONE_ID
EC2 IP: $EC2_IP
Created: $(date)

Nameservers:
$NAMESERVERS

DNS Records:
- $DOMAIN_NAME -> $EC2_IP
- www.$DOMAIN_NAME -> $EC2_IP
EOF

echo ""
echo "=========================================="
echo "✅ Route 53 Setup Complete!"
echo "=========================================="
echo ""
echo "📋 Configuration saved to: route53-config.txt"
echo ""
echo "🔧 Next Steps:"
echo "1. If you registered domain elsewhere, update nameservers to:"
echo "$NAMESERVERS"
echo ""
echo "2. Wait 5-10 minutes for DNS propagation"
echo ""
echo "3. Update Nginx configuration on EC2:"
echo "   ssh -i bolkhata-key.pem ec2-user@$EC2_IP"
echo "   sudo nano /etc/nginx/conf.d/bolkhata.conf"
echo "   Add: server_name $DOMAIN_NAME www.$DOMAIN_NAME;"
echo "   sudo systemctl restart nginx"
echo ""
echo "4. Test your domain:"
echo "   http://$DOMAIN_NAME"
echo "   http://www.$DOMAIN_NAME"
echo ""
echo "5. Optional - Add HTTPS with Let's Encrypt:"
echo "   sudo certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME"
echo ""
