#!/bin/bash
# 시놀로지 NAS 리버스 프록시 서브도메인 자동 관리 스크립트
# DSM CLI를 활용한 서브도메인 설정 자동화

# 컬러 로깅 함수
log_info() { echo -e "\033[32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }
log_step() { echo -e "\033[34m[STEP]\033[0m $1"; }
log_success() { echo -e "\033[35m[SUCCESS]\033[0m $1"; }

# 서브도메인 서비스 설정 (README.md 기반)
declare -A SUBDOMAIN_CONFIG=(
    ["n8n"]="n8n.crossman.synology.me:31001:5678"
    ["mcp"]="mcp.crossman.synology.me:31002:31002"
    ["uptime"]="uptime.crossman.synology.me:31003:31003"
    ["code"]="code.crossman.synology.me:8484:8484"
    ["gitea"]="git.crossman.synology.me:3000:3000"
    ["dsm"]="dsm.crossman.synology.me:5001:5001"
)

# DSM 로그인 정보 (환경변수에서 읽기)
DSM_HOST=${DSM_HOST:-"192.168.0.5"}
DSM_PORT=${DSM_PORT:-"5001"}
DSM_USER=${DSM_USER:-"crossman"}
DSM_PASS=${DSM_PASS:-""}

# DSM API 세션 관리
DSM_SESSION=""
DSM_SID=""

# DSM API 로그인
login_dsm() {
    log_step "DSM API 로그인 중..."
    
    if [ -z "$DSM_PASS" ]; then
        read -s -p "DSM 비밀번호를 입력하세요: " DSM_PASS
        echo
    fi
    
    local response=$(curl -s -k \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "api=SYNO.API.Auth&version=3&method=login&account=${DSM_USER}&passwd=${DSM_PASS}&session=PortalManager&format=cookie" \
        "https://${DSM_HOST}:${DSM_PORT}/webapi/auth.cgi")
    
    if echo "$response" | grep -q '"success":true'; then
        DSM_SID=$(echo "$response" | grep -o '"sid":"[^"]*"' | cut -d'"' -f4)
        log_success "DSM 로그인 성공 (SID: ${DSM_SID:0:10}...)"
        return 0
    else
        log_error "DSM 로그인 실패: $response"
        return 1
    fi
}

# DSM API 로그아웃
logout_dsm() {
    if [ -n "$DSM_SID" ]; then
        curl -s -k \
            -X POST \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "api=SYNO.API.Auth&version=1&method=logout&session=PortalManager" \
            --cookie "_sid_=$DSM_SID" \
            "https://${DSM_HOST}:${DSM_PORT}/webapi/auth.cgi" > /dev/null
        log_info "DSM 로그아웃 완료"
    fi
}

# 리버스 프록시 규칙 조회
list_reverse_proxy() {
    log_step "기존 리버스 프록시 규칙 조회 중..."
    
    local response=$(curl -s -k \
        -X GET \
        --cookie "_sid_=$DSM_SID" \
        "https://${DSM_HOST}:${DSM_PORT}/webapi/entry.cgi?api=SYNO.Core.Portal.ReverseProxy&version=1&method=list")
    
    if echo "$response" | grep -q '"success":true'; then
        echo "$response" | jq -r '.data.records[] | "\(.id): \(.source_scheme)://\(.source_host):\(.source_port) -> \(.dest_scheme)://\(.dest_host):\(.dest_port)"' 2>/dev/null || {
            log_warn "jq가 설치되지 않음. 원본 JSON 출력:"
            echo "$response"
        }
        return 0
    else
        log_error "리버스 프록시 규칙 조회 실패: $response"
        return 1
    fi
}

# 리버스 프록시 규칙 추가
add_reverse_proxy() {
    local service_name="$1"
    local config="${SUBDOMAIN_CONFIG[$service_name]}"
    
    if [ -z "$config" ]; then
        log_error "알 수 없는 서비스: $service_name"
        return 1
    fi
    
    IFS=':' read -r subdomain external_port internal_port <<< "$config"
    
    log_step "리버스 프록시 규칙 추가: $service_name"
    log_info "  서브도메인: $subdomain"
    log_info "  외부 포트: $external_port"
    log_info "  내부 포트: $internal_port"
    
    # 리버스 프록시 규칙 데이터 구성
    local data="api=SYNO.Core.Portal.ReverseProxy&version=1&method=create"
    data+="&source_scheme=https"
    data+="&source_host=$subdomain"
    data+="&source_port=443"
    data+="&dest_scheme=http"
    data+="&dest_host=localhost"
    data+="&dest_port=$internal_port"
    data+="&enable_websocket=true"
    data+="&enable_http2=true"
    
    local response=$(curl -s -k \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --cookie "_sid_=$DSM_SID" \
        -d "$data" \
        "https://${DSM_HOST}:${DSM_PORT}/webapi/entry.cgi")
    
    if echo "$response" | grep -q '"success":true'; then
        log_success "리버스 프록시 규칙 추가 성공: $service_name"
        return 0
    else
        log_error "리버스 프록시 규칙 추가 실패: $response"
        return 1
    fi
}

# 리버스 프록시 규칙 삭제
delete_reverse_proxy() {
    local rule_id="$1"
    
    if [ -z "$rule_id" ]; then
        log_error "규칙 ID가 필요합니다"
        return 1
    fi
    
    log_step "리버스 프록시 규칙 삭제: ID $rule_id"
    
    local response=$(curl -s -k \
        -X POST \
        -H "Content-Type: application/x-www-form-urlencoded" \
        --cookie "_sid_=$DSM_SID" \
        -d "api=SYNO.Core.Portal.ReverseProxy&version=1&method=delete&id=$rule_id" \
        "https://${DSM_HOST}:${DSM_PORT}/webapi/entry.cgi")
    
    if echo "$response" | grep -q '"success":true'; then
        log_success "리버스 프록시 규칙 삭제 성공: ID $rule_id"
        return 0
    else
        log_error "리버스 프록시 규칙 삭제 실패: $response"
        return 1
    fi
}

# 모든 서브도메인 설정
setup_all_subdomains() {
    log_step "모든 서브도메인 리버스 프록시 설정 시작"
    
    local success_count=0
    local total_count=${#SUBDOMAIN_CONFIG[@]}
    
    for service in "${!SUBDOMAIN_CONFIG[@]}"; do
        if add_reverse_proxy "$service"; then
            ((success_count++))
        fi
        sleep 1  # API 호출 간격
    done
    
    log_info "설정 완료: $success_count/$total_count 성공"
    
    if [ $success_count -eq $total_count ]; then
        log_success "모든 서브도메인 설정 완료!"
    else
        log_warn "일부 서브도메인 설정 실패. 로그를 확인하세요."
    fi
}

# 서브도메인 상태 확인
check_subdomain_status() {
    log_step "서브도메인 접속 상태 확인"
    
    for service in "${!SUBDOMAIN_CONFIG[@]}"; do
        IFS=':' read -r subdomain external_port internal_port <<< "${SUBDOMAIN_CONFIG[$service]}"
        
        log_info "🔍 $service ($subdomain) 확인 중..."
        
        # HTTPS 접속 테스트
        if curl -s -k --connect-timeout 5 "https://$subdomain" > /dev/null 2>&1; then
            log_success "  ✅ HTTPS 접속 가능"
        else
            log_warn "  ❌ HTTPS 접속 실패"
        fi
        
        # 내부 포트 테스트
        if curl -s --connect-timeout 5 "http://localhost:$internal_port" > /dev/null 2>&1; then
            log_success "  ✅ 내부 서비스 동작 중 (포트 $internal_port)"
        else
            log_warn "  ⚠️  내부 서비스 미동작 (포트 $internal_port)"
        fi
    done
}

# 도움말 출력
show_help() {
    echo "시놀로지 NAS 리버스 프록시 서브도메인 관리"
    echo "================================================"
    echo ""
    echo "사용법: $0 [명령어] [옵션]"
    echo ""
    echo "명령어:"
    echo "  list                   - 기존 리버스 프록시 규칙 조회"
    echo "  add <서비스명>         - 특정 서비스 서브도메인 추가"
    echo "  delete <규칙ID>        - 특정 규칙 삭제"
    echo "  setup-all              - 모든 서브도메인 설정"
    echo "  status                 - 서브도메인 접속 상태 확인"
    echo "  help                   - 이 도움말 출력"
    echo ""
    echo "지원 서비스:"
    for service in "${!SUBDOMAIN_CONFIG[@]}"; do
        IFS=':' read -r subdomain external_port internal_port <<< "${SUBDOMAIN_CONFIG[$service]}"
        echo "  $service - $subdomain (외부:$external_port -> 내부:$internal_port)"
    done
    echo ""
    echo "환경변수:"
    echo "  DSM_HOST  - DSM 호스트 주소 (기본값: 192.168.0.5)"
    echo "  DSM_PORT  - DSM 포트 번호 (기본값: 5001)"
    echo "  DSM_USER  - DSM 사용자명 (기본값: crossman)"
    echo "  DSM_PASS  - DSM 비밀번호 (입력 프롬프트에서 설정 가능)"
}

# 메인 함수
main() {
    local command="$1"
    local param="$2"
    
    case "$command" in
        "list")
            if login_dsm; then
                list_reverse_proxy
                logout_dsm
            fi
            ;;
        "add")
            if [ -z "$param" ]; then
                log_error "서비스명이 필요합니다. 예: $0 add n8n"
                exit 1
            fi
            if login_dsm; then
                add_reverse_proxy "$param"
                logout_dsm
            fi
            ;;
        "delete")
            if [ -z "$param" ]; then
                log_error "규칙 ID가 필요합니다. 예: $0 delete 1"
                exit 1
            fi
            if login_dsm; then
                delete_reverse_proxy "$param"
                logout_dsm
            fi
            ;;
        "setup-all")
            if login_dsm; then
                setup_all_subdomains
                logout_dsm
            fi
            ;;
        "status")
            check_subdomain_status
            ;;
        "help"|"--help"|"-h"|"")
            show_help
            ;;
        *)
            log_error "알 수 없는 명령어: $command"
            show_help
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
