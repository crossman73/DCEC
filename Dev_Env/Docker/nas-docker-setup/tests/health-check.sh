#!/bin/bash
# Health Check Script for NAS Docker Services

BASE_DIR="/volume1/docker/dev"

# Define services and their respective ports
declare -A services=(
    ["postgres"]="5432"
    ["n8n"]="31001"
    ["mcp-server"]="31002"
    ["code-server"]="8484"
    ["gitea"]="3000"
    ["uptime-kuma"]="31003"
    ["portainer"]="9000"
)

# Function to check service health
check_service_health() {
    local service=$1
    local port=$2
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:$port" | grep -q "200\|302\|401"; then
        echo "$service (port $port): Healthy"
    else
        echo "$service (port $port): Not responding or starting"
    fi
}

# Perform health checks
echo "Performing health checks on services..."
for service in "${!services[@]}"; do
    port="${services[$service]}"
    check_service_health "$service" "$port"
done

echo "Health check completed."