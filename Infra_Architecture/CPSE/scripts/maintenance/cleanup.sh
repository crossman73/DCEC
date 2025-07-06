#!/bin/bash

# Cleanup Script - 시스템 정리 스크립트
# NAS-SubDomain-Manager 시스템 정리 및 최적화

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
readonly LOG_FILE="${PROJECT_ROOT}/logs/cleanup.log"

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

# 정리 전 상태 확인
check_cleanup_status() {
    log_header "정리 전 상태 확인"
    
    # Docker 상태 확인
    if ! docker info &>/dev/null; then
        log_warn "Docker가 실행되지 않습니다. Docker 관련 정리는 건너뜁니다."
        return 1
    fi
    
    # 디스크 사용량 확인
    local disk_usage_before=$(df -h / | tail -1 | awk '{print $3}')
    echo -e "${WHITE}현재 디스크 사용량:${NC} ${disk_usage_before}"
    
    # Docker 리소스 현황
    local containers_total=$(docker ps -aq | wc -l)
    local images_total=$(docker images -q | wc -l)
    local volumes_total=$(docker volume ls -q | wc -l)
    local networks_total=$(docker network ls -q | wc -l)
    
    echo -e "${WHITE}Docker 리소스 현황:${NC}"
    echo -e "  컨테이너: ${containers_total}개"
    echo -e "  이미지: ${images_total}개"
    echo -e "  볼륨: ${volumes_total}개"
    echo -e "  네트워크: ${networks_total}개"
    
    echo ""
    return 0
}

# 중지된 컨테이너 정리
cleanup_stopped_containers() {
    log_step "중지된 컨테이너 정리"
    
    local stopped_containers=$(docker ps -aq --filter "status=exited" --filter "status=dead" 2>/dev/null || echo "")
    
    if [[ -n "${stopped_containers}" ]]; then
        local container_count=$(echo "${stopped_containers}" | wc -l)
        log_info "중지된 컨테이너 ${container_count}개 발견"
        
        # 컨테이너 목록 표시
        echo -e "${WHITE}정리할 컨테이너:${NC}"
        docker ps -a --filter "status=exited" --filter "status=dead" --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" 2>/dev/null || true
        echo ""
        
        if request_approval_safe "REMOVE_STOPPED_CONTAINERS" \
            "중지된 컨테이너 ${container_count}개 삭제" \
            "low" \
            "cleanup"; then
            
            echo "${stopped_containers}" | xargs docker rm 2>/dev/null || true
            log_success "중지된 컨테이너 정리 완료"
        else
            log_info "중지된 컨테이너 정리가 취소되었습니다"
        fi
    else
        log_info "정리할 중지된 컨테이너가 없습니다"
    fi
}

# 사용하지 않는 이미지 정리
cleanup_unused_images() {
    log_step "사용하지 않는 이미지 정리"
    
    # 댕글링 이미지 (태그가 없는 이미지)
    local dangling_images=$(docker images -f "dangling=true" -q 2>/dev/null || echo "")
    
    if [[ -n "${dangling_images}" ]]; then
        local dangling_count=$(echo "${dangling_images}" | wc -l)
        log_info "댕글링 이미지 ${dangling_count}개 발견"
        
        if request_approval_safe "REMOVE_DANGLING_IMAGES" \
            "댕글링 이미지 ${dangling_count}개 삭제 (태그가 없는 이미지)" \
            "low" \
            "cleanup"; then
            
            echo "${dangling_images}" | xargs docker rmi 2>/dev/null || true
            log_success "댕글링 이미지 정리 완료"
        else
            log_info "댕글링 이미지 정리가 취소되었습니다"
        fi
    else
        log_info "정리할 댕글링 이미지가 없습니다"
    fi
    
    # 사용하지 않는 이미지 (더 공격적인 정리)
    local unused_images=$(docker images --filter "dangling=false" --format "{{.ID}}" | while read -r image_id; do
        if ! docker ps -a --format "{{.Image}}" | grep -q "${image_id}"; then
            echo "${image_id}"
        fi
    done 2>/dev/null || echo "")
    
    if [[ -n "${unused_images}" ]]; then
        local unused_count=$(echo "${unused_images}" | wc -l)
        log_info "사용하지 않는 이미지 ${unused_count}개 발견"
        
        echo -e "${WHITE}사용하지 않는 이미지:${NC}"
        echo "${unused_images}" | while read -r image_id; do
            if [[ -n "${image_id}" ]]; then
                docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" --filter "dangling=false" | grep "${image_id}" 2>/dev/null || true
            fi
        done
        echo ""
        
        if request_approval_safe "REMOVE_UNUSED_IMAGES" \
            "사용하지 않는 이미지 ${unused_count}개 삭제" \
            "medium" \
            "REMOVE_UNUSED_IMAGES"; then
            
            echo "${unused_images}" | xargs docker rmi 2>/dev/null || true
            log_success "사용하지 않는 이미지 정리 완료"
        else
            log_info "사용하지 않는 이미지 정리가 취소되었습니다"
        fi
    else
        log_info "정리할 사용하지 않는 이미지가 없습니다"
    fi
}

# 사용하지 않는 볼륨 정리
cleanup_unused_volumes() {
    log_step "사용하지 않는 볼륨 정리"
    
    local unused_volumes=$(docker volume ls -f "dangling=true" -q 2>/dev/null || echo "")
    
    if [[ -n "${unused_volumes}" ]]; then
        local volume_count=$(echo "${unused_volumes}" | wc -l)
        log_info "사용하지 않는 볼륨 ${volume_count}개 발견"
        
        echo -e "${WHITE}정리할 볼륨:${NC}"
        echo "${unused_volumes}" | while read -r volume_name; do
            if [[ -n "${volume_name}" ]]; then
                local volume_info=$(docker volume inspect "${volume_name}" --format "{{.Name}} ({{.Driver}})" 2>/dev/null || echo "${volume_name}")
                echo "  ${volume_info}"
            fi
        done
        echo ""
        
        if request_destructive_approval "REMOVE_UNUSED_VOLUMES" \
            "사용하지 않는 볼륨 ${volume_count}개 삭제 (데이터 손실 가능)"; then
            
            echo "${unused_volumes}" | xargs docker volume rm 2>/dev/null || true
            log_success "사용하지 않는 볼륨 정리 완료"
        else
            log_info "사용하지 않는 볼륨 정리가 취소되었습니다"
        fi
    else
        log_info "정리할 사용하지 않는 볼륨이 없습니다"
    fi
}

# 사용하지 않는 네트워크 정리
cleanup_unused_networks() {
    log_step "사용하지 않는 네트워크 정리"
    
    # 기본 네트워크는 제외하고 사용자 정의 네트워크만 확인
    local unused_networks=$(docker network ls --filter "type=custom" --format "{{.ID}}" | while read -r network_id; do
        if [[ -n "${network_id}" ]]; then
            local connected_containers=$(docker network inspect "${network_id}" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
            if [[ -z "${connected_containers// }" ]]; then
                echo "${network_id}"
            fi
        fi
    done 2>/dev/null || echo "")
    
    if [[ -n "${unused_networks}" ]]; then
        local network_count=$(echo "${unused_networks}" | wc -l)
        log_info "사용하지 않는 네트워크 ${network_count}개 발견"
        
        echo -e "${WHITE}정리할 네트워크:${NC}"
        echo "${unused_networks}" | while read -r network_id; do
            if [[ -n "${network_id}" ]]; then
                local network_info=$(docker network inspect "${network_id}" --format "{{.Name}} ({{.Driver}})" 2>/dev/null || echo "${network_id}")
                echo "  ${network_info}"
            fi
        done
        echo ""
        
        if request_approval_safe "REMOVE_UNUSED_NETWORKS" \
            "사용하지 않는 네트워크 ${network_count}개 삭제" \
            "low" \
            "cleanup"; then
            
            echo "${unused_networks}" | xargs docker network rm 2>/dev/null || true
            log_success "사용하지 않는 네트워크 정리 완료"
        else
            log_info "사용하지 않는 네트워크 정리가 취소되었습니다"
        fi
    else
        log_info "정리할 사용하지 않는 네트워크가 없습니다"
    fi
}

# 로그 파일 정리
cleanup_log_files() {
    log_step "로그 파일 정리"
    
    local log_dirs=("${PROJECT_ROOT}/logs")
    local days_to_keep="${LOG_RETENTION_DAYS:-30}"
    
    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "${log_dir}" ]]; then
            log_info "로그 디렉토리 정리: ${log_dir}"
            
            # 오래된 로그 파일 찾기
            local old_logs=$(find "${log_dir}" -name "*.log" -type f -mtime +${days_to_keep} 2>/dev/null || echo "")
            
            if [[ -n "${old_logs}" ]]; then
                local log_count=$(echo "${old_logs}" | wc -l)
                local total_size=$(echo "${old_logs}" | xargs du -ch 2>/dev/null | tail -1 | cut -f1 || echo "Unknown")
                
                log_info "${days_to_keep}일 이상 된 로그 파일 ${log_count}개 발견 (총 크기: ${total_size})"
                
                echo -e "${WHITE}정리할 로그 파일:${NC}"
                echo "${old_logs}" | head -10 | while read -r log_file; do
                    if [[ -n "${log_file}" ]]; then
                        local file_date=$(stat -c %y "${log_file}" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
                        local file_size=$(du -h "${log_file}" 2>/dev/null | cut -f1 || echo "Unknown")
                        echo "  $(basename "${log_file}") (${file_size}, ${file_date})"
                    fi
                done
                if [[ ${log_count} -gt 10 ]]; then
                    echo "  ... 그리고 $((log_count - 10))개 더"
                fi
                echo ""
                
                if request_approval_safe "CLEANUP_OLD_LOGS" \
                    "${days_to_keep}일 이상 된 로그 파일 ${log_count}개 삭제" \
                    "low" \
                    "cleanup"; then
                    
                    echo "${old_logs}" | xargs rm -f 2>/dev/null || true
                    log_success "오래된 로그 파일 정리 완료"
                else
                    log_info "로그 파일 정리가 취소되었습니다"
                fi
            else
                log_info "${days_to_keep}일 이상 된 로그 파일이 없습니다"
            fi
            
            # 빈 로그 파일 정리
            local empty_logs=$(find "${log_dir}" -name "*.log" -type f -empty 2>/dev/null || echo "")
            if [[ -n "${empty_logs}" ]]; then
                local empty_count=$(echo "${empty_logs}" | wc -l)
                log_info "빈 로그 파일 ${empty_count}개 발견"
                
                if request_approval_safe "CLEANUP_EMPTY_LOGS" \
                    "빈 로그 파일 ${empty_count}개 삭제" \
                    "low" \
                    "cleanup"; then
                    
                    echo "${empty_logs}" | xargs rm -f 2>/dev/null || true
                    log_success "빈 로그 파일 정리 완료"
                fi
            fi
        fi
    done
}

# 임시 파일 정리
cleanup_temp_files() {
    log_step "임시 파일 정리"
    
    local temp_patterns=(
        "${PROJECT_ROOT}/*.tmp"
        "${PROJECT_ROOT}/*.temp"
        "${PROJECT_ROOT}/.*.swp"
        "${PROJECT_ROOT}/*~"
        "${PROJECT_ROOT}/*.backup.*"
    )
    
    local temp_files=()
    for pattern in "${temp_patterns[@]}"; do
        local found_files=($(ls ${pattern} 2>/dev/null || echo ""))
        for file in "${found_files[@]}"; do
            if [[ -f "${file}" ]]; then
                temp_files+=("${file}")
            fi
        done
    done
    
    if [[ ${#temp_files[@]} -gt 0 ]]; then
        log_info "임시 파일 ${#temp_files[@]}개 발견"
        
        echo -e "${WHITE}정리할 임시 파일:${NC}"
        for file in "${temp_files[@]}"; do
            local file_size=$(du -h "${file}" 2>/dev/null | cut -f1 || echo "Unknown")
            echo "  $(basename "${file}") (${file_size})"
        done
        echo ""
        
        if request_approval_safe "CLEANUP_TEMP_FILES" \
            "임시 파일 ${#temp_files[@]}개 삭제" \
            "low" \
            "cleanup"; then
            
            rm -f "${temp_files[@]}" 2>/dev/null || true
            log_success "임시 파일 정리 완료"
        else
            log_info "임시 파일 정리가 취소되었습니다"
        fi
    else
        log_info "정리할 임시 파일이 없습니다"
    fi
}

# 오래된 백업 정리
cleanup_old_backups() {
    log_step "오래된 백업 정리"
    
    local backup_dir="${PROJECT_ROOT}/backup"
    local days_to_keep="${BACKUP_RETENTION_DAYS:-7}"
    
    if [[ -d "${backup_dir}" ]]; then
        local old_backups=$(find "${backup_dir}" -name "*.tar.gz" -type f -mtime +${days_to_keep} 2>/dev/null || echo "")
        
        if [[ -n "${old_backups}" ]]; then
            local backup_count=$(echo "${old_backups}" | wc -l)
            local total_size=$(echo "${old_backups}" | xargs du -ch 2>/dev/null | tail -1 | cut -f1 || echo "Unknown")
            
            log_info "${days_to_keep}일 이상 된 백업 파일 ${backup_count}개 발견 (총 크기: ${total_size})"
            
            echo -e "${WHITE}정리할 백업 파일:${NC}"
            echo "${old_backups}" | while read -r backup_file; do
                if [[ -n "${backup_file}" ]]; then
                    local file_date=$(stat -c %y "${backup_file}" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
                    local file_size=$(du -h "${backup_file}" 2>/dev/null | cut -f1 || echo "Unknown")
                    echo "  $(basename "${backup_file}") (${file_size}, ${file_date})"
                fi
            done
            echo ""
            
            if request_approval_safe "CLEANUP_OLD_BACKUPS" \
                "${days_to_keep}일 이상 된 백업 파일 ${backup_count}개 삭제" \
                "medium" \
                "CLEANUP_BACKUPS"; then
                
                echo "${old_backups}" | xargs rm -f 2>/dev/null || true
                log_success "오래된 백업 파일 정리 완료"
            else
                log_info "백업 파일 정리가 취소되었습니다"
            fi
        else
            log_info "${days_to_keep}일 이상 된 백업 파일이 없습니다"
        fi
    else
        log_info "백업 디렉토리가 없습니다: ${backup_dir}"
    fi
}

# Docker 시스템 정리 (전체)
docker_system_prune() {
    log_step "Docker 시스템 전체 정리"
    
    if request_destructive_approval "DOCKER_SYSTEM_PRUNE" \
        "Docker 시스템 전체 정리 (모든 사용하지 않는 리소스 삭제)"; then
        
        log_info "Docker 시스템 정리 실행 중..."
        
        # --all 플래그로 사용하지 않는 이미지까지 모두 정리
        docker system prune -af --volumes 2>/dev/null || true
        
        log_success "Docker 시스템 전체 정리 완료"
    else
        log_info "Docker 시스템 정리가 취소되었습니다"
    fi
}

# 정리 후 상태 확인
check_cleanup_results() {
    log_header "정리 후 상태 확인"
    
    if docker info &>/dev/null; then
        # 디스크 사용량 확인
        local disk_usage_after=$(df -h / | tail -1 | awk '{print $3}')
        echo -e "${WHITE}정리 후 디스크 사용량:${NC} ${disk_usage_after}"
        
        # Docker 리소스 현황
        local containers_total=$(docker ps -aq | wc -l)
        local images_total=$(docker images -q | wc -l)
        local volumes_total=$(docker volume ls -q | wc -l)
        local networks_total=$(docker network ls -q | wc -l)
        
        echo -e "${WHITE}정리 후 Docker 리소스:${NC}"
        echo -e "  컨테이너: ${containers_total}개"
        echo -e "  이미지: ${images_total}개"
        echo -e "  볼륨: ${volumes_total}개"
        echo -e "  네트워크: ${networks_total}개"
    fi
    
    echo ""
}

# 빠른 정리 (안전한 항목만)
quick_cleanup() {
    log_header "빠른 정리 (안전한 항목만)"
    
    if check_cleanup_status; then
        cleanup_stopped_containers
        cleanup_temp_files
        cleanup_log_files
        check_cleanup_results
    fi
    
    log_success "빠른 정리 완료"
}

# 전체 정리
full_cleanup() {
    log_header "전체 시스템 정리"
    
    if check_cleanup_status; then
        cleanup_stopped_containers
        cleanup_unused_images
        cleanup_unused_volumes
        cleanup_unused_networks
        cleanup_log_files
        cleanup_temp_files
        cleanup_old_backups
        check_cleanup_results
    fi
    
    log_success "전체 정리 완료"
}

# 공격적 정리 (모든 항목)
aggressive_cleanup() {
    log_header "공격적 정리 (모든 항목)"
    
    echo -e "${RED}⚠️  공격적 정리는 많은 데이터를 삭제할 수 있습니다.${NC}"
    echo -e "${RED}⚠️  계속하기 전에 중요한 데이터를 백업했는지 확인하세요.${NC}"
    echo ""
    
    if check_cleanup_status; then
        cleanup_stopped_containers
        cleanup_unused_images
        cleanup_unused_volumes
        cleanup_unused_networks
        cleanup_log_files
        cleanup_temp_files
        cleanup_old_backups
        docker_system_prune
        check_cleanup_results
    fi
    
    log_success "공격적 정리 완료"
}

# 메인 함수
main() {
    # 로그 디렉토리 생성
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    log_info "=== NAS-SubDomain-Manager 정리 시작 ==="
    log_info "정리 시작 시간: $(date '+%Y-%m-%d %H:%M:%S')"
    
    case "${1:-full}" in
        "quick"|"q")
            quick_cleanup
            ;;
        "full"|"f")
            full_cleanup
            ;;
        "aggressive"|"a")
            aggressive_cleanup
            ;;
        "docker"|"d")
            if check_cleanup_status; then
                docker_system_prune
                check_cleanup_results
            fi
            ;;
        "logs"|"l")
            cleanup_log_files
            ;;
        "backups"|"b")
            cleanup_old_backups
            ;;
        "temp"|"t")
            cleanup_temp_files
            ;;
        "help"|"-h"|"--help")
            echo "사용법: $0 [옵션]"
            echo ""
            echo "옵션:"
            echo "  full, f        - 전체 정리 (기본값)"
            echo "  quick, q       - 빠른 정리 (안전한 항목만)"
            echo "  aggressive, a  - 공격적 정리 (모든 항목)"
            echo "  docker, d      - Docker 시스템 정리만"
            echo "  logs, l        - 로그 파일 정리만"
            echo "  backups, b     - 백업 파일 정리만"
            echo "  temp, t        - 임시 파일 정리만"
            echo "  help           - 도움말 표시"
            echo ""
            echo "환경 변수:"
            echo "  LOG_RETENTION_DAYS    - 로그 보관 기간 (기본: 30일)"
            echo "  BACKUP_RETENTION_DAYS - 백업 보관 기간 (기본: 7일)"
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            echo "사용법: $0 [full|quick|aggressive|docker|logs|backups|temp|help]"
            exit 1
            ;;
    esac
    
    log_info "=== 정리 완료 ==="
    log_info "정리 완료 시간: $(date '+%Y-%m-%d %H:%M:%S')"
}

# 스크립트 실행
main "$@"
