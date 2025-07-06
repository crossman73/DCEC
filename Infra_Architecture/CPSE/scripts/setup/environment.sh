#!/bin/bash

# 환경 설정 스크립트
# NAS-SubDomain-Manager - 시놀로지 NAS 서브도메인 관리 시스템

set -euo pipefail

# 색상 정의
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

# 기본 설정
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 로그 함수들
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
}

# 환경 변수 검증
validate_environment() {
    log_step "환경 변수 검증 시작"
    
    # .env 파일 존재 확인
    if [[ ! -f "${PROJECT_ROOT}/.env" ]]; then
        log_warn ".env 파일이 없습니다. 기본 .env 파일을 생성합니다."
        create_default_env
    fi
    
    # .env 파일 로드
    source "${PROJECT_ROOT}/.env"
    
    # 필수 환경 변수 확인
    local required_vars=(
        "DOMAIN_NAME"
        "SERVICES"
        "TIMEZONE"
        "COMPOSE_PROJECT_NAME"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("${var}")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "필수 환경 변수가 설정되지 않았습니다:"
        for var in "${missing_vars[@]}"; do
            log_error "  - ${var}"
        done
        exit 1
    fi
    
    log_success "환경 변수 검증 완료"
}

# 기본 .env 파일 생성
create_default_env() {
    log_step "기본 .env 파일 생성"
    
    cat > "${PROJECT_ROOT}/.env" << 'EOF'
# NAS-SubDomain-Manager 환경 설정

# 도메인 설정
DOMAIN_NAME=crossman.synology.me
SUBDOMAIN_PREFIX=nas

# 관리할 서비스 목록 (n8n은 별도 프로젝트에서 관리하므로 제외)
SERVICES=mcp,uptime-kuma,code-server,gitea,dsm,portainer

# 네트워크 설정
EXTERNAL_NETWORK=nas-network
INTERNAL_NETWORK=nas-internal

# 보안 설정
SSL_EMAIL=admin@crossman.synology.me
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here

# 시스템 설정
TIMEZONE=Asia/Seoul
COMPOSE_PROJECT_NAME=nas-subdomain

# 백업 설정
BACKUP_RETENTION_DAYS=7
LOG_RETENTION_DAYS=30

# 포트 설정
NGINX_PROXY_PORT=80
NGINX_PROXY_SSL_PORT=443
PORTAINER_PORT=9000
UPTIME_KUMA_PORT=3001
CODE_SERVER_PORT=8080
GITEA_HTTP_PORT=3000
GITEA_SSH_PORT=2222

# 데이터 디렉토리
DATA_DIR=./data
BACKUP_DIR=./backup
LOGS_DIR=./logs

# MCP 설정
MCP_PORT=3000
MCP_HOST=localhost

# 모니터링 설정
WATCHTOWER_SCHEDULE=0 0 2 * * *
WATCHTOWER_CLEANUP=true

EOF

    log_success "기본 .env 파일이 생성되었습니다"
    log_info "필요에 따라 .env 파일의 설정을 수정해주세요"
}
    
    # 환경 변수 로드
    source "${PROJECT_ROOT}/.env"
    
    # 필수 환경 변수 확인
    local required_vars=(
        "BASE_DOMAIN"
        "DOCKER_NETWORK_NAME"
        "DOCKER_SUBNET"
        "N8N_BASIC_AUTH_PASSWORD"
        "N8N_ENCRYPTION_KEY"
        "MCP_API_KEY"
        "SSL_EMAIL"
    )
    
    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "다음 환경 변수가 설정되지 않았습니다:"
        printf '%s\n' "${missing_vars[@]}"
        exit 1
    fi
    
    log_success "환경 변수 검증 완료"
}

# 시스템 정보 수집
collect_system_info() {
    log_step "시스템 정보 수집"
    
    # 시스템 정보 파일 생성
    cat > "${PROJECT_ROOT}/config/system-info.json" << EOF
{
    "hostname": "$(hostname)",
    "os": "$(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '\"')",
    "kernel": "$(uname -r)",
    "architecture": "$(uname -m)",
    "docker_version": "$(docker --version | cut -d' ' -f3 | sed 's/,//')",
    "docker_compose_version": "$(docker-compose --version | cut -d' ' -f3 | sed 's/,//')",
    "network_interfaces": [
        $(ip addr show | grep 'inet ' | grep -v 127.0.0.1 | awk '{print "\"" $2 "\""}' | paste -sd,)
    ],
    "disk_usage": {
        "root": "$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')",
        "docker": "$(df -h /var/lib/docker 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}' || echo 'N/A')"
    },
    "memory": {
        "total": "$(free -h | awk 'NR==2{print $2}')",
        "used": "$(free -h | awk 'NR==2{print $3}')",
        "available": "$(free -h | awk 'NR==2{print $7}')"
    },
    "scan_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_success "시스템 정보 수집 완료"
}

# 네트워크 설정 검증
validate_network() {
    log_step "네트워크 설정 검증"
    
    # 포트 사용 확인
    local used_ports=()
    local services_from_env
    
    # 환경 변수에서 서비스 정보 읽기
    source "${PROJECT_ROOT}/.env"
    
    # 포트 배열 파싱 (SERVICES 배열에서)
    for service_info in "${SERVICES[@]}"; do
        local external_port=$(echo "$service_info" | cut -d':' -f3)
        if netstat -tuln | grep -q ":${external_port} "; then
            used_ports+=("$external_port")
        fi
    done
    
    if [[ ${#used_ports[@]} -gt 0 ]]; then
        log_warn "다음 포트가 이미 사용 중입니다:"
        printf '%s\n' "${used_ports[@]}"
        log_warn "계속 진행하시겠습니까? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_error "설치를 취소했습니다."
            exit 1
        fi
    fi
    
    # DNS 설정 확인
    if command -v nslookup &> /dev/null; then
        log_info "DNS 설정 확인 중: ${BASE_DOMAIN}"
        if nslookup "${BASE_DOMAIN}" &> /dev/null; then
            log_success "DNS 설정이 올바릅니다: ${BASE_DOMAIN}"
        else
            log_warn "DNS 설정을 확인할 수 없습니다: ${BASE_DOMAIN}"
        fi
    fi
    
    log_success "네트워크 설정 검증 완료"
}

# Docker 네트워크 생성
create_docker_network() {
    log_step "Docker 네트워크 생성"
    
    # 기존 네트워크 확인
    if docker network ls | grep -q "${DOCKER_NETWORK_NAME}"; then
        log_info "Docker 네트워크가 이미 존재합니다: ${DOCKER_NETWORK_NAME}"
    else
        # 네트워크 생성
        docker network create \
            --driver bridge \
            --subnet="${DOCKER_SUBNET}" \
            "${DOCKER_NETWORK_NAME}"
        
        log_success "Docker 네트워크 생성 완료: ${DOCKER_NETWORK_NAME}"
    fi
}

# 시간대 설정
configure_timezone() {
    log_step "시간대 설정"
    
    # 현재 시간대 확인
    local current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "Unknown")
    log_info "현재 시간대: ${current_tz}"
    
    # 시놀로지 NAS의 경우 Asia/Seoul로 설정
    if [[ "$current_tz" != "Asia/Seoul" ]]; then
        log_info "시간대를 Asia/Seoul로 설정합니다."
        # 시놀로지에서는 timedatectl이 제한적이므로 /etc/localtime 사용
        if [[ -f /usr/share/zoneinfo/Asia/Seoul ]]; then
            ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
            log_success "시간대 설정 완료: Asia/Seoul"
        else
            log_warn "시간대 파일을 찾을 수 없습니다. 수동으로 설정해주세요."
        fi
    else
        log_success "시간대 설정이 올바릅니다: ${current_tz}"
    fi
}

# 환경 설정 정보 저장
save_environment_info() {
    log_step "환경 설정 정보 저장"
    
    # 환경 설정 정보 파일 생성
    cat > "${PROJECT_ROOT}/config/environment-info.json" << EOF
{
    "base_domain": "${BASE_DOMAIN}",
    "docker_network": "${DOCKER_NETWORK_NAME}",
    "docker_subnet": "${DOCKER_SUBNET}",
    "services": [
        $(printf '%s\n' "${SERVICES[@]}" | while IFS=':' read -r name subdomain external_port internal_port; do
            echo "        {\"name\": \"$name\", \"subdomain\": \"$subdomain\", \"external_port\": \"$external_port\", \"internal_port\": \"$internal_port\"}"
        done | paste -sd,)
    ],
    "ssl_email": "${SSL_EMAIL}",
    "backup_path": "${BACKUP_PATH}",
    "health_check_interval": ${HEALTH_CHECK_INTERVAL},
    "log_level": "${LOG_LEVEL}",
    "configured_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log_success "환경 설정 정보 저장 완료"
}

# 권한 설정
set_permissions() {
    log_step "권한 설정"
    
    # 스크립트 파일들 실행 권한 부여
    find "${PROJECT_ROOT}/scripts" -name "*.sh" -exec chmod +x {} \;
    chmod +x "${PROJECT_ROOT}/main.sh"
    
    # 로그 디렉토리 권한 설정
    mkdir -p "${PROJECT_ROOT}/logs"
    chmod 755 "${PROJECT_ROOT}/logs"
    
    # 백업 디렉토리 권한 설정
    mkdir -p "${PROJECT_ROOT}/backup"
    chmod 755 "${PROJECT_ROOT}/backup"
    
    # Docker 볼륨 디렉토리 권한 설정
    mkdir -p "${PROJECT_ROOT}/docker"
    chmod 755 "${PROJECT_ROOT}/docker"
    
    log_success "권한 설정 완료"
}

# 메인 실행 함수
main() {
    log_info "=== 환경 설정 스크립트 시작 ==="
    
    validate_environment
    collect_system_info
    validate_network
    create_docker_network
    configure_timezone
    save_environment_info
    set_permissions
    
    log_success "=== 환경 설정 완료 ==="
    log_info "다음 단계: Docker 서비스 설정을 진행하세요."
}

# 스크립트 실행
main "$@"
