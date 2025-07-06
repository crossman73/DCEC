#!/bin/bash

# Restore Script - 시스템 복원 스크립트
# NAS-SubDomain-Manager 백업에서 복원

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
readonly LOG_FILE="${PROJECT_ROOT}/logs/restore.log"

# 승인 시스템 로드
source "${PROJECT_ROOT}/scripts/security/approval.sh"

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

# 백업 파일 선택
select_backup_file() {
    local backup_file="$1"
    
    if [[ -z "${backup_file}" ]]; then
        log_step "사용 가능한 백업 파일 조회"
        
        local backups=($(find "${BACKUP_DIR}" -name "nas_subdomain_backup_*.tar.gz" -type f | sort -r))
        
        if [[ ${#backups[@]} -eq 0 ]]; then
            log_error "백업 파일을 찾을 수 없습니다."
            exit 1
        fi
        
        echo -e "${CYAN}사용 가능한 백업 파일:${NC}"
        for i in "${!backups[@]}"; do
            local filename=$(basename "${backups[i]}")
            local size=$(du -h "${backups[i]}" | cut -f1)
            echo "  $((i+1)). ${filename} (${size})"
        done
        echo ""
        
        echo -n "복원할 백업 파일 번호를 선택하세요 (1-${#backups[@]}): "
        read -r selection
        
        if [[ "${selection}" =~ ^[0-9]+$ ]] && [[ "${selection}" -ge 1 ]] && [[ "${selection}" -le ${#backups[@]} ]]; then
            backup_file="${backups[$((selection-1))]}"
        else
            log_error "잘못된 선택입니다."
            exit 1
        fi
    fi
    
    if [[ ! -f "${backup_file}" ]]; then
        log_error "백업 파일이 존재하지 않습니다: ${backup_file}"
        exit 1
    fi
    
    echo "${backup_file}"
}

# 백업 파일 검증
verify_backup_file() {
    local backup_file="$1"
    
    log_step "백업 파일 검증: $(basename "${backup_file}")"
    
    # 압축 파일 무결성 확인
    if ! tar tzf "${backup_file}" >/dev/null 2>&1; then
        log_error "백업 파일이 손상되었습니다: ${backup_file}"
        exit 1
    fi
    
    # 백업 메타데이터 확인
    if tar tzf "${backup_file}" | grep -q "backup_info.txt"; then
        log_info "백업 메타데이터 확인됨"
        
        # 백업 정보 표시
        echo -e "${CYAN}백업 정보:${NC}"
        tar xzf "${backup_file}" -O "*/backup_info.txt" | head -20
        echo ""
    else
        log_warn "백업 메타데이터가 없습니다"
    fi
    
    log_success "백업 파일 검증 완료"
}

# 현재 상태 백업
backup_current_state() {
    log_step "현재 상태 백업 (복원 전 안전 백업)"
    
    local safety_backup_name="safety_backup_$(date '+%Y%m%d_%H%M%S')"
    local safety_backup_dir="${BACKUP_DIR}/${safety_backup_name}"
    
    mkdir -p "${safety_backup_dir}"
    
    # 현재 설정 파일 백업
    local config_files=(".env" "docker-compose.yml" "main.sh")
    for file in "${config_files[@]}"; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            cp "${PROJECT_ROOT}/${file}" "${safety_backup_dir}/"
        fi
    done
    
    # config 디렉토리 백업
    if [[ -d "${PROJECT_ROOT}/config" ]]; then
        cp -r "${PROJECT_ROOT}/config" "${safety_backup_dir}/" 2>/dev/null || true
    fi
    
    # 압축
    cd "${BACKUP_DIR}"
    tar czf "${safety_backup_name}.tar.gz" "${safety_backup_name}/"
    rm -rf "${safety_backup_name}/"
    
    log_success "현재 상태 백업 완료: ${safety_backup_name}.tar.gz"
    return 0
}

# 서비스 중지
stop_services_for_restore() {
    log_step "복원을 위한 서비스 중지"
    
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        cd "${PROJECT_ROOT}"
        if docker-compose ps -q | grep -q .; then
            log_info "실행 중인 서비스 중지"
            docker-compose down
        else
            log_info "실행 중인 서비스가 없습니다"
        fi
    fi
    
    log_success "서비스 중지 완료"
}

# 설정 파일 복원
restore_config_files() {
    local backup_file="$1"
    local backup_name=$(basename "${backup_file}" .tar.gz)
    
    log_step "설정 파일 복원"
    
    # 임시 디렉토리에 백업 압축 해제
    local temp_dir=$(mktemp -d)
    trap "rm -rf ${temp_dir}" EXIT
    
    cd "${temp_dir}"
    tar xzf "${backup_file}"
    
    # 설정 파일 복원
    if [[ -d "${backup_name}/config" ]]; then
        # 기존 설정 파일들을 .backup으로 백업
        local config_files=(".env" "docker-compose.yml" "main.sh")
        for file in "${config_files[@]}"; do
            if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
                mv "${PROJECT_ROOT}/${file}" "${PROJECT_ROOT}/${file}.backup.$(date +%s)"
            fi
        done
        
        # 새 설정 파일 복사
        cp -r "${backup_name}/config/"* "${PROJECT_ROOT}/" 2>/dev/null || true
        
        # config 디렉토리 복원
        if [[ -d "${backup_name}/config" ]]; then
            mkdir -p "${PROJECT_ROOT}/config"
            cp -r "${backup_name}/config/"* "${PROJECT_ROOT}/config/" 2>/dev/null || true
        fi
        
        log_success "설정 파일 복원 완료"
    else
        log_warn "백업에 설정 파일이 없습니다"
    fi
}

# 스크립트 복원
restore_scripts() {
    local backup_file="$1"
    local backup_name=$(basename "${backup_file}" .tar.gz)
    
    log_step "스크립트 파일 복원"
    
    # 임시 디렉토리에서 스크립트 복원
    local temp_dir=$(mktemp -d)
    trap "rm -rf ${temp_dir}" EXIT
    
    cd "${temp_dir}"
    tar xzf "${backup_file}"
    
    if [[ -d "${backup_name}/scripts" ]]; then
        # 기존 scripts 디렉토리 백업
        if [[ -d "${PROJECT_ROOT}/scripts" ]]; then
            mv "${PROJECT_ROOT}/scripts" "${PROJECT_ROOT}/scripts.backup.$(date +%s)"
        fi
        
        # scripts 디렉토리 복원
        cp -r "${backup_name}/scripts" "${PROJECT_ROOT}/"
        
        # 실행 권한 부여
        find "${PROJECT_ROOT}/scripts" -name "*.sh" -exec chmod +x {} \;
        
        log_success "스크립트 파일 복원 완료"
    else
        log_warn "백업에 스크립트 파일이 없습니다"
    fi
}

# Docker 볼륨 복원
restore_docker_volumes() {
    local backup_file="$1"
    local backup_name=$(basename "${backup_file}" .tar.gz)
    
    log_step "Docker 볼륨 복원"
    
    # Docker가 실행 중인지 확인
    if ! docker info &>/dev/null; then
        log_warn "Docker가 실행되지 않습니다. 볼륨 복원을 건너뜁니다."
        return 0
    fi
    
    # 임시 디렉토리에 백업 압축 해제
    local temp_dir=$(mktemp -d)
    trap "rm -rf ${temp_dir}" EXIT
    
    cd "${temp_dir}"
    tar xzf "${backup_file}"
    
    if [[ -d "${backup_name}/volumes" ]]; then
        local volume_backups=($(find "${backup_name}/volumes" -name "*.tar.gz" -type f))
        
        if [[ ${#volume_backups[@]} -gt 0 ]]; then
            for volume_backup in "${volume_backups[@]}"; do
                local volume_name=$(basename "${volume_backup}" .tar.gz)
                
                log_info "볼륨 복원 중: ${volume_name}"
                
                # 기존 볼륨이 있으면 백업
                if docker volume inspect "${volume_name}" &>/dev/null; then
                    log_warn "기존 볼륨이 존재합니다: ${volume_name}"
                    
                    # 승인 요청
                    if ! request_destructive_approval "RESTORE_VOLUME" \
                        "기존 Docker 볼륨 '${volume_name}' 데이터를 백업 데이터로 덮어쓰기"; then
                        log_warn "볼륨 복원이 취소되었습니다: ${volume_name}"
                        continue
                    fi
                else
                    # 새 볼륨 생성
                    docker volume create "${volume_name}"
                fi
                
                # 볼륨 데이터 복원
                docker run --rm \
                    -v "${volume_name}:/target" \
                    -v "${temp_dir}/${backup_name}/volumes:/backup:ro" \
                    alpine:latest \
                    sh -c "cd /target && tar xzf /backup/$(basename "${volume_backup}")"
                
                log_success "볼륨 복원 완료: ${volume_name}"
            done
        else
            log_info "복원할 Docker 볼륨이 없습니다"
        fi
    else
        log_info "백업에 Docker 볼륨이 없습니다"
    fi
}

# 서비스 재시작
restart_services_after_restore() {
    log_step "복원 후 서비스 재시작"
    
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        cd "${PROJECT_ROOT}"
        
        # 설정 확인
        if docker-compose config &>/dev/null; then
            log_info "Docker Compose 설정 검증 완료"
            
            # 서비스 시작
            docker-compose up -d
            
            # 서비스 상태 확인
            sleep 10
            docker-compose ps
            
            log_success "서비스 재시작 완료"
        else
            log_error "Docker Compose 설정에 오류가 있습니다"
            log_error "수동으로 설정을 확인하고 서비스를 시작해주세요"
            return 1
        fi
    else
        log_warn "docker-compose.yml 파일이 없습니다"
    fi
}

# 복원 후 검증
verify_restore() {
    log_step "복원 검증"
    
    # 필수 파일 확인
    local required_files=(".env" "docker-compose.yml" "main.sh")
    for file in "${required_files[@]}"; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            log_info "필수 파일 확인: ${file}"
        else
            log_error "필수 파일 누락: ${file}"
        fi
    done
    
    # 스크립트 실행 권한 확인
    if [[ -f "${PROJECT_ROOT}/main.sh" ]] && [[ -x "${PROJECT_ROOT}/main.sh" ]]; then
        log_info "main.sh 실행 권한 확인"
    else
        log_warn "main.sh 실행 권한 설정"
        chmod +x "${PROJECT_ROOT}/main.sh"
    fi
    
    # Docker 서비스 상태 확인
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        cd "${PROJECT_ROOT}"
        local running_services=$(docker-compose ps --services --filter "status=running" | wc -l)
        local total_services=$(docker-compose ps --services | wc -l)
        
        log_info "실행 중인 서비스: ${running_services}/${total_services}"
        
        if [[ ${running_services} -eq ${total_services} ]]; then
            log_success "모든 서비스가 정상 실행 중입니다"
        else
            log_warn "일부 서비스가 실행되지 않았습니다"
        fi
    fi
    
    log_success "복원 검증 완료"
}

# 전체 복원 실행
run_full_restore() {
    local backup_file="$1"
    
    log_info "=== NAS-SubDomain-Manager 복원 시작 ==="
    log_info "복원 시작 시간: $(date '+%Y-%m-%d %H:%M:%S')"
    
    # 로그 디렉토리 생성
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    # 백업 파일 선택 및 검증
    backup_file=$(select_backup_file "${backup_file}")
    verify_backup_file "${backup_file}"
    
    # 복원 승인 요청
    if ! request_destructive_approval "FULL_SYSTEM_RESTORE" \
        "백업에서 전체 시스템 복원: $(basename "${backup_file}")"; then
        log_error "복원이 취소되었습니다."
        exit 1
    fi
    
    # 복원 실행
    backup_current_state
    stop_services_for_restore
    restore_config_files "${backup_file}"
    restore_scripts "${backup_file}"
    restore_docker_volumes "${backup_file}"
    restart_services_after_restore
    verify_restore
    
    log_success "=== 복원 완료 ==="
    log_info "복원된 백업: $(basename "${backup_file}")"
    log_info "복원 완료 시간: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "안전 백업이 생성되었습니다. 문제가 있으면 안전 백업을 사용하여 되돌릴 수 있습니다."
}

# 백업 목록 표시
list_backups() {
    log_step "백업 목록 조회"
    
    if [[ -d "${BACKUP_DIR}" ]]; then
        local backups=($(find "${BACKUP_DIR}" -name "nas_subdomain_backup_*.tar.gz" -type f | sort -r))
        
        if [[ ${#backups[@]} -gt 0 ]]; then
            echo -e "${CYAN}사용 가능한 백업 파일:${NC}"
            echo ""
            
            for backup_file in "${backups[@]}"; do
                local filename=$(basename "${backup_file}")
                local size=$(du -h "${backup_file}" | cut -f1)
                local date=$(stat -c %y "${backup_file}" 2>/dev/null || stat -f %Sm "${backup_file}" 2>/dev/null || echo "Unknown")
                
                echo -e "${WHITE}파일명:${NC} ${filename}"
                echo -e "${WHITE}크기:${NC} ${size}"
                echo -e "${WHITE}생성일:${NC} ${date}"
                echo ""
            done
        else
            log_info "백업 파일이 없습니다."
        fi
    else
        log_warn "백업 디렉토리가 존재하지 않습니다: ${BACKUP_DIR}"
    fi
}

# 백업 정보 표시
show_backup_info() {
    local backup_file="$1"
    
    if [[ -z "${backup_file}" ]]; then
        backup_file=$(select_backup_file "")
    fi
    
    if [[ -f "${backup_file}" ]]; then
        echo -e "${CYAN}백업 정보: $(basename "${backup_file}")${NC}"
        echo ""
        
        # 백업 메타데이터 표시
        if tar tzf "${backup_file}" | grep -q "backup_info.txt"; then
            tar xzf "${backup_file}" -O "*/backup_info.txt"
        else
            echo "백업 메타데이터가 없습니다."
        fi
    else
        log_error "백업 파일이 존재하지 않습니다: ${backup_file}"
    fi
}

# 메인 함수
main() {
    case "${1:-help}" in
        "restore")
            run_full_restore "${2:-}"
            ;;
        "list")
            list_backups
            ;;
        "info")
            show_backup_info "${2:-}"
            ;;
        "help"|"-h"|"--help")
            echo "사용법: $0 [restore|list|info|help] [backup_file]"
            echo ""
            echo "Commands:"
            echo "  restore [file]  - 백업에서 복원 (파일 미지정시 선택 메뉴)"
            echo "  list           - 백업 목록 조회"
            echo "  info [file]    - 백업 정보 표시"
            echo "  help           - 도움말 표시"
            echo ""
            echo "Examples:"
            echo "  $0 restore                                    # 백업 선택 후 복원"
            echo "  $0 restore backup/nas_subdomain_backup_*.tar.gz  # 특정 백업 복원"
            echo "  $0 list                                       # 백업 목록 조회"
            echo "  $0 info                                       # 백업 정보 표시"
            ;;
        *)
            log_error "알 수 없는 명령어: $1"
            echo "사용법: $0 [restore|list|info|help]"
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
