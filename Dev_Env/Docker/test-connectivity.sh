#!/bin/bash
# Quick connectivity test script for NAS deployment

# Configuration
NAS_IP="192.168.0.5"
NAS_PORT="22022"
NAS_USER="crossman"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "NAS Connectivity Test"
echo "=========================================="

# Test 1: Ping
log_info "Testing ping to ${NAS_IP}..."
if ping -c 4 "${NAS_IP}" > /dev/null 2>&1; then
    log_success "Ping successful"
else
    log_error "Ping failed - NAS not reachable"
fi

# Test 2: SSH Port
log_info "Testing SSH port ${NAS_PORT}..."
if nc -zv "${NAS_IP}" "${NAS_PORT}" > /dev/null 2>&1; then
    log_success "SSH port ${NAS_PORT} is open"
else
    log_error "SSH port ${NAS_PORT} is not accessible"
fi

# Test 3: SSH Authentication
log_info "Testing SSH authentication..."
if ssh -p "${NAS_PORT}" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${NAS_USER}@${NAS_IP}" "echo 'SSH authentication successful'" > /dev/null 2>&1; then
    log_success "SSH authentication successful"
else
    log_error "SSH authentication failed"
    log_info "Please check:"
    log_info "1. SSH key is properly configured"
    log_info "2. User '${NAS_USER}' exists on NAS"
    log_info "3. SSH service is running"
fi

# Test 4: Docker availability
log_info "Testing Docker availability on NAS..."
if ssh -p "${NAS_PORT}" -o ConnectTimeout=10 "${NAS_USER}@${NAS_IP}" "docker --version" > /dev/null 2>&1; then
    log_success "Docker is available on NAS"
else
    log_warning "Docker not available or not accessible"
fi

# Test 5: Directory permissions
log_info "Testing directory permissions..."
if ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "test -w /volume1/docker || sudo mkdir -p /volume1/docker/dev" > /dev/null 2>&1; then
    log_success "Directory permissions OK"
else
    log_warning "Directory permission issues"
fi

# Test 6: Service ports
log_info "Testing service ports..."
service_ports=(31001 8484 3000 31003 9000)
for port in "${service_ports[@]}"; do
    if nc -zv "${NAS_IP}" "${port}" > /dev/null 2>&1; then
        log_success "Port ${port} is open"
    else
        log_info "Port ${port} is not open (normal if services not running)"
    fi
done

echo ""
echo "=========================================="
echo "Connectivity test completed"
echo "=========================================="
echo ""
echo "If all critical tests passed, you can proceed with:"
echo "./deploy-nas-final.sh deploy"
echo ""
