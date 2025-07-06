#!/bin/bash
# 시놀로지 NAS 서브도메인 관리 시스템 데모
# 실제 DSM API 호출 없이 시스템 동작을 시연

# 컬러 로깅 함수
log_info() { echo -e "\033[32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }
log_step() { echo -e "\033[34m[STEP]\033[0m $1"; }
log_success() { echo -e "\033[35m[SUCCESS]\033[0m $1"; }

# 데모 데이터
DEMO_SERVICES=("n8n" "mcp" "uptime" "code" "gitea" "dsm")
DEMO_RULES=(
    "1:https://n8n.crossman.synology.me:443 -> http://localhost:5678"
    "2:https://mcp.crossman.synology.me:443 -> http://localhost:31002"
    "3:https://uptime.crossman.synology.me:443 -> http://localhost:31003"
)

# 헤더 출력
show_header() {
    clear
    echo "🌐 시놀로지 NAS 서브도메인 관리 시스템 - 데모"
    echo "=============================================="
    echo ""
    echo "⚠️  이것은 데모 모드입니다. 실제 DSM API는 호출되지 않습니다."
    echo ""
}

# 네트워크 환경 시뮬레이션
demo_network_check() {
    log_step "네트워크 환경 감지 중..."
    sleep 1
    
    # 랜덤하게 내부/외부 네트워크 시뮬레이션
    if [ $((RANDOM % 2)) -eq 0 ]; then
        log_success "✅ 내부 네트워크 (로컬) 감지됨: 192.168.0.100"
        export NETWORK_ENV="local"
    else
        log_info "🌐 외부 네트워크 감지됨: 203.xxx.xxx.xxx"
        log_step "🔒 OpenVPN 연결 확인 중..."
        sleep 1
        log_success "✅ OpenVPN 연결됨 - NAS 접근 가능"
        export NETWORK_ENV="vpn"
    fi
}

# DSM 연결 시뮬레이션
demo_dsm_connection() {
    log_step "DSM 연결 테스트 중..."
    sleep 1
    log_success "DSM 연결 성공 (https://192.168.0.5:5001)"
    
    log_step "DSM API 로그인 중..."
    sleep 1
    log_success "DSM 로그인 성공 (SID: a1b2c3d4e5...)"
}

# 리버스 프록시 규칙 목록 시뮬레이션
demo_list_rules() {
    log_step "기존 리버스 프록시 규칙 조회 중..."
    sleep 1
    
    echo ""
    echo "📋 현재 설정된 리버스 프록시 규칙:"
    echo "================================"
    for rule in "${DEMO_RULES[@]}"; do
        echo "  $rule"
    done
    echo ""
}

# 서비스 추가 시뮬레이션
demo_add_service() {
    local service="$1"
    
    log_step "리버스 프록시 규칙 추가: $service"
    
    case "$service" in
        "n8n")
            log_info "  서브도메인: n8n.crossman.synology.me"
            log_info "  외부 포트: 31001"
            log_info "  내부 포트: 5678"
            ;;
        "code")
            log_info "  서브도메인: code.crossman.synology.me"
            log_info "  외부 포트: 8484"
            log_info "  내부 포트: 8484"
            ;;
        *)
            log_info "  서브도메인: $service.crossman.synology.me"
            log_info "  포트 매핑 확인 중..."
            ;;
    esac
    
    sleep 2
    log_success "리버스 프록시 규칙 추가 성공: $service"
}

# 모든 서브도메인 설정 시뮬레이션
demo_setup_all() {
    log_step "모든 서브도메인 리버스 프록시 설정 시작"
    echo ""
    
    local success_count=0
    local total_count=${#DEMO_SERVICES[@]}
    
    for service in "${DEMO_SERVICES[@]}"; do
        log_info "🔧 $service 서브도메인 설정 중..."
        sleep 1
        
        if [ $((RANDOM % 10)) -lt 8 ]; then  # 80% 성공률
            log_success "  ✅ $service 설정 완료"
            ((success_count++))
        else
            log_warn "  ⚠️  $service 설정 실패 (중복 규칙 존재)"
        fi
    done
    
    echo ""
    log_info "설정 완료: $success_count/$total_count 성공"
    
    if [ $success_count -eq $total_count ]; then
        log_success "모든 서브도메인 설정 완료!"
    else
        log_warn "일부 서브도메인 설정 실패. 실제 환경에서는 로그를 확인하세요."
    fi
}

# 상태 확인 시뮬레이션
demo_status_check() {
    log_step "서브도메인 접속 상태 확인"
    echo ""
    
    local services=("n8n" "mcp" "uptime" "code" "gitea" "dsm")
    local subdomains=("n8n.crossman.synology.me" "mcp.crossman.synology.me" "uptime.crossman.synology.me" "code.crossman.synology.me" "git.crossman.synology.me" "dsm.crossman.synology.me")
    local ports=(5678 31002 31003 8484 3000 5001)
    
    for i in "${!services[@]}"; do
        local service="${services[$i]}"
        local subdomain="${subdomains[$i]}"
        local port="${ports[$i]}"
        
        log_info "🔍 $service ($subdomain) 확인 중..."
        sleep 1
        
        # HTTPS 테스트 시뮬레이션
        if [ $((RANDOM % 10)) -lt 7 ]; then  # 70% 성공률
            log_success "  ✅ HTTPS 접속 가능"
        else
            log_warn "  ❌ HTTPS 접속 실패"
        fi
        
        # 내부 서비스 테스트 시뮬레이션
        if [ $((RANDOM % 10)) -lt 8 ]; then  # 80% 성공률
            log_success "  ✅ 내부 서비스 동작 중 (포트 $port)"
        else
            log_warn "  ⚠️  내부 서비스 미동작 (포트 $port)"
        fi
        echo ""
    done
}

# 규칙 삭제 시뮬레이션
demo_delete_rule() {
    local rule_id="$1"
    
    log_step "리버스 프록시 규칙 삭제: ID $rule_id"
    sleep 1
    
    if [ "$rule_id" -le 3 ] && [ "$rule_id" -ge 1 ]; then
        log_success "리버스 프록시 규칙 삭제 성공: ID $rule_id"
    else
        log_error "규칙 ID를 찾을 수 없습니다: $rule_id"
    fi
}

# 서비스 목록 출력
show_services() {
    echo ""
    echo "📋 지원 서비스 목록:"
    echo "==================="
    echo ""
    echo "┌─────────────────────────────────────────────────────────────────────────┐"
    echo "│ 서비스  │ 서브도메인                    │ 외부포트 │ 내부포트 │ 설명        │"
    echo "├─────────────────────────────────────────────────────────────────────────┤"
    echo "│ n8n     │ n8n.crossman.synology.me     │ 31001    │ 5678     │ 워크플로우   │"
    echo "│ mcp     │ mcp.crossman.synology.me     │ 31002    │ 31002    │ MCP 서버    │"
    echo "│ uptime  │ uptime.crossman.synology.me  │ 31003    │ 31003    │ 모니터링    │"
    echo "│ code    │ code.crossman.synology.me    │ 8484     │ 8484     │ VSCode 웹   │"
    echo "│ gitea   │ git.crossman.synology.me     │ 3000     │ 3000     │ Git 저장소  │"
    echo "│ dsm     │ dsm.crossman.synology.me     │ 5001     │ 5001     │ NAS 관리    │"
    echo "└─────────────────────────────────────────────────────────────────────────┘"
    echo ""
}

# 메인 데모 메뉴
show_demo_menu() {
    echo ""
    echo "🎭 데모 메뉴:"
    echo "============"
    echo ""
    echo "1. 네트워크 환경 체크 시뮬레이션"
    echo "2. DSM 연결 테스트 시뮬레이션"
    echo "3. 리버스 프록시 규칙 조회"
    echo "4. 서비스 추가 시뮬레이션"
    echo "5. 모든 서브도메인 설정 시뮬레이션"
    echo "6. 상태 확인 시뮬레이션"
    echo "7. 규칙 삭제 시뮬레이션"
    echo "8. 서비스 목록 보기"
    echo "9. 전체 워크플로우 시연"
    echo "0. 종료"
    echo ""
    read -p "선택하세요 (0-9): " choice
    return $choice
}

# 전체 워크플로우 시연
demo_full_workflow() {
    log_step "🎬 전체 워크플로우 시연 시작"
    echo ""
    
    echo "1️⃣  네트워크 환경 및 DSM 연결 확인"
    demo_network_check
    echo ""
    demo_dsm_connection
    echo ""
    
    echo "2️⃣  기존 설정 확인"
    demo_list_rules
    
    echo "3️⃣  새 서비스 추가"
    demo_add_service "code"
    echo ""
    
    echo "4️⃣  모든 서브도메인 상태 확인"
    demo_status_check
    
    echo "5️⃣  시연 완료"
    log_success "🎉 전체 워크플로우 시연이 완료되었습니다!"
    echo ""
    log_info "실제 사용 시에는 다음 명령어를 사용하세요:"
    echo "  ./subdomain-manager.sh              # 대화형 모드"
    echo "  ./subdomain-manager.sh setup-all    # 모든 서브도메인 설정"
    echo "  ./subdomain-manager.sh status       # 상태 확인"
}

# 메인 함수
main() {
    show_header
    
    while true; do
        show_demo_menu
        choice=$?
        
        case $choice in
            1)
                echo ""
                demo_network_check
                ;;
            2)
                echo ""
                demo_dsm_connection
                ;;
            3)
                echo ""
                demo_list_rules
                ;;
            4)
                echo ""
                show_services
                read -p "추가할 서비스명을 입력하세요 (n8n, code, mcp, etc.): " service_name
                if [ -n "$service_name" ]; then
                    demo_add_service "$service_name"
                fi
                ;;
            5)
                echo ""
                demo_setup_all
                ;;
            6)
                echo ""
                demo_status_check
                ;;
            7)
                echo ""
                demo_list_rules
                read -p "삭제할 규칙 ID를 입력하세요: " rule_id
                if [ -n "$rule_id" ]; then
                    demo_delete_rule "$rule_id"
                fi
                ;;
            8)
                show_services
                ;;
            9)
                echo ""
                demo_full_workflow
                ;;
            0)
                echo ""
                log_info "데모를 종료합니다."
                echo ""
                log_info "실제 서브도메인 관리를 위해서는 다음을 실행하세요:"
                echo "  ./subdomain-manager.sh"
                exit 0
                ;;
            *)
                log_error "잘못된 선택입니다. 다시 선택해주세요."
                ;;
        esac
        
        echo ""
        read -p "계속하려면 Enter를 누르세요..."
    done
}

# 실행
main
