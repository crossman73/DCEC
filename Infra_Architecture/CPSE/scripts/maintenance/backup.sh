#!/bin/bash

# Backup Script - 시스템 백업 스크립트
# NAS-SubDomain-Manager 백업 및 복원 시스템

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
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly BACKUP_DIR="${PROJECT_ROOT}/backup"
readonly LOG_FILE="${PROJECT_ROOT}/logs/backup.log"

# 백업 설정
readonly BACKUP_DATE=$(date '+%Y%m%d_%H%M%S')
readonly BACKUP_NAME="nas_subdomain_backup_${BACKUP_DATE}"
readonly BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

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

# 백업 디렉토리 생성
create_backup_directory() {
    log_step "백업 디렉토리 생성: ${BACKUP_PATH}"
    
    mkdir -p "${BACKUP_PATH}"
    mkdir -p "${BACKUP_PATH}/config"
    mkdir -p "${BACKUP_PATH}/docker"
    mkdir -p "${BACKUP_PATH}/logs"
    mkdir -p "${BACKUP_PATH}/scripts"
    mkdir -p "${BACKUP_PATH}/volumes"
    
    log_success "백업 디렉토리 생성 완료"
}

# 설정 파일 백업
backup_config_files() {
    log_step "설정 파일 백업 시작"
    
    # 메인 설정 파일들
    local config_files=(
        ".env"
        "docker-compose.yml"
        "main.sh"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            cp "${PROJECT_ROOT}/${file}" "${BACKUP_PATH}/config/"
            log_info "백업 완료: ${file}"
        else
            log_warn "파일이 존재하지 않습니다: ${file}"
        fi
    done
    
    # config 디렉토리 전체 백업
    if [[ -d "${PROJECT_ROOT}/config" ]]; then
        cp -r "${PROJECT_ROOT}/config/"* "${BACKUP_PATH}/config/" 2>/dev/null || true
        log_info "config 디렉토리 백업 완료"
    fi
    
    log_success "설정 파일 백업 완료"
}

# 스크립트 백업
backup_scripts() {
    log_step "스크립트 파일 백업 시작"
    
    if [[ -d "${PROJECT_ROOT}/scripts" ]]; then
        cp -r "${PROJECT_ROOT}/scripts/"* "${BACKUP_PATH}/scripts/" 2>/dev/null || true
        log_info "scripts 디렉토리 백업 완료"
    fi
    
    log_success "스크립트 파일 백업 완료"
}

# Docker 볼륨 백업
backup_docker_volumes() {
    log_step "Docker 볼륨 백업 시작"
    
    # Docker가 실행 중인지 확인
    if ! docker info &>/dev/null; then
        log_warn "Docker가 실행되지 않습니다. 볼륨 백업을 건너뜁니다."
        return 0
    fi
    
    # 프로젝트 관련 볼륨 찾기
    local volumes=$(docker volume ls --format "{{.Name}}" | grep -E "(nas|subdomain|gitea|uptime|codeserver|portainer)" 2>/dev/null || true)
    
    if [[ -n "${volumes}" ]]; then
        log_info "발견된 볼륨: ${volumes}"
        
        while IFS= read -r volume; do
            if [[ -n "${volume}" ]]; then
                log_info "볼륨 백업 중: ${volume}"
                
                # 볼륨을 tar 파일로 백업
                docker run --rm \
                    -v "${volume}:/source:ro" \
                    -v "${BACKUP_PATH}/volumes:/backup" \
                    alpine:latest \
                    tar czf "/backup/${volume}.tar.gz" -C /source .
                
                log_info "볼륨 백업 완료: ${volume}.tar.gz"
            fi
        done <<< "${volumes}"
    else
        log_info "백업할 Docker 볼륨이 없습니다."
    fi
    
    log_success "Docker 볼륨 백업 완료"
}

# 로그 파일 백업
backup_logs() {
    log_step "로그 파일 백업 시작"
    
    if [[ -d "${PROJECT_ROOT}/logs" ]]; then
        # 최근 30일 로그만 백업
        find "${PROJECT_ROOT}/logs" -name "*.log" -mtime -30 -exec cp {} "${BACKUP_PATH}/logs/" \; 2>/dev/null || true
        log_info "로그 파일 백업 완료 (최근 30일)"
    fi
    
    log_success "로그 파일 백업 완료"
}

# 백업 메타데이터 생성
create_backup_metadata() {
    log_step "백업 메타데이터 생성"
    
    local metadata_file="${BACKUP_PATH}/backup_info.txt"
    
    cat > "${metadata_file}" << EOF
NAS-SubDomain-Manager 백업 정보
=====================================

백업 생성일시: $(date '+%Y-%m-%d %H:%M:%S')
백업 이름: ${BACKUP_NAME}
백업 버전: 1.0.0
시스템 정보: $(uname -a)
사용자: $(whoami)
Docker 버전: $(docker --version 2>/dev/null || echo "Docker not available")
Docker Compose 버전: $(docker-compose --version 2>/dev/null || echo "Docker Compose not available")

백업 포함 항목:
- 설정 파일 (.env, docker-compose.yml, main.sh)
- config 디렉토리
- scripts 디렉토리
- Docker 볼륨
- 로그 파일 (최근 30일)

복원 방법:
1. 백업 디렉토리를 원하는 위치에 복사
2. restore.sh 스크립트 실행
3. 서비스 재시작

주의사항:
- 복원 전 현재 데이터 백업 권장
- 동일한 시스템 환경에서 복원 권장
- Docker 볼륨 복원 시 기존 데이터 덮어쓰기 주의

EOF

    log_success "백업 메타데이터 생성 완료"
}

# 백업 압축
compress_backup() {
    log_step "백업 압축 시작"
    
    cd "${BACKUP_DIR}"
    tar czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}/"
    
    # 압축 파일 크기 확인
    local backup_size=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    log_info "압축된 백업 파일 크기: ${backup_size}"
    
    # 원본 디렉토리 삭제 (선택사항)
    if [[ "${KEEP_UNCOMPRESSED:-false}" != "true" ]]; then
        rm -rf "${BACKUP_NAME}/"
        log_info "압축 후 원본 디렉토리 삭제"
    fi
    
    log_success "백업 압축 완료: ${BACKUP_NAME}.tar.gz"
}

# 오래된 백업 정리
cleanup_old_backups() {
    local keep_days="${BACKUP_RETENTION_DAYS:-7}"
    
    log_step "오래된 백업 정리 (${keep_days}일 이상)"
    
    if [[ -d "${BACKUP_DIR}" ]]; then
        # 오래된 백업 파일 찾기 및 삭제
        find "${BACKUP_DIR}" -name "nas_subdomain_backup_*.tar.gz" -mtime +${keep_days} -delete 2>/dev/null || true
        
        # 현재 백업 파일 개수 확인
        local backup_count=$(find "${BACKUP_DIR}" -name "nas_subdomain_backup_*.tar.gz" | wc -l)
        log_info "현재 보관 중인 백업 파일 개수: ${backup_count}"
    fi
    
    log_success "오래된 백업 정리 완료"
}

# 백업 검증
verify_backup() {
    log_step "백업 검증 시작"
    
    local backup_file="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    
    if [[ -f "${backup_file}" ]]; then
        # 압축 파일 무결성 확인
        if tar tzf "${backup_file}" >/dev/null 2>&1; then
            log_success "백업 파일 무결성 확인 완료"
        else
            log_error "백업 파일이 손상되었습니다"
            return 1
        fi
        
        # 필수 파일 존재 확인
        local required_files=(
            "${BACKUP_NAME}/backup_info.txt"
            "${BACKUP_NAME}/config/"
            "${BACKUP_NAME}/scripts/"
        )
        
        for file in "${required_files[@]}"; do
            if tar tzf "${backup_file}" "${file}" >/dev/null 2>&1; then
                log_info "필수 파일 확인: ${file}"
            else
                log_warn "필수 파일 누락: ${file}"
            fi
        done
        
        log_success "백업 검증 완료"
    else
        log_error "백업 파일을 찾을 수 없습니다: ${backup_file}"
        return 1
    fi
}

# 백업 목록 표시
list_backups() {
    log_step "백업 목록 조회"
    
    if [[ -d "${BACKUP_DIR}" ]]; then
        local backups=$(find "${BACKUP_DIR}" -name "nas_subdomain_backup_*.tar.gz" -type f | sort -r)
        
        if [[ -n "${backups}" ]]; then
            echo -e "${CYAN}사용 가능한 백업 파일:${NC}"
            echo ""
            
            while IFS= read -r backup_file; do
                local filename=$(basename "${backup_file}")
                local size=$(du -h "${backup_file}" | cut -f1)
                local date=$(stat -c %y "${backup_file}" 2>/dev/null || stat -f %Sm "${backup_file}" 2>/dev/null || echo "Unknown")
                
                echo -e "${WHITE}파일명:${NC} ${filename}"
                echo -e "${WHITE}크기:${NC} ${size}"
                echo -e "${WHITE}생성일:${NC} ${date}"
                echo ""
            done <<< "${backups}"
        else
            log_info "백업 파일이 없습니다."
        fi
    else
        log_warn "백업 디렉토리가 존재하지 않습니다: ${BACKUP_DIR}"
    fi
}

# 전체 백업 실행
run_full_backup() {
    log_info "=== NAS-SubDomain-Manager 백업 시작 ==="
    log_info "백업 시작 시간: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 로그 디렉토리 생성
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    # 백업 실행
    create_backup_directory
    backup_config_files
    backup_scripts
    backup_docker_volumes
    backup_logs
    create_backup_metadata
    compress_backup
    verify_backup
    cleanup_old_backups
    
    log_success "=== 백업 완료 ==="
    log_info "백업 파일: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    log_info "백업 완료 시간: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 메인 함수
main() {
    case "${1:-backup}" in
        "backup")
            run_full_backup
            ;;
        "list")
            list_backups
            ;;
        "help"|"-h"|"--help")
            echo "사용법: $0 [backup|list|help]"
            echo ""
            echo "Commands:"
            echo "  backup  - 전체 백업 실행 (기본값)"
            echo "  list    - 백업 목록 조회"
            echo "  help    - 도움말 표시"
            ;;
        *)
            log_error "알 수 없는 명령어: $1"
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
