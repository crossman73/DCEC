#!/bin/bash
# NAS Direct Deployment Script (감사 대응 최적화)
# - v2.1: Gemini-assisted refactoring
# - 개선 사항:
#   1. docker-compose.yml에서 서비스 목록 동적 파싱
#   2. 설치 여부 확인 기준을 Docker 이미지에서 컨테이너로 변경
#   3. gitea, n8n 선택 시 postgres 의존성 자동 추가
#   4. 실행 위치에 무관하게 동작하도록 동적 경로 감지 기능 추가

set -euo pipefail

# =========================
# SSH 키 자동화 및 검증
# =========================
setup_ssh_keys() {
    if [[ ! -f "$HOME/.ssh/id_rsa" ]]; then
        ssh-keygen -t rsa -b 4096 -N "" -f "$HOME/.ssh/id_rsa"
    fi
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_rsa.pub"
    ssh-copy-id -p "$NAS_PORT" "$NAS_USER@$NAS_IP" || { log_error "SSH key copy failed"; exit 1; }
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys"
}

# =========================
# 컬러 로그 함수
# =========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# =========================
# 필수 파일 체크
# =========================
check_required_files() {
    log_info "Checking required local files..."
    local missing=0
    for f in ".env" "docker-compose.yml" "postgres-init/init-multiple-dbs.sh"; do
        if [[ ! -f "${LOCAL_DIR}/$f" ]]; then
            log_error "Required file missing: ${LOCAL_DIR}/$f"
            missing=1
        fi
    done
    if [[ $missing -eq 1 ]]; then
        log_error "필수 파일이 누락되어 배포를 중단합니다."
        exit 1
    fi
    log_success "All required files exist."
}

# =========================
# SSH 연결 체크
# =========================
check_ssh_connection() {
    log_info "Checking SSH connection to NAS..."
    if ssh -p "${NAS_PORT}" -o ConnectTimeout=10 "${NAS_USER}@${NAS_IP}" "echo 'SSH connection successful'"; then
        log_success "SSH connection to NAS established"
    else
        log_error "Cannot connect to NAS via SSH"
        exit 1
    fi
}

# =========================
# 백업
# =========================
create_backup() {
    log_info "Creating backup of existing configuration on NAS..."
    local backup_ts
    backup_ts=$(date +%Y%m%d%H%M%S)
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "
        if [ -d ${REMOTE_DIR} ]; then
            echo 'Backing up ${REMOTE_DIR} to ${REMOTE_DIR}.bak.${backup_ts}'
            cp -a ${REMOTE_DIR} ${REMOTE_DIR}.bak.${backup_ts}
        else
            echo 'No existing directory to back up.'
        fi
    "
}

# =========================
# 파일 전송 (rsync)
# =========================
transfer_files() {
    log_info "Transferring files to NAS using rsync..."
    rsync -avz --delete -e "ssh -p ${NAS_PORT}" "${LOCAL_DIR}/" "${NAS_USER}@${NAS_IP}:${REMOTE_DIR}/"
    if [[ $? -ne 0 ]]; then
        log_error "rsync 파일 전송 실패"
        exit 1
    fi
    log_success "Files transferred successfully"
}

# =========================
# 원격지 권한 설정
# =========================
fix_remote_permissions() {
    log_info "Setting permissions on remote directory..."
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "
        sudo chown -R ${NAS_USER}:users ${REMOTE_DIR}
        sudo chmod -R 755 ${REMOTE_DIR}
        if [ -f ${REMOTE_DIR}/postgres-init/init-multiple-dbs.sh ]; then
            chmod +x ${REMOTE_DIR}/postgres-init/init-multiple-dbs.sh
        fi
    "
    log_success "Remote permissions set."
}

# =========================
# 서비스별 설치 여부 확인 및 설치 함수 (컨테이너 존재 기준)
# =========================
install_service() {
    local svc="$1"
    local exists
    exists=$(ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "docker ps -a --format '{{.Names}}' | grep -w \"$svc\" || true")
    
    if [[ -n "$exists" ]]; then
        read -p "--> Service '$svc' is already installed. Re-install/update? (y/n): " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            ENABLED_SERVICES+=("$svc")
        else
            log_info "Skipping '$svc'."
        fi
    else
        read -p "--> Install new service '$svc'? (y/n): " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            ENABLED_SERVICES+=("$svc")
        else
            log_info "Skipping '$svc'."
        fi
    fi
}

# =========================
# 설치할 서비스 선택 (동적 목록 및 의존성 처리)
# =========================
select_services_to_install() {
    log_info "--- Select services to install/update ---"
    ALL_SERVICES=$(grep -E '^\s{2}[a-zA-Z0-9_-]+:' "${LOCAL_DIR}/docker-compose.yml" | sed -e 's/://' -e 's/^[ \t]*//' | tr '\n' ' ')
    
    if [[ -z "$ALL_SERVICES" ]]; then
        log_error "Could not find any services in docker-compose.yml. Exiting."
        exit 1
    fi
    log_info "Available services: $ALL_SERVICES"

    ENABLED_SERVICES=()
    for svc in $ALL_SERVICES; do
        install_service "$svc"
    done

    local needs_postgres=0
    local postgres_in_list=0
    for svc in "${ENABLED_SERVICES[@]}"; do
        if [[ "$svc" == "gitea" || "$svc" == "n8n" ]]; then
            needs_postgres=1
        fi
        if [[ "$svc" == "postgres" ]]; then
            postgres_in_list=1
        fi
    done

    if [[ $needs_postgres -eq 1 && $postgres_in_list -eq 0 ]]; then
        if [[ "$ALL_SERVICES" == *"postgres"* ]]; then
            log_warning "A selected service requires 'postgres'. Adding 'postgres' to the deployment list."
            ENABLED_SERVICES+=("postgres")
        fi
    fi
}

# =========================
# Docker 서비스 배포(선택된 서비스만)
# =========================
deploy_services() {
    log_info "--- Deploying selected Docker services ---"
    if [[ ${#ENABLED_SERVICES[@]} -eq 0 ]]; then
        log_warning "No services selected. Nothing to deploy."
        exit 0
    fi

    local services_to_deploy
    services_to_deploy=$(IFS=' '; echo "${ENABLED_SERVICES[*]}")
    
    log_info "Services to be deployed: $services_to_deploy"

    log_info "Stopping existing containers for selected services..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker compose stop ${services_to_deploy}"
    
    log_info "Running docker compose up..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker compose up -d --remove-orphans ${services_to_deploy}"
    
    log_success "Deployment command executed for: $services_to_deploy"
}

# =========================
# 서비스별 헬스체크
# =========================
validate_service_health() {
    log_info "--- Validating service health ---"
    declare -A PORTS=( [n8n]=5678 [gitea]=3000 [postgres]=5432 [uptime-kuma]=3001 )
    
    for svc in "${ENABLED_SERVICES[@]}"; do
        if [[ -z "${PORTS[$svc]:-}" ]]; then
            log_warning "No health check port defined for '$svc'. Skipping."
            continue
        fi
        
        local port="${PORTS[$svc]}"
        log_info "Checking health for '$svc' on port $port..."
        local healthy=0
        for i in {1..10}; do
            if nc -z -w5 "$NAS_IP" "$port"; then
                log_success "'$svc' port $port is open."
                healthy=1
                break
            fi
            log_info "Attempt $i/10: '$svc' port $port not yet open. Retrying in 5 seconds..."
            sleep 5
        done

        if [[ $healthy -eq 0 ]]; then
            log_error "Health check failed for '$svc' after 10 attempts."
            log_error "Please check the container logs on the NAS: docker logs $svc"
        fi
    done
}

# =========================
# 메인 실행부
# =========================
main() {
    # --- Dynamic Path Configuration ---
    log_info "Determining script location dynamically..."
    LOCAL_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
    REMOTE_DIR="/volume1/docker/dev"
    log_success "Script local directory set to: ${LOCAL_DIR}"
    cd "$LOCAL_DIR"

    # --- NAS Connection Setup ---
    if [[ -f ".env" ]]; then
        export $(grep -v '^#' .env | xargs)
    else
        log_error ".env file not found. Please create it with NAS connection details (NAS_IP, NAS_USER, NAS_PORT)."
        exit 1
    fi

    # setup_ssh_keys # 최초 1회만 필요하므로 주석 처리. 필요시 주석 해제.
    check_ssh_connection
    check_required_files
    
    create_backup
    transfer_files
    fix_remote_permissions
    
    select_services_to_install
    
    deploy_services
    
    validate_service_health

    log_success "Deployment script finished!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi