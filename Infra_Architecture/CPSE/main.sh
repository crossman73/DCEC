#!/bin/bash

# NAS-SubDomain-Manager - 시놀로지 NAS 서브도메인 자동화 관리 시스템
# Version: 1.0.0
# Author: DCEC Infrastructure Team
# Description: 시놀로지 NAS crossman.synology.me 도메인 기반 서브도메인 자동화 관리

set -euo pipefail

# 색상 정의
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# 기본 설정
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_NAME="NAS-SubDomain-Manager"
readonly VERSION="1.0.0"
readonly LOG_FILE="${SCRIPT_DIR}/logs/main.log"

# 로그 함수들
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "${LOG_FILE}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_FILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_FILE}"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1" | tee -a "${LOG_FILE}"
}

log_success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1" | tee -a "${LOG_FILE}"
}

log_header() {
    echo -e "${CYAN}===============================================${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${CYAN}===============================================${NC}"
}

# 승인 시스템 로드
source "${SCRIPT_DIR}/scripts/security/approval.sh"

# 환경 변수 로드
load_environment() {
    if [[ -f "${SCRIPT_DIR}/.env" ]]; then
        source "${SCRIPT_DIR}/.env"
        log_info "환경 변수 로드 완료: .env"
    else
        log_warn ".env 파일이 없습니다. 기본 설정을 사용합니다."
    fi
}

# 사전 검사 함수
check_prerequisites() {
    log_step "시스템 사전 검사 시작"
    
    # DSM 버전 확인
    if command -v synopkg &> /dev/null; then
        local dsm_version=$(cat /etc.defaults/VERSION | grep majorversion | cut -d'"' -f4)
        if [[ ${dsm_version} -lt 7 ]]; then
            log_error "DSM 7.0 이상이 필요합니다. 현재 버전: ${dsm_version}"
            exit 1
        fi
        log_info "DSM 버전 확인: ${dsm_version}.x"
    fi
    
    # Docker 서비스 확인
    if ! systemctl is-active --quiet docker 2>/dev/null && ! service docker status &>/dev/null; then
        log_error "Docker 서비스가 실행되지 않습니다."
        exit 1
    fi
    log_info "Docker 서비스 상태: 정상"
    
    # 권한 확인 (root 권한 방지)
    if [[ $EUID -eq 0 ]]; then
        log_error "보안상 root 권한으로 실행할 수 없습니다. 일반 사용자로 실행해주세요."
        exit 1
    fi
    log_info "사용자 권한 확인: 정상"
    
    log_success "시스템 사전 검사 완료"
}

# 도움말 표시
show_help() {
    log_header "${PROJECT_NAME} v${VERSION}"
    echo ""
    echo "사용법: $0 <command> [options]"
    echo ""
    echo "기본 Commands:"
    echo "  install     - 전체 시스템 설치 및 구성"
    echo "  setup       - 초기 설정만 실행"
    echo "  start       - 모든 서비스 시작"
    echo "  stop        - 모든 서비스 중지"
    echo "  restart     - 모든 서비스 재시작"
    echo "  status      - 서비스 상태 확인"
    echo "  backup      - 백업 실행"
    echo "  restore     - 백업에서 복원"
    echo "  update      - 시스템 업데이트"
    echo "  logs        - 로그 확인"
    echo "  health      - 헬스체크 실행"
    echo "  clean       - 정리 작업"
    echo ""
    echo "백업/복원 Commands:"
    echo "  backup-list      - 백업 목록 보기"
    echo "  backup-info      - 백업 정보 표시"
    echo "  restore-list     - 복원 가능한 백업 목록"
    echo ""
    echo "승인 시스템 Commands:"
    echo "  approval-log      - 승인 로그 보기"
    echo "  approval-stats    - 승인 통계 보기"
    echo "  test-mode-on      - 테스트 모드 활성화 (자동 승인)"
    echo "  test-mode-off     - 테스트 모드 비활성화"
    echo ""
    echo "  help        - 이 도움말 표시"
    echo ""
    echo "Examples:"
    echo "  $0 install                 # 전체 설치"
    echo "  $0 status                  # 상태 확인"
    echo "  $0 logs --service=gitea    # Gitea 로그 확인"
    echo "  $0 approval-log            # 최근 승인 로그 확인"
    echo "  $0 test-mode-on            # 테스트 모드 활성화"
    echo "  $0 backup                  # 시스템 백업"
    echo "  $0 restore                 # 백업에서 복원"
    echo "  $0 backup-list             # 백업 목록 확인"
    echo ""
    echo "안전 기능:"
    echo "  - 모든 중요한 작업은 사용자 승인을 요구합니다"
    echo "  - 파괴적 작업은 특별한 확인 문구를 요구합니다"
    echo "  - 모든 승인 요청과 결과가 로그에 기록됩니다"
    echo "  - 테스트 모드에서는 자동 승인됩니다"
    echo ""
}

# 전체 설치
install_system() {
    log_header "NAS-SubDomain-Manager 설치 시작"
    
    # 설치 승인 요청
    if ! request_approval_safe "FULL_SYSTEM_INSTALL" \
        "전체 시스템 설치: 환경 설정, 보안 설정, 서비스 설치, 모니터링 설정" \
        "high" \
        "INSTALL_CONFIRMED"; then
        log_error "설치가 취소되었습니다."
        exit 1
    fi
    
    setup_environment
    setup_security
    setup_services
    start_services
    setup_monitoring
    
    log_success "설치가 완료되었습니다!"
    log_info "서비스 상태를 확인하려면: $0 status"
}

# 환경 설정
setup_environment() {
    log_step "환경 설정 시작"
    
    # 스크립트 실행
    "${SCRIPT_DIR}/scripts/setup/environment.sh"
    "${SCRIPT_DIR}/scripts/setup/directories.sh"
    
    log_success "환경 설정 완료"
}

# 보안 설정
setup_security() {
    log_step "보안 설정 시작"
    
    "${SCRIPT_DIR}/scripts/security/firewall.sh"
    "${SCRIPT_DIR}/scripts/security/ssl.sh"
    
    log_success "보안 설정 완료"
}

# 서비스 설정
setup_services() {
    log_step "서비스 설정 시작"
    
    "${SCRIPT_DIR}/scripts/services/docker-compose.sh"
    "${SCRIPT_DIR}/scripts/services/dns.sh"
    
    log_success "서비스 설정 완료"
}

# 서비스 시작
start_services() {
    log_step "서비스 시작"
    
    # 서비스 시작 승인 요청
    if ! request_approval_safe "START_SERVICES" \
        "모든 Docker 서비스 시작 (MCP, Uptime Kuma, Code Server, Gitea, DSM, Portainer)" \
        "low" \
        "start"; then
        log_error "서비스 시작이 취소되었습니다."
        return 1
    fi
    
    cd "${SCRIPT_DIR}"
    if docker-compose up -d; then
        log_success "모든 서비스가 시작되었습니다"
    else
        log_error "서비스 시작 중 오류가 발생했습니다"
        return 1
    fi
}

# 서비스 중지
stop_services() {
    log_step "서비스 중지"
    
    # 서비스 중지 승인 요청
    if ! request_service_interruption_approval "STOP_SERVICES" \
        "모든 Docker 서비스 중지 - 웹 접근이 일시적으로 중단됩니다" \
        "MCP Server, Uptime Kuma, Code Server, Gitea, DSM Proxy, Portainer"; then
        log_error "서비스 중지가 취소되었습니다."
        return 1
    fi
    
    cd "${SCRIPT_DIR}"
    if docker-compose down; then
        log_success "모든 서비스가 중지되었습니다"
    else
        log_error "서비스 중지 중 오류가 발생했습니다"
        return 1
    fi
}

# 서비스 재시작
restart_services() {
    log_step "서비스 재시작"
    
    # 서비스 재시작 승인 요청
    if ! request_service_interruption_approval "RESTART_SERVICES" \
        "모든 Docker 서비스 재시작 - 약 30초간 서비스 중단됩니다" \
        "MCP Server, Uptime Kuma, Code Server, Gitea, DSM Proxy, Portainer"; then
        log_error "서비스 재시작이 취소되었습니다."
        return 1
    fi
    
    stop_services
    sleep 5
    start_services
}

# 서비스 상태 확인
check_status() {
    log_header "서비스 상태 확인"
    
    "${SCRIPT_DIR}/scripts/maintenance/status.sh"
}

# 백업 실행
run_backup() {
    log_step "백업 실행 시작"
    
    # 백업 승인 요청
    if ! request_approval_safe "RUN_BACKUP" \
        "시스템 전체 백업 실행 (설정, 데이터, Docker 볼륨)" \
        "low" \
        "backup"; then
        log_error "백업이 취소되었습니다."
        return 1
    fi
    
    "${SCRIPT_DIR}/scripts/maintenance/backup.sh"
    
    log_success "백업이 완료되었습니다"
}

# 시스템 업데이트
update_system() {
    log_step "시스템 업데이트 시작"
    
    # 업데이트 승인 요청
    if ! request_service_interruption_approval "UPDATE_SYSTEM" \
        "시스템 업데이트 - Docker 이미지 업데이트 및 서비스 재시작" \
        "모든 웹 서비스"; then
        log_error "시스템 업데이트가 취소되었습니다."
        return 1
    fi
    
    "${SCRIPT_DIR}/scripts/maintenance/update.sh"
    
    log_success "시스템 업데이트가 완료되었습니다"
}

# 로그 확인
show_logs() {
    local service_name="${2:-all}"
    
    if [[ "$service_name" == "all" ]]; then
        tail -f "${LOG_FILE}"
    else
        docker-compose logs -f "$service_name"
    fi
}

# 헬스체크
run_health_check() {
    log_step "헬스체크 실행"
    
    "${SCRIPT_DIR}/scripts/maintenance/health.sh"
}

# 정리 작업
clean_system() {
    log_step "시스템 정리 시작"
    
    # 정리 작업 승인 요청
    if ! request_destructive_approval "CLEAN_SYSTEM" \
        "시스템 정리: 사용하지 않는 Docker 이미지, 컨테이너, 볼륨, 로그 파일 삭제"; then
        log_error "시스템 정리가 취소되었습니다."
        return 1
    fi
    
    "${SCRIPT_DIR}/scripts/maintenance/cleanup.sh"
    
    log_success "시스템 정리가 완료되었습니다"
}

# 모니터링 설정
setup_monitoring() {
    log_step "모니터링 설정 시작"
    
    "${SCRIPT_DIR}/scripts/setup/monitoring.sh"
    
    log_success "모니터링 설정 완료"
}

# 메인 실행 함수
main() {
    # 로그 디렉토리 생성
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    # 시작 로그
    log_info "=== ${PROJECT_NAME} v${VERSION} 시작 ==="
    log_info "실행 시간: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "실행 사용자: $(whoami)"
    log_info "실행 경로: ${SCRIPT_DIR}"
    
    # 환경 변수 로드
    load_environment
    
    # 명령어 파싱
    case "${1:-help}" in
        "install")
            check_prerequisites
            install_system
            ;;
        "setup")
            check_prerequisites
            setup_environment
            ;;
        "start")
            start_services
            ;;
        "stop")
            stop_services
            ;;
        "restart")
            restart_services
            ;;
        "status")
            check_status
            ;;
        "backup")
            run_backup
            ;;
        "restore")
            "${SCRIPT_DIR}/scripts/maintenance/restore.sh" restore "${2:-}"
            ;;
        "backup-list")
            "${SCRIPT_DIR}/scripts/maintenance/backup.sh" list
            ;;
        "backup-info")
            "${SCRIPT_DIR}/scripts/maintenance/restore.sh" info "${2:-}"
            ;;
        "restore-list")
            "${SCRIPT_DIR}/scripts/maintenance/restore.sh" list
            ;;
        "update")
            update_system
            ;;
        "logs")
            show_logs "$@"
            ;;
        "health")
            run_health_check
            ;;
        "clean")
            clean_system
            ;;
        "approval-log")
            show_approval_log "${2:-20}"
            ;;
        "approval-stats")
            show_approval_stats
            ;;
        "test-mode-on")
            enable_test_mode
            ;;
        "test-mode-off")
            disable_test_mode
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            log_error "알 수 없는 명령어: $1"
            show_help
            exit 1
            ;;
    esac
    
    log_info "=== ${PROJECT_NAME} 실행 완료 ==="
}

# 스크립트 실행
main "$@"
