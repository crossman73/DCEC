#!/bin/bash
# NAS Docker Development Environment Setup Script
# Description: Setup complete directory structure and deploy services to NAS
# Usage: Run this script on NAS via SSH

set -euo pipefail

# ===========================================
# Configuration
# ===========================================
BASE_DIR="/volume1/docker/dev"
DATA_DIR="$BASE_DIR/data"
CONFIG_DIR="$BASE_DIR/config"
LOGS_DIR="$BASE_DIR/logs"
SCRIPTS_DIR="$BASE_DIR/scripts"
BACKUP_DIR="/volume1/docker/backup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ===========================================
# Logging Functions
# ===========================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ===========================================
# Directory Structure Setup
# ===========================================
setup_directories() {
    log_info "Creating directory structure..."
    
    # Main directories
    sudo mkdir -p "$BASE_DIR" "$DATA_DIR" "$CONFIG_DIR" "$LOGS_DIR" "$SCRIPTS_DIR" "$BACKUP_DIR"
    
    # Data directories
    sudo mkdir -p \
        "$DATA_DIR/postgres" \
        "$DATA_DIR/n8n" \
        "$DATA_DIR/gitea" \
        "$DATA_DIR/uptime" \
        "$DATA_DIR/portainer"
    
    # Config directories
    sudo mkdir -p \
        "$CONFIG_DIR/n8n" \
        "$CONFIG_DIR/gitea" \
        "$CONFIG_DIR/vscode" \
        "$CONFIG_DIR/nginx/conf.d" \
        "$CONFIG_DIR/ssl"
    
    # Log directories
    sudo mkdir -p \
        "$LOGS_DIR/postgres" \
        "$LOGS_DIR/n8n" \
        "$LOGS_DIR/gitea" \
        "$LOGS_DIR/mcp" \
        "$LOGS_DIR/vscode" \
        "$LOGS_DIR/uptime" \
        "$LOGS_DIR/portainer" \
        "$LOGS_DIR/nginx" \
        "$LOGS_DIR/watchtower"
    
    # Set ownership
    sudo chown -R $(whoami):users /volume1/docker
    sudo chmod -R 755 /volume1/docker
    
    # Set specific permissions for data directories
    sudo chmod -R 750 "$DATA_DIR"
    sudo chmod -R 755 "$CONFIG_DIR"
    sudo chmod -R 755 "$LOGS_DIR"
    
    log_success "Directory structure created successfully"
}

# ===========================================
# Docker Compose Installation Check
# ===========================================
check_docker_compose() {
    log_info "Checking Docker Compose installation..."
    
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose found: $(docker-compose --version)"
        return 0
    fi
    
    log_warning "Docker Compose not found. Installing..."
    
    # Install Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Create symlink if needed
    if [ ! -f /usr/bin/docker-compose ]; then
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
    fi
    
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose installed: $(docker-compose --version)"
    else
        log_error "Docker Compose installation failed"
        exit 1
    fi
}

# ===========================================
# Configuration Files Setup
# ===========================================
setup_config_files() {
    log_info "Setting up configuration files..."
    
    # Create nginx default config
    cat > "$CONFIG_DIR/nginx/nginx.conf" << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private must-revalidate max-age=0;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/json;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF

    # Create nginx service configs
    cat > "$CONFIG_DIR/nginx/conf.d/default.conf" << 'EOF'
# Default server block
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        return 444;
    }
}

# n8n service
upstream n8n {
    server n8n:5678;
}

server {
    listen 80;
    server_name n8n.dev.local;
    
    location / {
        proxy_pass http://n8n;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# VS Code service
upstream vscode {
    server code-server:8080;
}

server {
    listen 80;
    server_name code.dev.local;
    
    location / {
        proxy_pass http://vscode;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
    }
}

# Gitea service
upstream gitea {
    server gitea:3000;
}

server {
    listen 80;
    server_name git.dev.local;
    
    location / {
        proxy_pass http://gitea;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

    log_success "Configuration files created"
}

# ===========================================
# Management Scripts Setup
# ===========================================
setup_scripts() {
    log_info "Creating management scripts..."
    
    # Start script
    cat > "$SCRIPTS_DIR/start.sh" << 'EOF'
#!/bin/bash
cd /volume1/docker/dev
echo "Starting NAS Docker Development Environment..."
docker-compose up -d
docker-compose ps
EOF

    # Stop script
    cat > "$SCRIPTS_DIR/stop.sh" << 'EOF'
#!/bin/bash
cd /volume1/docker/dev
echo "Stopping NAS Docker Development Environment..."
docker-compose down
EOF

    # Restart script
    cat > "$SCRIPTS_DIR/restart.sh" << 'EOF'
#!/bin/bash
cd /volume1/docker/dev
echo "Restarting NAS Docker Development Environment..."
docker-compose down
docker-compose up -d
docker-compose ps
EOF

    # Status script
    cat > "$SCRIPTS_DIR/status.sh" << 'EOF'
#!/bin/bash
cd /volume1/docker/dev
echo "=== Docker Compose Services ==="
docker-compose ps
echo ""
echo "=== Docker Containers ==="
docker ps --filter "name=nas-dev-"
echo ""
echo "=== Docker Networks ==="
docker network ls | grep nas-dev
echo ""
echo "=== Docker Volumes ==="
docker volume ls | grep nas-dev
EOF

    # Logs script
    cat > "$SCRIPTS_DIR/logs.sh" << 'EOF'
#!/bin/bash
cd /volume1/docker/dev
if [ -z "$1" ]; then
    echo "Usage: $0 <service_name>"
    echo "Available services: postgres, n8n, mcp-server, code-server, gitea, uptime-kuma, portainer, nginx"
    exit 1
fi
docker-compose logs -f "$1"
EOF

    # Backup script
    cat > "$SCRIPTS_DIR/backup.sh" << 'EOF'
#!/bin/bash
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="/volume1/docker/backup/$BACKUP_DATE"

echo "Creating backup: $BACKUP_PATH"
mkdir -p "$BACKUP_PATH"

# Backup configurations
cp -r /volume1/docker/dev/config "$BACKUP_PATH/"
cp /volume1/docker/dev/docker-compose.yml "$BACKUP_PATH/"
cp /volume1/docker/dev/.env "$BACKUP_PATH/"

# Backup data (excluding large files)
rsync -av --exclude='*.log' /volume1/docker/dev/data "$BACKUP_PATH/"

# Create archive
cd /volume1/docker/backup
tar -czf "nas-dev-backup-$BACKUP_DATE.tar.gz" "$BACKUP_DATE"
rm -rf "$BACKUP_DATE"

echo "Backup completed: nas-dev-backup-$BACKUP_DATE.tar.gz"

# Cleanup old backups (keep last 30 days)
find /volume1/docker/backup -name "nas-dev-backup-*.tar.gz" -mtime +30 -delete
EOF

    # Make scripts executable
    chmod +x "$SCRIPTS_DIR"/*.sh
    
    log_success "Management scripts created"
}

# ===========================================
# Service Health Check
# ===========================================
health_check() {
    log_info "Performing health check..."
    
    cd "$BASE_DIR"
    
    # Wait for services to start
    log_info "Waiting for services to initialize (60 seconds)..."
    sleep 60
    
    # Check services
    declare -A services=(
        ["postgres"]="5432"
        ["n8n"]="31001"
        ["mcp-server"]="31002"
        ["code-server"]="8484"
        ["gitea"]="3000"
        ["uptime-kuma"]="31003"
        ["portainer"]="9000"
    )
    
    log_info "Checking service health..."
    for service in "${!services[@]}"; do
        port="${services[$service]}"
        if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:$port" | grep -q "200\|302\|401"; then
            log_success "$service (port $port): Healthy"
        else
            log_warning "$service (port $port): Not responding or starting"
        fi
    done
    
    # Show running containers
    log_info "Running containers:"
    docker-compose ps
}

# ===========================================
# Display Information
# ===========================================
display_info() {
    log_success "=========================================="
    log_success "NAS Docker Development Environment Ready!"
    log_success "=========================================="
    
    echo ""
    log_info "Access URLs (Internal Network):"
    echo "  - n8n:         http://192.168.0.5:31001"
    echo "  - MCP Server:  http://192.168.0.5:31002"
    echo "  - VS Code:     http://192.168.0.5:8484"
    echo "  - Gitea:       http://192.168.0.5:3000"
    echo "  - Uptime Kuma: http://192.168.0.5:31003"
    echo "  - Portainer:   http://192.168.0.5:9000"
    echo "  - Nginx:       http://192.168.0.5:8080"
    
    echo ""
    log_info "Management Commands:"
    echo "  - Start:   /volume1/docker/dev/scripts/start.sh"
    echo "  - Stop:    /volume1/docker/dev/scripts/stop.sh"
    echo "  - Restart: /volume1/docker/dev/scripts/restart.sh"
    echo "  - Status:  /volume1/docker/dev/scripts/status.sh"
    echo "  - Logs:    /volume1/docker/dev/scripts/logs.sh <service>"
    echo "  - Backup:  /volume1/docker/dev/scripts/backup.sh"
    
    echo ""
    log_info "Network Share Access:"
    echo "  - Windows: \\\\192.168.0.5\\docker\\dev"
    echo "  - Direct:  /volume1/docker/dev"
    
    echo ""
    log_info "Next Steps:"
    echo "  1. Configure DSM reverse proxy for external access"
    echo "  2. Set up SSL certificates"
    echo "  3. Configure service-specific settings"
    echo "  4. Set up automated backups"
}

# ===========================================
# Main Function
# ===========================================
main() {
    log_info "=========================================="
    log_info "NAS Docker Development Environment Setup"
    log_info "=========================================="
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_error "Please do not run this script as root"
        exit 1
    fi
    
    setup_directories
    check_docker_compose
    setup_config_files
    setup_scripts
    
    log_info "Directory structure and scripts ready!"
    log_info "Please copy docker-compose.yml and .env files to $BASE_DIR"
    log_info "Then run: cd $BASE_DIR && docker-compose up -d"
    
    echo ""
    read -p "Do you want to start services now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$BASE_DIR/docker-compose.yml" ]; then
            cd "$BASE_DIR"
            docker-compose up -d
            health_check
            display_info
        else
            log_warning "docker-compose.yml not found. Please copy the compose file first."
        fi
    else
        log_info "Setup completed. You can start services manually later."
    fi
}

# ===========================================
# Script Execution
# ===========================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi