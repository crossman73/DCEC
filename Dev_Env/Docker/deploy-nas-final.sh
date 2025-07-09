#!/bin/bash
# NAS Direct Deployment Script (감사 대응 최적화)
# - 환경 자동 감지, SSH 키 자동화, 백업/롤백, 서비스별 헬스체크, 권한/보안, 장애 자동 대응, 서비스 격리, 통합 로그 등
#   외부 감사 지적사항을 모두 반영한 버전입니다.

set -euo pipefail

# =========================
# 환경 자동 감지
# =========================
detect_environment() {
    if grep -qi microsoft /proc/version 2>/dev/null; then
        LOCAL_DIR="/mnt/d/Dev/DCEC/Dev_Env/Docker"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        LOCAL_DIR="$HOME/Dev/DCEC/Dev_Env/Docker"
    else
        LOCAL_DIR="$HOME/Dev/DCEC/Dev_Env/Docker"
    fi
    REMOTE_DIR="/volume1/docker/dev"
    read -p "Detected LOCAL_DIR: $LOCAL_DIR, REMOTE_DIR: $REMOTE_DIR. Continue? (y/n): " yn
    [[ "$yn" =~ ^[Yy]$ ]] || exit 1
}

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

LOG_DIR="/volume1/docker/logs"
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; logger -p user.info -t deploy-nas-final "$1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; logger -p user.info -t deploy-nas-final "$1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; logger -p user.warning -t deploy-nas-final "$1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; logger -p user.err -t deploy-nas-final "$1"; }

# =========================
# 필수 파일 체크
# =========================
check_required_files() {
    log_info "Checking required local files..."
    local missing=0
    for f in ".env.global" "docker-compose.yml" "nas-setup-complete.sh"; do
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
# 백업/롤백
# =========================
create_backup() {
    log_info "Creating backup snapshot..."
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "
        ls -dt $REMOTE_DIR.bak.* 2>/dev/null | tail -n +2 | xargs -r rm -rf
        cp -a $REMOTE_DIR $REMOTE_DIR.bak.$(date +%Y%m%d%H%M%S)
    "
}
rollback_deployment() {
    log_warning "Rolling back deployment..."
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "rm -rf $REMOTE_DIR && mv $REMOTE_DIR.bak.* $REMOTE_DIR"
    notify_slack "NAS 배포 롤백 발생: $(date) - $REMOTE_DIR 복구됨"
}

# =========================
# 파일 전송 (rsync)
# =========================
transfer_files() {
    log_info "Transferring files to NAS using rsync..."
    rsync -avz -e "ssh -p ${NAS_PORT}" "${LOCAL_DIR}/" "${NAS_USER}@${NAS_IP}:${REMOTE_DIR}/"
    if [[ $? -ne 0 ]]; then
        log_error "rsync 파일 전송 실패"
        auto_recovery "network_error"
        exit 1
    fi
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "sudo chown -R ${NAS_USER}:users ${REMOTE_DIR} && sudo chmod +x ${REMOTE_DIR}/nas-setup-complete.sh"
    log_success "Files transferred and permissions set successfully"
}

# =========================
# 권한/보안 자동화
# =========================
SERVICE_GROUP="${SERVICE_GROUP:-users}"
fix_permissions() {
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "sudo chown -R $NAS_USER:$SERVICE_GROUP $REMOTE_DIR && sudo chmod -R 755 $REMOTE_DIR"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/id_rsa"
}

# =========================
# 서비스별 .env 분리/격리 및 공통 사용자 정보 적용
# =========================
SERVICE_USER="crossman"
SERVICE_PASS="data!5522"

setup_service_env() {
    for svc in n8n gitea code-server uptime-kuma portainer; do
        cp "$LOCAL_DIR/.env.global" "$LOCAL_DIR/.env.$svc"
        echo "USER_ID=${SERVICE_USER}"   >> "$LOCAL_DIR/.env.$svc"
        echo "USER_PASS=${SERVICE_PASS}" >> "$LOCAL_DIR/.env.$svc"
        # 서비스별 환경 변수 추가/수정 필요시 여기에
    done
}

# =========================
# 셋업 스크립트 실행
# =========================
run_setup_script() {
    log_info "Running setup script on NAS..."
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && ./nas-setup-complete.sh"
    if [[ $? -ne 0 ]]; then
        log_error "셋업 스크립트 실행 실패"
        auto_recovery "permission_denied"
        exit 1
    fi
    log_success "Setup script execution completed"
}

# =========================
# 서비스별 설치 여부 확인 및 설치 함수 (이미지 존재 시 재설치 여부 확인)
# =========================
install_service() {
    local svc="$1"
    # 원격 NAS에서 해당 서비스 컨테이너/이미지 존재 여부 확인
    local exists
    exists=$(ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "docker images --format '{{.Repository}}' | grep -w $svc || true")
    if [[ -n "$exists" ]]; then
        read -p "$svc 도커 이미지가 이미 존재합니다. 재설치(업데이트) 하시겠습니까? (y/n): " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            ENABLED_SERVICES+=("$svc")
        else
            log_info "$svc 서비스는 재설치하지 않습니다."
        fi
    else
        read -p "$svc 서비스를 설치하시겠습니까? (y/n): " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            ENABLED_SERVICES+=("$svc")
        else
            log_info "$svc 서비스는 설치하지 않습니다."
        fi
    fi
}

# =========================
# 서비스별 설치 여부 확인
# =========================
select_services_to_install() {
    ENABLED_SERVICES=()
    for svc in n8n gitea code-server uptime-kuma portainer; do
        install_service "$svc"
    done
}

# =========================
# Docker 서비스 배포(선택된 서비스만)
# =========================
deploy_services() {
    log_info "Deploying selected Docker services on NAS..."
    local svc_args=()
    for svc in "${ENABLED_SERVICES[@]}"; do
        svc_args+=("$svc")
    done
    if [[ ${#svc_args[@]} -eq 0 ]]; then
        log_warning "선택된 서비스가 없습니다. 배포를 중단합니다."
        exit 0
    fi
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker compose down --remove-orphans"
    ssh -p "${NAS_PORT}" "${NAS_USER}@${NAS_IP}" "cd ${REMOTE_DIR} && docker compose up -d ${svc_args[*]}"
    log_success "Selected Docker services deployed: ${svc_args[*]}"
}

# =========================
# 서비스별 헬스체크 및 장애 자동 대응 (code-server 보완)
# =========================
declare -A PORTS=( [n8n]=31001 [gitea]=8484 [code-server]=3000 [uptime-kuma]=31003 [portainer]=9000 )
validate_service_health() {
    for svc in "${!PORTS[@]}"; do
        for i in {1..5}; do
            if [[ "$svc" == "code-server" ]]; then
                # code-server는 /health 미지원 → /로 200 응답 체크
                if ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "curl -fs -o /dev/null -w '%{http_code}' http://localhost:${PORTS[$svc]}/ | grep -q 200"; then
                    log_success "$svc health check passed"
                    break
                fi
            else
                # health endpoint가 없는 서비스는 docker-compose.yml의 healthcheck 옵션과 일치하는지 점검 필요
                if ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "curl -fs http://localhost:${PORTS[$svc]}/health"; then
                    log_success "$svc health check passed"
                    break
                fi
            fi
            if [[ $i -eq 5 ]]; then
                log_error "$svc health check failed after 5 attempts"
                auto_recovery "service_failed" "$svc"
                notify_slack "[$svc] 서비스 헬스체크 5회 실패, 롤백 또는 수동 점검 필요"
                return 1
            else
                sleep 5
            fi
        done
    done
}

# =========================
# 장애 자동 대응
# =========================
auto_recovery() {
    local errtype="$1" svc="${2:-}"
    case "$errtype" in
        permission_denied) fix_permissions ;;
        service_failed) rollback_deployment ;;
        network_error) log_error "Network error, manual intervention required" ;;
    esac
}

# =========================
# 서비스 정보 출력
# =========================
display_service_info() {
    log_info "Service Information:"
    echo ""
    echo "=== Service URLs ==="
    echo "n8n:              http://${NAS_IP}:31001"
    echo "Gitea:            http://${NAS_IP}:8484"
    echo "Code Server:      http://${NAS_IP}:3000"
    echo "Uptime Kuma:      http://${NAS_IP}:31003"
    echo "Portainer:        http://${NAS_IP}:9000"
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

# =========================
# 통합 모니터링/알림 (예시: Slack)
# =========================
notify_slack() {
    [[ -z "${SLACK_WEBHOOK_URL:-}" ]] && return
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$1\"}" "$SLACK_WEBHOOK_URL"
}

# =========================
# 기존 Docker 서비스/설정 점검
# =========================
check_existing_docker_state() {
    log_info "기존 Docker 컨테이너 및 포트 상태를 점검합니다."

    # 실행 중인 컨테이너
    log_info "[실행 중인 컨테이너 목록]"
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

    # compose 프로젝트
    log_info "[docker compose 프로젝트 목록]"
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "docker compose ls || echo 'compose 프로젝트 없음'"

    # 포트 점유 현황
    log_info "[컨테이너별 포트 점유 현황]"
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "docker ps --format 'table {{.Names}}\t{{.Ports}}'"

    # 불필요한 볼륨/네트워크/이미지
    log_info "[사용 중인 볼륨]"
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "docker volume ls"
    log_info "[사용 중인 네트워크]"
    ssh -p "$NAS_PORT" "$NAS_USER@$NAS_IP" "docker network ls"

    echo ""
    read -p "기존 Docker 서비스/설정이 위와 같이 남아 있습니다. 계속 진행할까요? (y/n): " yn
    [[ "$yn" =~ ^[Yy]$ ]] || { log_info "배포를 중단합니다."; exit 0; }
}

# =========================
# 메인 실행부
# =========================
main() {
    detect_environment
    setup_ssh_keys
    check_ssh_connection

    # 기존 Docker 상태 점검
    check_existing_docker_state

    check_required_files
    ensure_log_dir
    create_backup
    setup_service_env
    transfer_files
    fix_permissions
    run_setup_script

    # 서비스별 설치 여부 확인
    select_services_to_install

    deploy_services
    validate_service_health
    display_service_info
    log_success "Deployment completed successfully!"
    log_info "Check the service URLs above to verify everything is working."
    notify_slack "NAS 배포 자동화 성공: $(date)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi