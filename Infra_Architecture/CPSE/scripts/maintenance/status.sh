#!/bin/bash

# Status Check Script - 시스템 상태 확인 스크립트
# NAS-SubDomain-Manager 상태 모니터링

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
readonly LOG_FILE="${PROJECT_ROOT}/logs/status.log"

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

# 상태 아이콘 함수
status_icon() {
    local status="$1"
    case "${status}" in
        "running"|"healthy"|"up"|"active") echo -e "${GREEN}●${NC}" ;;
        "exited"|"unhealthy"|"down"|"inactive") echo -e "${RED}●${NC}" ;;
        "restarting"|"starting") echo -e "${YELLOW}●${NC}" ;;
        *) echo -e "${WHITE}○${NC}" ;;
    esac
}

# 시스템 정보 확인
check_system_info() {
    log_header "시스템 정보"
    
    echo -e "${WHITE}호스트명:${NC} $(hostname)"
    echo -e "${WHITE}운영체제:${NC} $(uname -o 2>/dev/null || uname -s)"
    echo -e "${WHITE}커널:${NC} $(uname -r)"
    echo -e "${WHITE}아키텍처:${NC} $(uname -m)"
    echo -e "${WHITE}현재 시간:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${WHITE}실행 사용자:${NC} $(whoami)"
    echo -e "${WHITE}시스템 가동시간:${NC} $(uptime | cut -d',' -f1 | cut -d' ' -f4-)"
    
    # 메모리 사용량
    if command -v free &>/dev/null; then
        local mem_info=$(free -h | grep "Mem:")
        local mem_used=$(echo "${mem_info}" | awk '{print $3}')
        local mem_total=$(echo "${mem_info}" | awk '{print $2}')
        echo -e "${WHITE}메모리 사용량:${NC} ${mem_used}/${mem_total}"
    fi
    
    # 디스크 사용량
    if command -v df &>/dev/null; then
        local disk_usage=$(df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}')
        echo -e "${WHITE}디스크 사용량:${NC} ${disk_usage}"
    fi
    
    echo ""
}

# Docker 상태 확인
check_docker_status() {
    log_header "Docker 상태"
    
    # Docker 서비스 상태
    if command -v docker &>/dev/null; then
        if docker info &>/dev/null; then
            echo -e "$(status_icon "running") ${WHITE}Docker 서비스:${NC} ${GREEN}실행 중${NC}"
            
            local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
            echo -e "${WHITE}Docker 버전:${NC} ${docker_version}"
            
            # Docker 리소스 사용량
            local containers_running=$(docker ps -q | wc -l)
            local containers_total=$(docker ps -aq | wc -l)
            echo -e "${WHITE}컨테이너:${NC} 실행 중 ${containers_running}개, 전체 ${containers_total}개"
            
            local images_count=$(docker images -q | wc -l)
            echo -e "${WHITE}이미지:${NC} ${images_count}개"
            
            local volumes_count=$(docker volume ls -q | wc -l)
            echo -e "${WHITE}볼륨:${NC} ${volumes_count}개"
            
        else
            echo -e "$(status_icon "down") ${WHITE}Docker 서비스:${NC} ${RED}중지됨${NC}"
            log_error "Docker 서비스가 실행되지 않습니다"
        fi
    else
        echo -e "$(status_icon "down") ${WHITE}Docker:${NC} ${RED}설치되지 않음${NC}"
        log_error "Docker가 설치되어 있지 않습니다"
    fi
    
    # Docker Compose 상태
    if command -v docker-compose &>/dev/null; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | cut -d',' -f1)
        echo -e "$(status_icon "running") ${WHITE}Docker Compose:${NC} ${GREEN}설치됨${NC} (v${compose_version})"
    else
        echo -e "$(status_icon "down") ${WHITE}Docker Compose:${NC} ${RED}설치되지 않음${NC}"
        log_warn "Docker Compose가 설치되어 있지 않습니다"
    fi
    
    echo ""
}

# 프로젝트 설정 확인
check_project_config() {
    log_header "프로젝트 설정"
    
    # 필수 파일 확인
    local config_files=(".env" "docker-compose.yml" "main.sh")
    
    for file in "${config_files[@]}"; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            echo -e "$(status_icon "up") ${WHITE}${file}:${NC} ${GREEN}존재함${NC}"
            
            # 파일 크기와 수정일
            local file_size=$(du -h "${PROJECT_ROOT}/${file}" | cut -f1)
            local file_date=$(stat -c %y "${PROJECT_ROOT}/${file}" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
            echo -e "   ${WHITE}크기:${NC} ${file_size}, ${WHITE}수정일:${NC} ${file_date}"
        else
            echo -e "$(status_icon "down") ${WHITE}${file}:${NC} ${RED}없음${NC}"
            log_error "필수 파일이 없습니다: ${file}"
        fi
    done
    
    # 스크립트 디렉토리 확인
    local script_dirs=("scripts/setup" "scripts/services" "scripts/security" "scripts/maintenance")
    
    echo ""
    echo -e "${WHITE}스크립트 디렉토리:${NC}"
    for dir in "${script_dirs[@]}"; do
        if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
            local script_count=$(find "${PROJECT_ROOT}/${dir}" -name "*.sh" | wc -l)
            echo -e "$(status_icon "up") ${WHITE}${dir}:${NC} ${GREEN}존재함${NC} (${script_count}개 스크립트)"
        else
            echo -e "$(status_icon "down") ${WHITE}${dir}:${NC} ${RED}없음${NC}"
        fi
    done
    
    echo ""
}

# 서비스 상태 확인
check_services_status() {
    log_header "서비스 상태"
    
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        cd "${PROJECT_ROOT}"
        
        # Docker Compose 설정 유효성 확인
        if docker-compose config &>/dev/null; then
            echo -e "$(status_icon "up") ${WHITE}Docker Compose 설정:${NC} ${GREEN}유효함${NC}"
        else
            echo -e "$(status_icon "down") ${WHITE}Docker Compose 설정:${NC} ${RED}오류 있음${NC}"
            log_error "Docker Compose 설정에 오류가 있습니다"
        fi
        
        # 서비스별 상태 확인
        if docker info &>/dev/null; then
            echo ""
            echo -e "${WHITE}서비스별 상태:${NC}"
            
            # 정의된 서비스 목록
            local services=($(docker-compose config --services 2>/dev/null || echo ""))
            
            if [[ ${#services[@]} -gt 0 ]]; then
                for service in "${services[@]}"; do
                    local container_id=$(docker-compose ps -q "${service}" 2>/dev/null || echo "")
                    
                    if [[ -n "${container_id}" ]]; then
                        local status=$(docker inspect --format '{{.State.Status}}' "${container_id}" 2>/dev/null || echo "unknown")
                        local health=$(docker inspect --format '{{.State.Health.Status}}' "${container_id}" 2>/dev/null || echo "")
                        
                        echo -n -e "$(status_icon "${status}") ${WHITE}${service}:${NC}"
                        
                        case "${status}" in
                            "running")
                                echo -e " ${GREEN}실행 중${NC}"
                                
                                # 헬스체크 상태
                                if [[ -n "${health}" && "${health}" != "<no value>" ]]; then
                                    case "${health}" in
                                        "healthy") echo -e "   ${GREEN}건강함${NC}" ;;
                                        "unhealthy") echo -e "   ${RED}비정상${NC}" ;;
                                        "starting") echo -e "   ${YELLOW}시작 중${NC}" ;;
                                    esac
                                fi
                                
                                # 포트 매핑 정보
                                local ports=$(docker port "${container_id}" 2>/dev/null | tr '\n' ' ' || echo "")
                                if [[ -n "${ports}" ]]; then
                                    echo -e "   ${WHITE}포트:${NC} ${ports}"
                                fi
                                ;;
                            "exited")
                                local exit_code=$(docker inspect --format '{{.State.ExitCode}}' "${container_id}" 2>/dev/null || echo "unknown")
                                echo -e " ${RED}중지됨${NC} (종료 코드: ${exit_code})"
                                ;;
                            "restarting")
                                echo -e " ${YELLOW}재시작 중${NC}"
                                ;;
                            *)
                                echo -e " ${YELLOW}${status}${NC}"
                                ;;
                        esac
                        
                        # 컨테이너 리소스 사용량
                        local cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" "${container_id}" 2>/dev/null || echo "N/A")
                        local mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "${container_id}" 2>/dev/null || echo "N/A")
                        if [[ "${cpu_usage}" != "N/A" ]]; then
                            echo -e "   ${WHITE}CPU:${NC} ${cpu_usage}, ${WHITE}메모리:${NC} ${mem_usage}"
                        fi
                        
                    else
                        echo -e "$(status_icon "down") ${WHITE}${service}:${NC} ${RED}컨테이너 없음${NC}"
                    fi
                done
            else
                log_warn "정의된 서비스가 없습니다"
            fi
        else
            log_warn "Docker가 실행되지 않아 서비스 상태를 확인할 수 없습니다"
        fi
    else
        echo -e "$(status_icon "down") ${WHITE}docker-compose.yml:${NC} ${RED}없음${NC}"
        log_error "docker-compose.yml 파일이 없습니다"
    fi
    
    echo ""
}

# 네트워크 상태 확인
check_network_status() {
    log_header "네트워크 상태"
    
    # 프로젝트 네트워크 확인
    if docker info &>/dev/null; then
        local project_name=$(basename "${PROJECT_ROOT}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]_-')
        local networks=$(docker network ls --format "{{.Name}}" | grep "${project_name}" || echo "")
        
        if [[ -n "${networks}" ]]; then
            echo -e "${WHITE}프로젝트 네트워크:${NC}"
            while IFS= read -r network; do
                if [[ -n "${network}" ]]; then
                    echo -e "$(status_icon "up") ${WHITE}${network}${NC}"
                    
                    # 네트워크에 연결된 컨테이너 수
                    local containers=$(docker network inspect "${network}" --format '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")
                    local container_count=$(echo "${containers}" | wc -w)
                    echo -e "   ${WHITE}연결된 컨테이너:${NC} ${container_count}개"
                fi
            done <<< "${networks}"
        else
            log_info "프로젝트 관련 네트워크가 없습니다"
        fi
    fi
    
    # 포트 사용 상태 확인
    echo ""
    echo -e "${WHITE}포트 사용 상태:${NC}"
    
    local common_ports=(80 443 8080 3000 9000 5000)
    for port in "${common_ports[@]}"; do
        if command -v netstat &>/dev/null; then
            if netstat -ln 2>/dev/null | grep -q ":${port} "; then
                echo -e "$(status_icon "up") ${WHITE}포트 ${port}:${NC} ${GREEN}사용 중${NC}"
            else
                echo -e "$(status_icon "down") ${WHITE}포트 ${port}:${NC} ${YELLOW}미사용${NC}"
            fi
        elif command -v ss &>/dev/null; then
            if ss -ln 2>/dev/null | grep -q ":${port} "; then
                echo -e "$(status_icon "up") ${WHITE}포트 ${port}:${NC} ${GREEN}사용 중${NC}"
            else
                echo -e "$(status_icon "down") ${WHITE}포트 ${port}:${NC} ${YELLOW}미사용${NC}"
            fi
        fi
    done
    
    echo ""
}

# 볼륨 상태 확인
check_volumes_status() {
    log_header "볼륨 상태"
    
    if docker info &>/dev/null; then
        # 프로젝트 관련 볼륨 찾기
        local project_name=$(basename "${PROJECT_ROOT}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]_-')
        local volumes=$(docker volume ls --format "{{.Name}}" | grep -E "(${project_name}|nas|subdomain|gitea|uptime|codeserver|portainer)" 2>/dev/null || echo "")
        
        if [[ -n "${volumes}" ]]; then
            echo -e "${WHITE}프로젝트 볼륨:${NC}"
            while IFS= read -r volume; do
                if [[ -n "${volume}" ]]; then
                    echo -e "$(status_icon "up") ${WHITE}${volume}${NC}"
                    
                    # 볼륨 크기 (가능한 경우)
                    local volume_path=$(docker volume inspect "${volume}" --format '{{.Mountpoint}}' 2>/dev/null || echo "")
                    if [[ -n "${volume_path}" && -d "${volume_path}" ]]; then
                        local size=$(du -sh "${volume_path}" 2>/dev/null | cut -f1 || echo "Unknown")
                        echo -e "   ${WHITE}크기:${NC} ${size}"
                    fi
                    
                    # 볼륨을 사용하는 컨테이너
                    local using_containers=$(docker ps -a --filter volume="${volume}" --format "{{.Names}}" 2>/dev/null | tr '\n' ' ' || echo "")
                    if [[ -n "${using_containers}" ]]; then
                        echo -e "   ${WHITE}사용 컨테이너:${NC} ${using_containers}"
                    fi
                fi
            done <<< "${volumes}"
        else
            log_info "프로젝트 관련 볼륨이 없습니다"
        fi
        
        # 전체 볼륨 통계
        echo ""
        local total_volumes=$(docker volume ls -q | wc -l)
        echo -e "${WHITE}전체 볼륨 개수:${NC} ${total_volumes}개"
    else
        log_warn "Docker가 실행되지 않아 볼륨 상태를 확인할 수 없습니다"
    fi
    
    echo ""
}

# 로그 상태 확인
check_logs_status() {
    log_header "로그 상태"
    
    local log_dirs=("logs" "backup")
    
    for dir in "${log_dirs[@]}"; do
        if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
            echo -e "$(status_icon "up") ${WHITE}${dir} 디렉토리:${NC} ${GREEN}존재함${NC}"
            
            local file_count=$(find "${PROJECT_ROOT}/${dir}" -type f | wc -l)
            local dir_size=$(du -sh "${PROJECT_ROOT}/${dir}" 2>/dev/null | cut -f1 || echo "Unknown")
            echo -e "   ${WHITE}파일 개수:${NC} ${file_count}개, ${WHITE}크기:${NC} ${dir_size}"
            
            # 최근 로그 파일
            local recent_log=$(find "${PROJECT_ROOT}/${dir}" -name "*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
            if [[ -n "${recent_log}" ]]; then
                local log_date=$(stat -c %y "${recent_log}" 2>/dev/null | cut -d' ' -f1 || echo "Unknown")
                echo -e "   ${WHITE}최근 로그:${NC} $(basename "${recent_log}") (${log_date})"
            fi
        else
            echo -e "$(status_icon "down") ${WHITE}${dir} 디렉토리:${NC} ${RED}없음${NC}"
        fi
    done
    
    echo ""
}

# 전체 상태 요약
show_status_summary() {
    log_header "상태 요약"
    
    local status_ok=0
    local status_warn=0
    local status_error=0
    
    # 상태 점수 계산 (간단한 휴리스틱)
    
    # Docker 상태
    if docker info &>/dev/null; then
        ((status_ok++))
    else
        ((status_error++))
    fi
    
    # 필수 파일 존재 여부
    local config_files=(".env" "docker-compose.yml" "main.sh")
    for file in "${config_files[@]}"; do
        if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
            ((status_ok++))
        else
            ((status_error++))
        fi
    done
    
    # 서비스 상태 (Docker Compose가 있는 경우)
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]] && docker info &>/dev/null; then
        cd "${PROJECT_ROOT}"
        local running_services=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l || echo "0")
        local total_services=$(docker-compose ps --services 2>/dev/null | wc -l || echo "0")
        
        if [[ ${total_services} -gt 0 ]]; then
            if [[ ${running_services} -eq ${total_services} ]]; then
                ((status_ok++))
            elif [[ ${running_services} -gt 0 ]]; then
                ((status_warn++))
            else
                ((status_error++))
            fi
        fi
    fi
    
    # 전체 상태 표시
    local total_checks=$((status_ok + status_warn + status_error))
    
    if [[ ${total_checks} -gt 0 ]]; then
        echo -e "${WHITE}전체 상태:${NC}"
        echo -e "$(status_icon "up") ${GREEN}정상:${NC} ${status_ok}개"
        echo -e "$(status_icon "restarting") ${YELLOW}경고:${NC} ${status_warn}개"
        echo -e "$(status_icon "down") ${RED}오류:${NC} ${status_error}개"
        echo ""
        
        if [[ ${status_error} -eq 0 && ${status_warn} -eq 0 ]]; then
            echo -e "${GREEN}✅ 모든 시스템이 정상적으로 작동하고 있습니다.${NC}"
        elif [[ ${status_error} -eq 0 ]]; then
            echo -e "${YELLOW}⚠️  일부 항목에 주의가 필요합니다.${NC}"
        else
            echo -e "${RED}❌ 일부 시스템에 문제가 있습니다. 로그를 확인해주세요.${NC}"
        fi
    fi
    
    echo ""
}

# 빠른 상태 확인 (간단 버전)
quick_status() {
    echo -e "${CYAN}NAS-SubDomain-Manager 빠른 상태 확인${NC}"
    echo ""
    
    # Docker 상태
    if docker info &>/dev/null; then
        echo -e "$(status_icon "running") Docker: ${GREEN}실행 중${NC}"
    else
        echo -e "$(status_icon "down") Docker: ${RED}중지됨${NC}"
    fi
    
    # 서비스 상태
    if [[ -f "${PROJECT_ROOT}/docker-compose.yml" ]] && docker info &>/dev/null; then
        cd "${PROJECT_ROOT}"
        local running_services=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l || echo "0")
        local total_services=$(docker-compose ps --services 2>/dev/null | wc -l || echo "0")
        
        if [[ ${total_services} -gt 0 ]]; then
            echo -e "$(status_icon "running") 서비스: ${running_services}/${total_services} 실행 중"
        else
            echo -e "$(status_icon "down") 서비스: 정의되지 않음"
        fi
    else
        echo -e "$(status_icon "down") 서비스: 확인 불가"
    fi
    
    # 설정 파일
    if [[ -f "${PROJECT_ROOT}/.env" && -f "${PROJECT_ROOT}/docker-compose.yml" ]]; then
        echo -e "$(status_icon "up") 설정: ${GREEN}완료${NC}"
    else
        echo -e "$(status_icon "down") 설정: ${RED}불완전${NC}"
    fi
    
    echo ""
}

# 메인 함수
main() {
    # 로그 디렉토리 생성
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    case "${1:-full}" in
        "quick"|"q")
            quick_status
            ;;
        "full"|"f")
            check_system_info
            check_docker_status
            check_project_config
            check_services_status
            check_network_status
            check_volumes_status
            check_logs_status
            show_status_summary
            ;;
        "docker"|"d")
            check_docker_status
            check_services_status
            ;;
        "config"|"c")
            check_project_config
            ;;
        "services"|"s")
            check_services_status
            ;;
        "network"|"n")
            check_network_status
            ;;
        "volumes"|"v")
            check_volumes_status
            ;;
        "logs"|"l")
            check_logs_status
            ;;
        "help"|"-h"|"--help")
            echo "사용법: $0 [옵션]"
            echo ""
            echo "옵션:"
            echo "  full, f      - 전체 상태 확인 (기본값)"
            echo "  quick, q     - 빠른 상태 확인"
            echo "  docker, d    - Docker 및 서비스 상태"
            echo "  config, c    - 프로젝트 설정 확인"
            echo "  services, s  - 서비스 상태만 확인"
            echo "  network, n   - 네트워크 상태 확인"
            echo "  volumes, v   - 볼륨 상태 확인"
            echo "  logs, l      - 로그 상태 확인"
            echo "  help         - 도움말 표시"
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            echo "사용법: $0 [full|quick|docker|config|services|network|volumes|logs|help]"
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
