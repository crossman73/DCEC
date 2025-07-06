#!/bin/bash
# Service Tests Script for NAS Docker Environment

set -euo pipefail

# Load environment variables
if [ -f "../.env" ]; then
    export $(grep -v '^#' ../.env | xargs)
fi

# Define services and their expected endpoints
declare -A services=(
    ["postgres"]="http://localhost:5432"
    ["n8n"]="http://localhost:31001"
    ["gitea"]="http://localhost:3000"
    ["code-server"]="http://localhost:8484"
)

# Function to test service availability
test_service() {
    local service_name=$1
    local service_url=$2

    echo "Testing $service_name at $service_url..."
    if curl -s --head "$service_url" | grep "200 OK" > /dev/null; then
        echo "$service_name is up and running."
    else
        echo "$service_name is not reachable!"
        exit 1
    fi
}

# Run tests on all services
for service in "${!services[@]}"; do
    test_service "$service" "${services[$service]}"
done

echo "All services are operational."