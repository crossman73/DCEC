#!/bin/bash
# NAS Docker Services Deployment Script
# Description: Deploy all subdomain services to Synology NAS Docker
# Version: 1.0.0

set -euo pipefail

# ===========================================
# Configuration
# ===========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/nas-docker-deploy.log"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
ENV_FILE="$SCRIPT_DIR/../Infra_Architecture/CPSE/.env"

# NAS 설정
NAS_HOST="192.168.0.5"
NAS_USER="crossman"
NAS_DOCKER_PATH="/volume1/dev/docker"
NAS_DATA_PATH="/volume1/dev/data"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===========================================
# Logging Functions
# ===========================================
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# ===========================================
# Network Detection
# ===========================================
detect_network() {
    log_info "네트워크 환경 감지 중..."
    
    # Ping test to NAS
    if ping -c 1 "$NAS_HOST" >/dev/null 2>&1; then
        log_success "NAS 접속 가능: $NAS_HOST"
        return 0
    else
        log_warning "NAS 직접 접속 불가, OpenVPN 연결 확인 중..."
        
        # Check VPN connection
        if ip route | grep -q "192.168.0.0/24"; then
            log_success "OpenVPN 연결됨"
            return 0
        else
            log_error "NAS 접속 및 OpenVPN 연결 실패"
            return 1
        fi
    fi
}

# ===========================================
# Prerequisites Check
# ===========================================
check_prerequisites() {
    log_info "사전 요구사항 확인 중..."
    
    # Check if Docker Compose file exists
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose 파일을 찾을 수 없습니다: $COMPOSE_FILE"
        exit 1
    fi
    
    # Check if .env file exists
    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "환경 설정 파일을 찾을 수 없습니다: $ENV_FILE"
        exit 1
    fi
    
    # Check SSH connectivity to NAS
    if ! ssh -o ConnectTimeout=5 "$NAS_USER@$NAS_HOST" "echo 'SSH 연결 테스트'" >/dev/null 2>&1; then
        log_error "NAS SSH 연결 실패. SSH 키 또는 연결 설정을 확인하세요."
        exit 1
    fi
    
    log_success "모든 사전 요구사항 확인 완료"
}

# ===========================================
# Copy Files to NAS
# ===========================================
copy_files_to_nas() {
    log_info "NAS로 파일 복사 중..."
    
    # Create directories on NAS
    ssh "$NAS_USER@$NAS_HOST" "
        sudo mkdir -p $NAS_DOCKER_PATH
        sudo mkdir -p $NAS_DATA_PATH
        sudo chown -R $NAS_USER:users $NAS_DOCKER_PATH
        sudo chown -R $NAS_USER:users $NAS_DATA_PATH
    "
    
    # Copy Docker Compose file
    scp "$COMPOSE_FILE" "$NAS_USER@$NAS_HOST:$NAS_DOCKER_PATH/"
    
    # Copy environment file
    scp "$ENV_FILE" "$NAS_USER@$NAS_HOST:$NAS_DOCKER_PATH/.env"
    
    log_success "파일 복사 완료"
}

# ===========================================
# Deploy Services
# ===========================================
deploy_services() {
    log_info "Docker 서비스 배포 중..."
    
    ssh "$NAS_USER@$NAS_HOST" "
        cd $NAS_DOCKER_PATH
        
        # Stop existing services
        docker-compose down --remove-orphans || true
        
        # Pull latest images
        docker-compose pull
        
        # Start services
        docker-compose up -d
        
        # Wait for services to start
        sleep 30
        
        # Show status
        docker-compose ps
    "
    
    log_success "Docker 서비스 배포 완료"
}

# ===========================================
# Verify Services
# ===========================================
verify_services() {
    log_info "서비스 상태 확인 중..."
    
    # Service endpoints to check
    declare -A services=(
        ["n8n"]="http://$NAS_HOST:31001"
        ["mcp-server"]="http://$NAS_HOST:31002/health"
        ["code-server"]="http://$NAS_HOST:8484"
        ["gitea"]="http://$NAS_HOST:3000"
        ["uptime-kuma"]="http://$NAS_HOST:31003"
        ["portainer"]="http://$NAS_HOST:9000"
    )
    
    for service in "${!services[@]}"; do
        url="${services[$service]}"
        log_info "확인 중: $service ($url)"
        
        if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 "$url" | grep -q "200\|302\|401"; then
            log_success "$service 서비스 정상 동작"
        else
            log_warning "$service 서비스 응답 없음 또는 시작 중"
        fi
    done
}

# ===========================================
# Generate Service URLs
# ===========================================
generate_service_urls() {
    log_info "서비스 접속 URL 생성 중..."
    
    cat << EOF > "$SCRIPT_DIR/service-urls.md"
# NAS Docker Services URLs

## 내부 네트워크 접속 (포트 직접 접속)
- **n8n**: http://$NAS_HOST:31001
- **MCP Server**: http://$NAS_HOST:31002
- **VS Code**: http://$NAS_HOST:8484
- **Gitea**: http://$NAS_HOST:3000
- **Uptime Kuma**: http://$NAS_HOST:31003
- **Portainer**: http://$NAS_HOST:9000

## 외부 서브도메인 접속 (DSM 리버스 프록시 설정 후)
- **n8n**: https://n8n.crossman.synology.me
- **MCP Server**: https://mcp.crossman.synology.me
- **VS Code**: https://code.crossman.synology.me
- **Gitea**: https://git.crossman.synology.me
- **Uptime Kuma**: https://uptime.crossman.synology.me
- **Portainer**: https://portainer.crossman.synology.me

## 관리자 정보
- **기본 사용자명**: admin
- **기본 비밀번호**: changeme123
- **Gitea SSH 포트**: 2222

## 다음 단계
1. DSM 리버스 프록시에서 각 서비스 규칙 추가
2. SSL 인증서 설정
3. 방화벽 및 포트포워딩 설정
4. 서비스별 초기 설정 완료

생성 시간: $(date)
EOF

    log_success "서비스 URL 파일 생성: $SCRIPT_DIR/service-urls.md"
}

# ===========================================
# Main Function
# ===========================================
main() {
    log_info "=========================================="
    log_info "NAS Docker Services Deployment 시작"
    log_info "=========================================="
    
    detect_network
    check_prerequisites
    copy_files_to_nas
    deploy_services
    
    log_info "서비스 시작 대기 중 (60초)..."
    sleep 60
    
    verify_services
    generate_service_urls
    
    log_success "=========================================="
    log_success "NAS Docker Services Deployment 완료!"
    log_success "=========================================="
    
    log_info "서비스 접속 정보는 다음 파일을 확인하세요:"
    log_info "- $SCRIPT_DIR/service-urls.md"
    log_info "- 로그 파일: $LOG_FILE"
}

# ===========================================
# Script Execution
# ===========================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
