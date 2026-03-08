#!/bin/bash

echo "Starting Bol-Khata Banking Service..."

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "Maven is not installed. Please install Maven first."
    exit 1
fi

# Build the project
echo "Building project..."
mvn clean install -DskipTests

# Run the service
echo "Starting Banking Service on http://localhost:8080"
mvn spring-boot:run
