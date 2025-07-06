#!/bin/bash
# Maintenance script for NAS Docker Development Environment
# Description: This script performs maintenance tasks such as cleaning up unused Docker resources.

set -euo pipefail

# ===========================================
# Logging Functions
# ===========================================
log_info() { echo -e "[INFO] $1"; }
log_success() { echo -e "[SUCCESS] $1"; }
log_warning() { echo -e "[WARNING] $1"; }
log_error() { echo -e "[ERROR] $1"; }

# ===========================================
# Cleanup Unused Docker Resources
# ===========================================
cleanup_docker() {
    log_info "Cleaning up unused Docker resources..."
    
    # Remove unused containers, networks, images (both dangling and unused)
    docker system prune -af
    
    # Remove unused volumes
    docker volume prune -f
    
    log_success "Docker cleanup completed."
}

# ===========================================
# Main Function
# ===========================================
main() {
    log_info "=========================================="
    log_info "Starting NAS Docker Maintenance"
    log_info "=========================================="
    
    cleanup_docker
    
    log_info "Maintenance tasks completed."
}

# ===========================================
# Script Execution
# ===========================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi