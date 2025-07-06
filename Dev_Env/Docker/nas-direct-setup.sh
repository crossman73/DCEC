#!/bin/bash
# NAS Docker Services Direct Setup Script
# NAS에서 직접 실행하는 Docker 서비스 설정 스크립트

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 작업 디렉토리 설정
WORK_DIR="/volume1/dev/docker"

# Docker Compose 설치 확인
check_docker_compose() {
    log_info "Docker Compose 설치 확인 중..."
    
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose 이미 설치됨: $(docker-compose --version)"
        return 0
    fi
    
    log_warning "Docker Compose가 설치되지 않음. 설치 중..."
    
    # Docker Compose 설치
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose 설치 완료: $(docker-compose --version)"
    else
        log_error "Docker Compose 설치 실패"
        exit 1
    fi
}

# 작업 디렉토리 생성
setup_directories() {
    log_info "작업 디렉토리 설정 중..."
    
    sudo mkdir -p "$WORK_DIR"
    sudo chown -R $(whoami):users "$WORK_DIR"
    
    log_success "작업 디렉토리 생성 완료: $WORK_DIR"
}

# Docker Compose 파일 생성
create_docker_compose() {
    log_info "Docker Compose 파일 생성 중..."
    
    cd "$WORK_DIR"
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'

networks:
  nas-subdomain-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  postgres_data:
  gitea_data:
  uptime_data:
  portainer_data:
  n8n_data:
  vscode_config:

services:
  postgres:
    image: postgres:16
    container_name: nas-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: changeme123
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - nas-subdomain-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n -d n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: nas-n8n
    restart: unless-stopped
    ports:
      - "31001:5678"
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: n8n
      DB_POSTGRESDB_PASSWORD: changeme123
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_BASIC_AUTH_USER: admin
      N8N_BASIC_AUTH_PASSWORD: changeme123
      WEBHOOK_URL: https://n8n.crossman.synology.me
      N8N_BASE_URL: https://n8n.crossman.synology.me
      N8N_SECURE_COOKIE: "false"
      GENERIC_TIMEZONE: Asia/Seoul
      N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE: "true"
      N8N_METRICS: "true"
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - nas-subdomain-network

  mcp-server:
    image: leonardsellem/n8n-mcp-server:latest
    container_name: nas-mcp-server
    restart: unless-stopped
    ports:
      - "31002:31002"
    environment:
      N8N_API_URL: http://n8n:5678/api/v1
      N8N_API_KEY: "default-api-key"
      MCP_PORT: 31002
      MCP_HOST: "0.0.0.0"
      NODE_ENV: production
    depends_on:
      n8n:
        condition: service_healthy
    networks:
      - nas-subdomain-network

  code-server:
    image: codercom/code-server:latest
    container_name: nas-code-server
    restart: unless-stopped
    ports:
      - "8484:8080"
    environment:
      PASSWORD: changeme123
    volumes:
      - /volume1/dev:/home/coder/workspace
      - vscode_config:/home/coder/.config
    user: "1000:1000"
    networks:
      - nas-subdomain-network

  gitea:
    image: gitea/gitea:latest
    container_name: nas-gitea
    restart: unless-stopped
    ports:
      - "3000:3000"
      - "2222:22"
    environment:
      USER_UID: 1000
      USER_GID: 1000
      GITEA__server__DOMAIN: git.crossman.synology.me
      GITEA__server__ROOT_URL: https://git.crossman.synology.me
    volumes:
      - gitea_data:/data
    networks:
      - nas-subdomain-network

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: nas-uptime-kuma
    restart: unless-stopped
    ports:
      - "31003:3001"
    volumes:
      - uptime_data:/app/data
    networks:
      - nas-subdomain-network

  portainer:
    image: portainer/portainer-ce:latest
    container_name: nas-portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - nas-subdomain-network
EOF

    log_success "Docker Compose 파일 생성 완료"
}

# 환경 설정 파일 생성
create_env_file() {
    log_info "환경 설정 파일 생성 중..."
    
    cat > .env << 'EOF'
BASE_DOMAIN=crossman.synology.me
DOCKER_NETWORK_NAME=nas-subdomain-network
N8N_PASSWORD=changeme123
VSCODE_PASSWORD=changeme123
POSTGRES_PASSWORD=changeme123
EOF

    log_success "환경 설정 파일 생성 완료"
}

# Docker 서비스 시작
start_services() {
    log_info "Docker 서비스 시작 중..."
    
    cd "$WORK_DIR"
    
    # 기존 서비스 정리
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # 이미지 다운로드
    log_info "Docker 이미지 다운로드 중..."
    docker-compose pull
    
    # 서비스 시작
    log_info "서비스 시작 중..."
    docker-compose up -d
    
    log_success "Docker 서비스 시작 완료"
}

# 서비스 상태 확인
verify_services() {
    log_info "서비스 상태 확인 중..."
    
    cd "$WORK_DIR"
    
    # 서비스 시작 대기
    log_info "서비스 초기화 대기 중 (60초)..."
    sleep 60
    
    # 상태 확인
    docker-compose ps
    
    echo ""
    log_info "포트 상태 확인:"
    
    declare -A services=(
        ["n8n"]="31001"
        ["mcp-server"]="31002"
        ["code-server"]="8484"
        ["gitea"]="3000"
        ["uptime-kuma"]="31003"
        ["portainer"]="9000"
    )
    
    for service in "${!services[@]}"; do
        port="${services[$service]}"
        if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://localhost:$port" | grep -q "200\|302\|401"; then
            log_success "$service (포트 $port): 정상 동작"
        else
            log_warning "$service (포트 $port): 응답 없음 또는 시작 중"
        fi
    done
    
    echo ""
    log_info "외부 접속 URL:"
    echo "- n8n: http://192.168.0.5:31001"
    echo "- MCP Server: http://192.168.0.5:31002"
    echo "- VS Code: http://192.168.0.5:8484"
    echo "- Gitea: http://192.168.0.5:3000"
    echo "- Uptime Kuma: http://192.168.0.5:31003"
    echo "- Portainer: http://192.168.0.5:9000"
}

# 메인 함수
main() {
    log_info "=========================================="
    log_info "NAS Docker Services 직접 설치 시작"
    log_info "=========================================="
    
    check_docker_compose
    setup_directories
    create_docker_compose
    create_env_file
    start_services
    verify_services
    
    log_success "=========================================="
    log_success "NAS Docker Services 설치 완료!"
    log_success "=========================================="
    
    log_info "다음 단계:"
    log_info "1. 브라우저에서 각 서비스 접속 테스트"
    log_info "2. DSM 리버스 프록시에 서브도메인 규칙 추가"
    log_info "3. SSL 인증서 설정"
}

# 스크립트 실행
main "$@"
