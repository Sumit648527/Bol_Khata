#!/bin/bash

# Register a new domain through Route 53
# This script helps you register a domain directly with AWS

set -e

DOMAIN_NAME="${1:-bolkhata.click}"
REGION="us-east-1"

echo "=========================================="
echo "Register Domain with Route 53"
echo "=========================================="
echo "Domain: $DOMAIN_NAME"
echo ""

# Check domain availability
echo "Checking domain availability..."
AVAILABILITY=$(aws route53domains check-domain-availability \
  --domain-name "$DOMAIN_NAME" \
  --region us-east-1 \
  --output json)

AVAILABLE=$(echo $AVAILABILITY | jq -r '.Availability')

if [ "$AVAILABLE" == "AVAILABLE" ]; then
    echo "✅ Domain $DOMAIN_NAME is available!"
    echo ""
    
    # Get pricing
    echo "Getting pricing information..."
    PRICE=$(aws route53domains get-domain-suggestions \
      --domain-name "${DOMAIN_NAME%.*}" \
      --suggestion-count 1 \
      --only-available \
      --region us-east-1 \
      --output json | jq -r '.SuggestionsList[0].Price')
    
    echo "💰 Estimated price: \$$PRICE USD/year"
    echo ""
    
    echo "To register this domain, run:"
    echo ""
    echo "aws route53domains register-domain \\"
    echo "  --domain-name $DOMAIN_NAME \\"
    echo "  --duration-in-years 1 \\"
    echo "  --auto-renew \\"
    echo "  --admin-contact FirstName=YourFirstName,LastName=YourLastName,ContactType=PERSON,OrganizationName=YourOrg,AddressLine1='123 Main St',City=YourCity,State=YourState,CountryCode=IN,ZipCode=123456,PhoneNumber=+91.1234567890,Email=your@email.com \\"
    echo "  --registrant-contact FirstName=YourFirstName,LastName=YourLastName,ContactType=PERSON,OrganizationName=YourOrg,AddressLine1='123 Main St',City=YourCity,State=YourState,CountryCode=IN,ZipCode=123456,PhoneNumber=+91.1234567890,Email=your@email.com \\"
    echo "  --tech-contact FirstName=YourFirstName,LastName=YourLastName,ContactType=PERSON,OrganizationName=YourOrg,AddressLine1='123 Main St',City=YourCity,State=YourState,CountryCode=IN,ZipCode=123456,PhoneNumber=+91.1234567890,Email=your@email.com \\"
    echo "  --region us-east-1"
    echo ""
    echo "⚠️  Note: Replace contact details with your actual information"
    echo "⚠️  Domain registration is not free - you will be charged"
    
elif [ "$AVAILABLE" == "UNAVAILABLE" ]; then
    echo "❌ Domain $DOMAIN_NAME is not available"
    echo ""
    echo "Try these alternatives:"
    echo "- ${DOMAIN_NAME%.*}.online"
    echo "- ${DOMAIN_NAME%.*}.tech"
    echo "- ${DOMAIN_NAME%.*}.site"
    echo "- ${DOMAIN_NAME%.*}.link"
    
else
    echo "⚠️  Domain availability: $AVAILABLE"
fi

echo ""
echo "=========================================="
echo "Cheap Domain Options:"
echo "=========================================="
echo ".click  - ~\$3/year"
echo ".link   - ~\$5/year"
echo ".online - ~\$3/year"
echo ".site   - ~\$3/year"
echo ".tech   - ~\$5/year"
echo ""
