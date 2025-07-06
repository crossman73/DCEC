#!/bin/bash
# 시놀로지 NAS 통합 서브도메인 관리 시스템
# 네트워크 체크 + 리버스 프록시 관리 통합

# 현재 스크립트 디렉토리
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 컬러 로깅 함수
log_info() { echo -e "\033[32m[INFO]\033[0m $1"; }
log_warn() { echo -e "\033[33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $1"; }
log_step() { echo -e "\033[34m[STEP]\033[0m $1"; }
log_success() { echo -e "\033[35m[SUCCESS]\033[0m $1"; }

# 네트워크 환경 체크
check_network_and_access() {
    log_step "네트워크 환경 및 NAS 접속 체크"
    
    # network-check.sh 스크립트 실행
    if [ -f "$SCRIPT_DIR/network-check.sh" ]; then
        bash "$SCRIPT_DIR/network-check.sh" check
        
        # 네트워크 환경 변수 가져오기
        source "$SCRIPT_DIR/network-check.sh" check 2>/dev/null || true
        
        if [ "$NETWORK_ENV" = "local" ] || [ "$NETWORK_ENV" = "vpn" ]; then
            log_success "NAS 접속 가능 - 서브도메인 관리 작업 진행 가능"
            return 0
        else
            log_error "NAS 접속 불가 - 네트워크 환경 확인 필요"
            return 1
        fi
    else
        log_warn "network-check.sh 스크립트를 찾을 수 없습니다. 기본 접속 시도"
        return 0
    fi
}

# DSM 연결 테스트
test_dsm_connection() {
    log_step "DSM 연결 테스트 중..."
    
    local dsm_host=${DSM_HOST:-"192.168.0.5"}
    local dsm_port=${DSM_PORT:-"5001"}
    
    if curl -s -k --connect-timeout 10 "https://$dsm_host:$dsm_port" > /dev/null 2>&1; then
        log_success "DSM 연결 성공 (https://$dsm_host:$dsm_port)"
        return 0
    else
        log_error "DSM 연결 실패 - 네트워크 환경 또는 DSM 상태 확인 필요"
        return 1
    fi
}

# 서브도메인 관리 메뉴
show_subdomain_menu() {
    echo ""
    echo "🌐 시놀로지 NAS 서브도메인 관리"
    echo "==============================="
    echo ""
    echo "1. 기존 리버스 프록시 규칙 조회"
    echo "2. 특정 서비스 서브도메인 추가"
    echo "3. 모든 서브도메인 자동 설정"
    echo "4. 서브도메인 접속 상태 확인"
    echo "5. 리버스 프록시 규칙 삭제"
    echo "6. 서브도메인 서비스 목록 보기"
    echo "7. 네트워크 환경 재확인"
    echo "0. 종료"
    echo ""
    read -p "선택하세요 (0-7): " choice
    return $choice
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

# 서비스 추가 대화형 메뉴
interactive_add_service() {
    show_services
    echo "추가할 서비스를 선택하세요:"
    echo ""
    echo "1. n8n (워크플로우 자동화)"
    echo "2. mcp (모델 컨텍스트 프로토콜)"
    echo "3. uptime (모니터링 서비스)"
    echo "4. code (VSCode 웹 환경)"
    echo "5. gitea (Git 저장소)"
    echo "6. dsm (NAS 관리 패널)"
    echo "0. 취소"
    echo ""
    read -p "선택하세요 (0-6): " service_choice
    
    case $service_choice in
        1) service_name="n8n";;
        2) service_name="mcp";;
        3) service_name="uptime";;
        4) service_name="code";;
        5) service_name="gitea";;
        6) service_name="dsm";;
        0) return 1;;
        *) 
            log_error "잘못된 선택입니다."
            return 1
            ;;
    esac
    
    log_info "선택된 서비스: $service_name"
    bash "$SCRIPT_DIR/reverse-proxy-manager.sh" add "$service_name"
}

# 규칙 삭제 대화형 메뉴
interactive_delete_rule() {
    echo ""
    log_step "삭제할 규칙을 선택하기 위해 먼저 기존 규칙을 조회합니다."
    bash "$SCRIPT_DIR/reverse-proxy-manager.sh" list
    echo ""
    read -p "삭제할 규칙의 ID를 입력하세요 (취소: 0): " rule_id
    
    if [ "$rule_id" = "0" ]; then
        return 1
    fi
    
    if [ -z "$rule_id" ]; then
        log_error "규칙 ID를 입력해야 합니다."
        return 1
    fi
    
    log_warn "규칙 ID $rule_id를 삭제하려고 합니다."
    read -p "계속하시겠습니까? (y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        bash "$SCRIPT_DIR/reverse-proxy-manager.sh" delete "$rule_id"
    else
        log_info "삭제가 취소되었습니다."
    fi
}

# 모든 서브도메인 설정 확인
confirm_setup_all() {
    echo ""
    log_warn "모든 서브도메인을 자동으로 설정합니다."
    show_services
    echo ""
    echo "⚠️  주의사항:"
    echo "   - 중복된 서브도메인이 있을 경우 오류가 발생할 수 있습니다"
    echo "   - 내부 서비스가 실행 중인지 확인하세요"
    echo "   - 포트 충돌이 없는지 확인하세요"
    echo ""
    read -p "계속하시겠습니까? (y/N): " confirm
    
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        bash "$SCRIPT_DIR/reverse-proxy-manager.sh" setup-all
    else
        log_info "설정이 취소되었습니다."
    fi
}

# 메인 실행 함수
main() {
    echo "🏠 시놀로지 NAS 통합 서브도메인 관리 시스템"
    echo "==========================================="
    echo ""
    
    # 네트워크 및 DSM 연결 체크
    if ! check_network_and_access; then
        echo ""
        log_error "네트워크 환경 문제로 인해 서브도메인 관리 작업을 수행할 수 없습니다."
        echo ""
        echo "해결 방법:"
        echo "1. 내부 네트워크(192.168.0.x)에서 실행하세요"
        echo "2. 외부에서는 OpenVPN 연결 후 실행하세요"
        echo "3. ./network-check.sh vpn 명령으로 VPN 연결 가이드 확인"
        exit 1
    fi
    
    if ! test_dsm_connection; then
        echo ""
        log_error "DSM 연결 실패로 인해 서브도메인 관리 작업을 수행할 수 없습니다."
        echo ""
        echo "해결 방법:"
        echo "1. NAS가 정상 동작하는지 확인하세요"
        echo "2. DSM 웹 인터페이스 접속 확인 (https://192.168.0.5:5001)"
        echo "3. 방화벽 설정 확인"
        exit 1
    fi
    
    # 메인 메뉴 루프
    while true; do
        show_subdomain_menu
        choice=$?
        
        case $choice in
            1)
                log_step "기존 리버스 프록시 규칙 조회"
                bash "$SCRIPT_DIR/reverse-proxy-manager.sh" list
                ;;
            2)
                log_step "특정 서비스 서브도메인 추가"
                interactive_add_service
                ;;
            3)
                log_step "모든 서브도메인 자동 설정"
                confirm_setup_all
                ;;
            4)
                log_step "서브도메인 접속 상태 확인"
                bash "$SCRIPT_DIR/reverse-proxy-manager.sh" status
                ;;
            5)
                log_step "리버스 프록시 규칙 삭제"
                interactive_delete_rule
                ;;
            6)
                show_services
                ;;
            7)
                log_step "네트워크 환경 재확인"
                check_network_and_access
                test_dsm_connection
                ;;
            0)
                log_info "프로그램을 종료합니다."
                exit 0
                ;;
            *)
                log_error "잘못된 선택입니다. 다시 선택해주세요."
                ;;
        esac
        
        echo ""
        read -p "계속하려면 Enter를 누르세요..."
        echo ""
    done
}

# 명령행 인수 처리
if [ $# -eq 0 ]; then
    # 인수가 없으면 대화형 모드
    main
else
    # 인수가 있으면 직접 실행
    case "$1" in
        "check")
            check_network_and_access && test_dsm_connection
            ;;
        "list")
            bash "$SCRIPT_DIR/reverse-proxy-manager.sh" list
            ;;
        "add")
            if [ -z "$2" ]; then
                log_error "서비스명이 필요합니다. 예: $0 add n8n"
                exit 1
            fi
            bash "$SCRIPT_DIR/reverse-proxy-manager.sh" add "$2"
            ;;
        "setup-all")
            bash "$SCRIPT_DIR/reverse-proxy-manager.sh" setup-all
            ;;
        "status")
            bash "$SCRIPT_DIR/reverse-proxy-manager.sh" status
            ;;
        "delete")
            if [ -z "$2" ]; then
                log_error "규칙 ID가 필요합니다. 예: $0 delete 1"
                exit 1
            fi
            bash "$SCRIPT_DIR/reverse-proxy-manager.sh" delete "$2"
            ;;
        "help"|"--help"|"-h")
            echo "시놀로지 NAS 통합 서브도메인 관리 시스템"
            echo "======================================="
            echo ""
            echo "사용법: $0 [명령어] [옵션]"
            echo ""
            echo "대화형 모드:"
            echo "  $0                     - 대화형 메뉴 실행"
            echo ""
            echo "직접 실행:"
            echo "  $0 check               - 네트워크 및 DSM 연결 확인"
            echo "  $0 list                - 기존 리버스 프록시 규칙 조회"
            echo "  $0 add <서비스명>      - 특정 서비스 서브도메인 추가"
            echo "  $0 setup-all           - 모든 서브도메인 설정"
            echo "  $0 status              - 서브도메인 접속 상태 확인"
            echo "  $0 delete <규칙ID>     - 특정 규칙 삭제"
            echo "  $0 help                - 이 도움말 출력"
            echo ""
            echo "지원 서비스: n8n, mcp, uptime, code, gitea, dsm"
            ;;
        *)
            log_error "알 수 없는 명령어: $1"
            echo "도움말: $0 help"
            exit 1
            ;;
    esac
fi
