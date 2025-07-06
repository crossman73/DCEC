#!/bin/bash

# Update Script - 시스템 업데이트 스크립트
# NAS-SubDomain-Manager Docker 이미지 및 시스템 업데이트

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
readonly LOG_FILE="${PROJECT_ROOT}/logs/update.log"

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

log_header() {
    echo -e "${CYAN}===============================================${NC}"
    echo -e "${WHITE}  $1${NC}"
    echo -e "${CYAN}===============================================${NC}"
}

# 업데이트 전 백업
create_update_backup() {
    log_step "업데이트 전 자동 백업 생성"
    
    local backup_script="${PROJECT_ROOT}/scripts/maintenance/backup.sh"
    
    if [[ -f "${backup_script}" ]]; then
        log_info "백업 스크립트 실행 중..."
        "${backup_script}" backup
        log_success "업데이트 전 백업 완료"
    else
        log_warn "백업 스크립트를 찾을 수 없습니다: ${backup_script}"
        
        if ! request_approval_safe "CONTINUE_WITHOUT_BACKUP" \
            "백업 없이 업데이트 계속 진행" \
            "high" \
            "CONTINUE_WITHOUT_BACKUP"; then
            log_error "백업 없이 업데이트를 진행할 수 없습니다."
            exit 1
        fi
    fi
}

# 현재 이미지 버전 확인
check_current_images() {
    log_step "현재 Docker 이미지 버전 확인"
    
    if ! docker info &>/dev/null; then
        log_error "Docker가 실행되지 않습니다."
        exit 1
    fi
    
    if [[ ! -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        log_error "docker-compose.yml 파일이 없습니다."
        exit 1
    fi
    
    cd "${PROJECT_ROOT}"
    
    echo -e "${WHITE}현재 사용 중인 이미지:${NC}"
    docker-compose images 2>/dev/null || true
    echo ""
    
    # 각 서비스별 이미지 태그 확인
    local services=($(docker-compose config --services 2>/dev/null || echo ""))
    
    if [[ ${#services[@]} -gt 0 ]]; then
        echo -e "${WHITE}서비스별 이미지 상세:${NC}"
        for service in "${services[@]}"; do
            local image=$(docker-compose config | grep -A5 "^  ${service}:" | grep "image:" | awk '{print $2}' || echo "Unknown")
            echo -e "  ${WHITE}${service}:${NC} ${image}"
        done
        echo ""
    fi
}

# 사용 가능한 업데이트 확인
check_available_updates() {
    log_step "사용 가능한 업데이트 확인"
    
    cd "${PROJECT_ROOT}"
    
    # docker-compose에서 사용하는 이미지 목록 추출
    local images=($(docker-compose config | grep "image:" | awk '{print $2}' | sort -u || echo ""))
    
    if [[ ${#images[@]} -eq 0 ]]; then
        log_warn "업데이트할 이미지가 없습니다."
        return 1
    fi
    
    log_info "업데이트 가능한 이미지 확인 중..."
    
    local updates_available=false
    local update_list=()
    
    for image in "${images[@]}"; do
        if [[ -n "${image}" ]]; then
            log_info "이미지 확인 중: ${image}"
            
            # 현재 로컬 이미지 ID
            local local_id=$(docker images --format "{{.ID}}" "${image}" 2>/dev/null | head -1 || echo "")
            
            if [[ -n "${local_id}" ]]; then
                # 원격 이미지 pull (최신 버전 확인)
                log_info "원격 이미지 확인: ${image}"
                if docker pull "${image}" &>/dev/null; then
                    # pull 후 이미지 ID
                    local new_id=$(docker images --format "{{.ID}}" "${image}" 2>/dev/null | head -1 || echo "")
                    
                    if [[ "${local_id}" != "${new_id}" ]]; then
                        log_info "업데이트 사용 가능: ${image}"
                        updates_available=true
                        update_list+=("${image}")
                    else
                        log_info "최신 버전: ${image}"
                    fi
                else
                    log_warn "이미지를 가져올 수 없습니다: ${image}"
                fi
            else
                log_warn "로컬 이미지를 찾을 수 없습니다: ${image}"
                # 이미지가 없는 경우 pull
                if docker pull "${image}" &>/dev/null; then
                    log_info "새 이미지 다운로드: ${image}"
                    updates_available=true
                    update_list+=("${image}")
                fi
            fi
        fi
    done
    
    if [[ "${updates_available}" == "true" ]]; then
        log_success "업데이트 가능한 이미지: ${#update_list[@]}개"
        echo -e "${WHITE}업데이트할 이미지:${NC}"
        for update_image in "${update_list[@]}"; do
            echo -e "  ${GREEN}●${NC} ${update_image}"
        done
        echo ""
        return 0
    else
        log_info "모든 이미지가 최신 버전입니다."
        return 1
    fi
}

# Docker 이미지 업데이트
update_docker_images() {
    log_step "Docker 이미지 업데이트"
    
    cd "${PROJECT_ROOT}"
    
    # 서비스 중지
    log_info "서비스 중지 중..."
    if docker-compose ps -q | grep -q .; then
        docker-compose down
        log_info "서비스 중지 완료"
    else
        log_info "실행 중인 서비스가 없습니다"
    fi
    
    # 이미지 업데이트
    log_info "Docker 이미지 pull 중..."
    if docker-compose pull; then
        log_success "Docker 이미지 업데이트 완료"
    else
        log_error "Docker 이미지 업데이트 실패"
        return 1
    fi
    
    # 서비스 재시작
    log_info "서비스 재시작 중..."
    if docker-compose up -d; then
        log_success "서비스 재시작 완료"
        
        # 서비스 상태 확인
        sleep 10
        log_info "서비스 상태 확인..."
        docker-compose ps
        
        # 헬스체크 실행
        local healthy_services=0
        local total_services=0
        
        local services=($(docker-compose config --services 2>/dev/null || echo ""))
        for service in "${services[@]}"; do
            ((total_services++))
            local container_id=$(docker-compose ps -q "${service}" 2>/dev/null || echo "")
            if [[ -n "${container_id}" ]]; then
                local status=$(docker inspect --format '{{.State.Status}}' "${container_id}" 2>/dev/null || echo "unknown")
                if [[ "${status}" == "running" ]]; then
                    ((healthy_services++))
                fi
            fi
        done
        
        log_info "실행 중인 서비스: ${healthy_services}/${total_services}"
        
        if [[ ${healthy_services} -eq ${total_services} ]]; then
            log_success "모든 서비스가 정상적으로 실행되고 있습니다"
        else
            log_warn "일부 서비스가 실행되지 않았습니다. 로그를 확인해주세요."
        fi
    else
        log_error "서비스 재시작 실패"
        return 1
    fi
}

# 시스템 설정 업데이트
update_system_config() {
    log_step "시스템 설정 업데이트"
    
    # Git에서 최신 설정 가져오기 (옵션)
    if [[ -d "${PROJECT_ROOT}/.git" ]]; then
        log_info "Git 저장소에서 최신 변경사항 확인..."
        
        cd "${PROJECT_ROOT}"
        
        # 현재 브랜치 확인
        local current_branch=$(git branch --show-current 2>/dev/null || echo "main")
        log_info "현재 브랜치: ${current_branch}"
        
        # 원격 변경사항 확인
        if git fetch origin "${current_branch}" &>/dev/null; then
            local local_commit=$(git rev-parse HEAD)
            local remote_commit=$(git rev-parse "origin/${current_branch}")
            
            if [[ "${local_commit}" != "${remote_commit}" ]]; then
                log_info "원격 저장소에 새로운 변경사항이 있습니다"
                
                if request_approval_safe "UPDATE_FROM_GIT" \
                    "Git 저장소에서 최신 설정 가져오기" \
                    "medium" \
                    "git_update"; then
                    
                    # 로컬 변경사항 stash
                    if ! git diff --quiet; then
                        log_info "로컬 변경사항을 임시 저장합니다"
                        git stash push -m "Update backup $(date '+%Y-%m-%d %H:%M:%S')"
                    fi
                    
                    # 최신 변경사항 pull
                    if git pull origin "${current_branch}"; then
                        log_success "Git 업데이트 완료"
                        
                        # 스크립트 실행 권한 부여
                        find "${PROJECT_ROOT}/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
                        chmod +x "${PROJECT_ROOT}/main.sh" 2>/dev/null || true
                        
                    else
                        log_error "Git 업데이트 실패"
                        return 1
                    fi
                else
                    log_info "Git 업데이트가 취소되었습니다"
                fi
            else
                log_info "로컬이 최신 상태입니다"
            fi
        else
            log_warn "원격 저장소에 연결할 수 없습니다"
        fi
    else
        log_info "Git 저장소가 아닙니다. 설정 업데이트를 건너뜁니다."
    fi
}

# 스크립트 권한 업데이트
update_script_permissions() {
    log_step "스크립트 실행 권한 업데이트"
    
    # main.sh 권한
    if [[ -f "${PROJECT_ROOT}/main.sh" ]]; then
        chmod +x "${PROJECT_ROOT}/main.sh"
        log_info "main.sh 실행 권한 설정"
    fi
    
    # scripts 디렉토리의 모든 .sh 파일 권한
    if [[ -d "${PROJECT_ROOT}/scripts" ]]; then
        find "${PROJECT_ROOT}/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
        local script_count=$(find "${PROJECT_ROOT}/scripts" -name "*.sh" | wc -l)
        log_info "스크립트 파일 ${script_count}개의 실행 권한 설정"
    fi
    
    log_success "스크립트 권한 업데이트 완료"
}

# 사용하지 않는 이미지 정리
cleanup_old_images() {
    log_step "사용하지 않는 구 버전 이미지 정리"
    
    # 댕글링 이미지 (업데이트로 인해 생성된)
    local dangling_images=$(docker images -f "dangling=true" -q 2>/dev/null || echo "")
    
    if [[ -n "${dangling_images}" ]]; then
        local dangling_count=$(echo "${dangling_images}" | wc -l)
        log_info "정리할 구 버전 이미지: ${dangling_count}개"
        
        if request_approval_safe "CLEANUP_OLD_IMAGES" \
            "업데이트로 생성된 구 버전 이미지 ${dangling_count}개 정리" \
            "low" \
            "cleanup"; then
            
            echo "${dangling_images}" | xargs docker rmi 2>/dev/null || true
            log_success "구 버전 이미지 정리 완료"
        else
            log_info "이미지 정리가 취소되었습니다"
        fi
    else
        log_info "정리할 구 버전 이미지가 없습니다"
    fi
}

# 업데이트 후 검증
verify_update() {
    log_step "업데이트 후 시스템 검증"
    
    cd "${PROJECT_ROOT}"
    
    # Docker Compose 설정 검증
    if docker-compose config &>/dev/null; then
        log_success "Docker Compose 설정 유효"
    else
        log_error "Docker Compose 설정에 오류가 있습니다"
        return 1
    fi
    
    # 서비스 상태 검증
    local services=($(docker-compose config --services 2>/dev/null || echo ""))
    local running_services=0
    
    for service in "${services[@]}"; do
        local container_id=$(docker-compose ps -q "${service}" 2>/dev/null || echo "")
        if [[ -n "${container_id}" ]]; then
            local status=$(docker inspect --format '{{.State.Status}}' "${container_id}" 2>/dev/null || echo "unknown")
            if [[ "${status}" == "running" ]]; then
                ((running_services++))
                log_info "서비스 실행 중: ${service}"
            else
                log_warn "서비스 문제 발견: ${service} (${status})"
            fi
        else
            log_warn "컨테이너를 찾을 수 없습니다: ${service}"
        fi
    done
    
    if [[ ${running_services} -eq ${#services[@]} ]]; then
        log_success "모든 서비스가 정상 실행 중입니다"
    else
        log_warn "일부 서비스에 문제가 있습니다 (${running_services}/${#services[@]} 실행 중)"
    fi
    
    # 업데이트된 이미지 버전 표시
    echo ""
    echo -e "${WHITE}업데이트된 이미지 버전:${NC}"
    docker-compose images 2>/dev/null || true
    
    log_success "시스템 검증 완료"
}

# 전체 업데이트
full_update() {
    log_header "전체 시스템 업데이트"
    
    # 업데이트 승인
    if ! request_service_interruption_approval "FULL_SYSTEM_UPDATE" \
        "Docker 이미지 업데이트 및 서비스 재시작 - 약 5-10분간 서비스 중단" \
        "모든 웹 서비스"; then
        log_error "업데이트가 취소되었습니다."
        exit 1
    fi
    
    create_update_backup
    check_current_images
    
    if check_available_updates; then
        update_docker_images
        update_system_config
        update_script_permissions
        cleanup_old_images
        verify_update
        
        log_success "전체 업데이트 완료!"
    else
        log_info "업데이트할 항목이 없습니다."
    fi
}

# 이미지만 업데이트
images_only_update() {
    log_header "Docker 이미지만 업데이트"
    
    if ! request_service_interruption_approval "IMAGES_ONLY_UPDATE" \
        "Docker 이미지만 업데이트 및 서비스 재시작" \
        "모든 웹 서비스"; then
        log_error "업데이트가 취소되었습니다."
        exit 1
    fi
    
    check_current_images
    
    if check_available_updates; then
        update_docker_images
        cleanup_old_images
        verify_update
        
        log_success "Docker 이미지 업데이트 완료!"
    else
        log_info "업데이트할 이미지가 없습니다."
    fi
}

# 설정만 업데이트
config_only_update() {
    log_header "시스템 설정만 업데이트"
    
    if ! request_approval_safe "CONFIG_ONLY_UPDATE" \
        "시스템 설정 및 스크립트 업데이트 (서비스 중단 없음)" \
        "low" \
        "config_update"; then
        log_error "설정 업데이트가 취소되었습니다."
        exit 1
    fi
    
    update_system_config
    update_script_permissions
    
    log_success "설정 업데이트 완료!"
}

# 업데이트 확인만
check_only() {
    log_header "업데이트 확인"
    
    check_current_images
    check_available_updates
    
    log_info "업데이트 확인 완료"
}

# 메인 함수
main() {
    # 로그 디렉토리 생성
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    log_info "=== NAS-SubDomain-Manager 업데이트 시작 ==="
    log_info "업데이트 시작 시간: $(date '+%Y-%m-%d %H:%M:%S')"
    
    case "${1:-full}" in
        "full"|"f")
            full_update
            ;;
        "images"|"i")
            images_only_update
            ;;
        "config"|"c")
            config_only_update
            ;;
        "check"|"status")
            check_only
            ;;
        "help"|"-h"|"--help")
            echo "사용법: $0 [옵션]"
            echo ""
            echo "옵션:"
            echo "  full, f      - 전체 업데이트 (기본값)"
            echo "  images, i    - Docker 이미지만 업데이트"
            echo "  config, c    - 설정 파일만 업데이트"
            echo "  check        - 업데이트 확인만"
            echo "  help         - 도움말 표시"
            echo ""
            echo "업데이트 순서:"
            echo "  1. 업데이트 전 백업 생성"
            echo "  2. 현재 이미지 버전 확인"
            echo "  3. 사용 가능한 업데이트 확인"
            echo "  4. Docker 이미지 업데이트"
            echo "  5. 시스템 설정 업데이트"
            echo "  6. 스크립트 권한 업데이트"
            echo "  7. 구 버전 이미지 정리"
            echo "  8. 업데이트 후 검증"
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            echo "사용법: $0 [full|images|config|check|help]"
            exit 1
            ;;
    esac
    
    log_info "=== 업데이트 완료 ==="
    log_info "업데이트 완료 시간: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 스크립트 실행
main "$@"
