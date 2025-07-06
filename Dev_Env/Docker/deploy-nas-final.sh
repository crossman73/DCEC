#!/bin/bash
# NAS Direct Deployment Script
# 실제 NAS에 SSH로 접속하여 Docker 환경을 배포합니다.

set -euo pipefail

# Configuration
NAS_IP="192.168.0.5"
NAS_PORT="22022"
NAS_USER="crossman"
LOCAL_DIR="d:/Dev/DCEC/Dev_Env/Docker"
REMOTE_DIR="/volume1/docker/dev"

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

# Check SSH connection
check_ssh_connection() {
    log_info "Checking SSH connection to NAS..."
    if ssh -p "${NAS_PORT}" -o ConnectTimeout=10 "${NAS_USER}@${NAS_IP}" "echo 'SSH connection successful'"; then
        log_success "SSH connection to NAS established"
        return 0
    else
        log_error "Cannot connect to NAS via SSH"
        log_info "Please ensure:"
        log_info "1. NAS is accessible at ${NAS_IP}"
        log_info "2. SSH is enabled on the NAS (port ${NAS_PORT})"
        log_info "3. Your SSH key is properly configured"
        exit 1
    fi
}

# Transfer files to NAS
transfer_files() {
    log_info "Transferring files to NAS..."
    
    # Create remote directory if it doesn't exist
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "sudo mkdir -p ${REMOTE_DIR}"
    
    # Transfer main configuration files
    log_info "Transferring main configuration files..."
    scp -P "${NAS_PORT}" "${LOCAL_DIR}/.env" "${NAS_USER}@${NAS_IP}:${REMOTE_DIR}/"
    scp -P "${NAS_PORT}" "${LOCAL_DIR}/docker-compose.yml" "${NAS_USER}@${NAS_IP}:${REMOTE_DIR}/"
    scp -P "${NAS_PORT}" "${LOCAL_DIR}/nas-setup-complete.sh" "${NAS_USER}@${NAS_IP}:${REMOTE_DIR}/"
    
    # Transfer n8n API key
    log_info "Transferring n8n API key..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "sudo mkdir -p ${REMOTE_DIR}/config/n8n"
    scp -P "${NAS_PORT}" "${LOCAL_DIR}/n8n/20250626_n8n_API_KEY.txt" "${NAS_USER}@${NAS_IP}:${REMOTE_DIR}/config/n8n/api-keys.txt"
    
    # Set execute permissions
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "chmod +x ${REMOTE_DIR}/nas-setup-complete.sh"
    
    log_success "Files transferred successfully"
}

# Run setup script on NAS
run_setup_script() {
    log_info "Running setup script on NAS..."
    
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && ./nas-setup-complete.sh"
    
    log_success "Setup script execution completed"
}

# Deploy Docker services
deploy_services() {
    log_info "Deploying Docker services on NAS..."
    
    # Update .env with proper values
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && sed -i 's|DATA_ROOT=.*|DATA_ROOT=${REMOTE_DIR}/data|g' .env"
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && sed -i 's|DB_PASSWORD=.*|DB_PASSWORD=changeme123|g' .env"
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && sed -i 's|N8N_PORT=.*|N8N_PORT=31001|g' .env"
    
    # Start services
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose down --remove-orphans"
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose up -d"
    
    log_success "Docker services deployed"
}

# Health check
health_check() {
    log_info "Performing health check..."
    
    sleep 30  # Wait for services to start
    
    # Check service status
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose ps"
    
    log_info "Health check completed"
}

# Display service information
display_service_info() {
    log_info "Service Information:"
    echo ""
    echo "=== Service URLs ==="
    echo "n8n:              http://192.168.0.5:31001"
    echo "Gitea:            http://192.168.0.5:8484"
    echo "Code Server:      http://192.168.0.5:3000"
    echo "Uptime Kuma:      http://192.168.0.5:31003"
    echo "Portainer:        http://192.168.0.5:9000"
    echo ""
    echo "=== Sub-domain URLs (if configured) ==="
    echo "n8n:              https://n8n.crossman.synology.me"
    echo "Gitea:            https://git.crossman.synology.me"
    echo "Code Server:      https://code.crossman.synology.me"
    echo "Uptime Kuma:      https://uptime.crossman.synology.me"
    echo ""
    echo "=== Default Credentials ==="
    echo "n8n:              admin / changeme123"
    echo "Code Server:      changeme123"
    echo "Database:         nasuser / changeme123"
    echo ""
}

# Debug function for troubleshooting
debug_deployment() {
    log_info "=== Debug Information ==="
    
    # Check NAS connectivity
    log_info "Testing NAS connectivity..."
    ping -c 4 "${NAS_IP}" || log_warning "Ping failed"
    
    # Check SSH port
    log_info "Testing SSH port ${NAS_PORT}..."
    nc -zv "${NAS_IP}" "${NAS_PORT}" || log_warning "SSH port ${NAS_PORT} not accessible"
    
    # Check Docker status on NAS
    log_info "Checking Docker status on NAS..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "docker --version" || log_warning "Docker not available"
    
    # Check remote directory
    log_info "Checking remote directory..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "ls -la ${REMOTE_DIR}" || log_warning "Remote directory not accessible"
    
    # Check docker-compose status
    log_info "Checking docker-compose status..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose ps" || log_warning "Docker-compose not running"
    
    log_info "Debug information collection completed"
}

# Service management functions
start_services() {
    log_info "Starting all services..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose up -d"
    log_success "Services started"
}

stop_services() {
    log_info "Stopping all services..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose down"
    log_success "Services stopped"
}

restart_services() {
    log_info "Restarting all services..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose restart"
    log_success "Services restarted"
}

# Service logs
view_service_logs() {
    local service_name="${1:-}"
    if [[ -z "${service_name}" ]]; then
        log_info "Viewing all service logs..."
        ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose logs --tail=100 -f"
    else
        log_info "Viewing logs for service: ${service_name}"
        ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose logs --tail=100 -f ${service_name}"
    fi
}

# Service status check
check_service_status() {
    log_info "Checking service status..."
    
    # Docker container status
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker-compose ps"
    
    # Port checks
    log_info "Checking port accessibility..."
    for port in 31001 8484 3000 31003 9000; do
        if nc -zv "${NAS_IP}" "${port}" 2>/dev/null; then
            log_success "Port ${port} is accessible"
        else
            log_warning "Port ${port} is not accessible"
        fi
    done
    
    # Quick health check
    log_info "Quick health check..."
    curl -s --connect-timeout 5 "http://${NAS_IP}:31001" > /dev/null && log_success "n8n is responding" || log_warning "n8n not responding"
    curl -s --connect-timeout 5 "http://${NAS_IP}:8484" > /dev/null && log_success "Gitea is responding" || log_warning "Gitea not responding"
    curl -s --connect-timeout 5 "http://${NAS_IP}:3000" > /dev/null && log_success "Code Server is responding" || log_warning "Code Server not responding"
    curl -s --connect-timeout 5 "http://${NAS_IP}:31003" > /dev/null && log_success "Uptime Kuma is responding" || log_warning "Uptime Kuma not responding"
    curl -s --connect-timeout 5 "http://${NAS_IP}:9000" > /dev/null && log_success "Portainer is responding" || log_warning "Portainer not responding"
}

# Usage information
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  deploy      - Full deployment (default)"
    echo "  start       - Start services"
    echo "  stop        - Stop services"
    echo "  restart     - Restart services"
    echo "  status      - Check service status"
    echo "  logs [service] - View service logs"
    echo "  debug       - Debug deployment"
    echo "  info        - Display service information"
    echo ""
    echo "Examples:"
    echo "  $0 deploy         # Full deployment"
    echo "  $0 status         # Check status"
    echo "  $0 logs n8n       # View n8n logs"
    echo "  $0 debug          # Debug information"
    echo ""
}

# Main function
main() {
    local command="${1:-deploy}"
    
    case "${command}" in
        deploy)
            log_info "=========================================="
            log_info "NAS Docker Environment Deployment"
            log_info "=========================================="
            
            check_ssh_connection
            transfer_files
            run_setup_script
            deploy_services
            health_check
            display_service_info
            
            log_success "Deployment completed successfully!"
            log_info "Check the service URLs above to verify everything is working."
            ;;
        start)
            start_services
            ;;
        stop)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        status)
            check_service_status
            ;;
        logs)
            view_service_logs "${2:-}"
            ;;
        debug)
            debug_deployment
            ;;
        info)
            display_service_info
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: ${command}"
            usage
            exit 1
            ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi