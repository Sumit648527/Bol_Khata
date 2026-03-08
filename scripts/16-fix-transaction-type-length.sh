#!/bin/bash

# Fix Transaction entity type column length from 10 to 20

echo "Fixing Transaction entity type column length..."

# Check current length
echo "Current type column definition:"
grep -A 1 'name = "type"' /opt/bolkhata/banking-service/src/main/java/com/bolkhata/entity/Transaction.java

# Fix the length
sudo sed -i 's/@Column(name = "type", nullable = false, length = 10)/@Column(name = "type", nullable = false, length = 20)/' /opt/bolkhata/banking-service/src/main/java/com/bolkhata/entity/Transaction.java

# Verify the fix
echo ""
echo "Updated type column definition:"
grep -A 1 'name = "type"' /opt/bolkhata/banking-service/src/main/java/com/bolkhata/entity/Transaction.java

# Rebuild
echo ""
echo "Rebuilding application..."
cd /opt/bolkhata/banking-service
mvn clean package -DskipTests

# Restart
echo ""
echo "Restarting service..."
sudo systemctl restart bolkhata-banking

# Wait and check status
echo ""
echo "Waiting for service to start..."
sleep 10

echo ""
echo "Service status:"
sudo systemctl status bolkhata-banking --no-pager | head -20

echo ""
echo "✅ Fix complete! Transaction type column now supports up to 20 characters."
echo "Test all three transaction types:"
echo "  - SALE_PAID (9 chars)"
echo "  - SALE_CREDIT (11 chars)"
echo "  - PAYMENT_RECEIVED (16 chars)"
