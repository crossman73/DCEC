#!/bin/bash
# 시놀로지 NAS 모든 서비스 서브도메인 설정 가이드
# DSM 리버스 프록시를 통한 crossman.synology.me 서브도메인 생성

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }
log_header() { echo -e "${PURPLE}[HEADER]${NC} $1"; }

# 서비스 정보 배열
declare -A SERVICES=(
    ["n8n"]="n8n.crossman.synology.me:31001:5678:워크플로우 자동화"
    ["mcp"]="mcp.crossman.synology.me:31002:31002:모델 컨텍스트 프로토콜"
    ["uptime"]="uptime.crossman.synology.me:31003:31003:모니터링 시스템"
    ["code"]="code.crossman.synology.me:8484:8484:VSCode 웹 환경"
    ["gitea"]="git.crossman.synology.me:3000:3000:Git 저장소"
    ["dsm"]="dsm.crossman.synology.me:5001:5001:DSM 관리 인터페이스"
)

# 네트워크 확인
check_network() {
    log_step "네트워크 연결 확인 중..."
    source ./network-check.sh
    detect_network_environment
    
    if ! check_nas_access; then
        log_error "NAS 접속 불가능. 네트워크 설정을 확인하세요."
        return 1
    fi
    return 0
}

# 단일 서비스 설정 가이드
setup_single_service() {
    local service_name="$1"
    local service_info="${SERVICES[$service_name]}"
    
    if [[ -z "$service_info" ]]; then
        log_error "알 수 없는 서비스: $service_name"
        return 1
    fi
    
    IFS=':' read -r subdomain external_port internal_port description <<< "$service_info"
    
    log_header "🌐 $service_name 서브도메인 설정"
    echo "======================================="
    echo ""
    echo "📋 서비스 정보:"
    echo "   서브도메인: $subdomain"
    echo "   설명: $description"
    echo "   외부 포트: $external_port"
    echo "   내부 포트: $internal_port"
    echo ""
    
    log_step "DSM 리버스 프록시 설정 단계:"
    echo ""
    echo "1️⃣  DSM 웹 인터페이스 접속"
    echo "   URL: http://192.168.0.5:5000 또는 https://192.168.0.5:5001"
    echo ""
    echo "2️⃣  제어판 > 응용 프로그램 포털 이동"
    echo ""
    echo "3️⃣  '리버스 프록시' 탭 클릭"
    echo ""
    echo "4️⃣  '만들기' 버튼 클릭"
    echo ""
    echo "5️⃣  리버스 프록시 규칙 입력:"
    echo "   ┌─ 소스 설정 ─────────────────────┐"
    echo "   │ 프로토콜: HTTPS                  │"
    echo "   │ 호스트 이름: $subdomain          │"
    echo "   │ 포트: 443                        │"
    echo "   └─────────────────────────────────┘"
    echo ""
    echo "   ┌─ 대상 설정 ─────────────────────┐"
    echo "   │ 프로토콜: HTTP                   │"
    echo "   │ 호스트 이름: localhost           │"
    echo "   │ 포트: $internal_port             │"
    echo "   └─────────────────────────────────┘"
    echo ""
    echo "6️⃣  고급 설정 (선택사항):"
    echo "   - WebSocket 지원 활성화 (필요한 경우)"
    echo "   - 사용자 정의 헤더 추가 (필요한 경우)"
    echo ""
    echo "7️⃣  '저장' 클릭"
    echo ""
    
    log_success "설정 완료 후 접속 테스트:"
    echo "   URL: https://$subdomain"
    echo "   내부 테스트: http://192.168.0.5:$internal_port"
    echo ""
    
    # 포트 확인
    log_step "현재 포트 상태 확인 중..."
    if command -v nc &> /dev/null; then
        if nc -z 192.168.0.5 $internal_port 2>/dev/null; then
            log_success "포트 $internal_port: 활성화됨"
        else
            log_warning "포트 $internal_port: 비활성화됨 (서비스가 실행되지 않음)"
            echo "         서비스를 먼저 시작해주세요."
        fi
    fi
    
    echo ""
    read -p "다음 서비스 설정으로 계속하시겠습니까? (Enter 키를 눌러주세요)"
}

# 모든 서비스 설정 가이드
setup_all_services() {
    log_header "🚀 모든 서비스 서브도메인 설정"
    echo "========================================="
    echo ""
    
    log_info "설정할 서비스 목록:"
    for service in "${!SERVICES[@]}"; do
        local service_info="${SERVICES[$service]}"
        IFS=':' read -r subdomain external_port internal_port description <<< "$service_info"
        printf "   %-8s %s (%s)\n" "$service" "$subdomain" "$description"
    done
    echo ""
    
    read -p "모든 서비스 설정을 시작하시겠습니까? (y/N): " response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        log_warning "설정이 취소되었습니다."
        return 1
    fi
    
    # 각 서비스별 설정
    for service in "${!SERVICES[@]}"; do
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        setup_single_service "$service"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    done
    
    log_header "🎉 모든 서비스 설정 완료!"
    echo ""
    log_info "설정된 서브도메인 목록:"
    for service in "${!SERVICES[@]}"; do
        local service_info="${SERVICES[$service]}"
        IFS=':' read -r subdomain external_port internal_port description <<< "$service_info"
        echo "   ✅ https://$subdomain ($description)"
    done
}

# SSL 인증서 설정 가이드
setup_ssl_certificates() {
    log_header "🔐 SSL 인증서 설정"
    echo "========================="
    echo ""
    
    log_step "Let's Encrypt 인증서 설정:"
    echo ""
    echo "1️⃣  DSM > 제어판 > 보안 > 인증서"
    echo ""
    echo "2️⃣  '추가' 버튼 클릭"
    echo ""
    echo "3️⃣  'Let's Encrypt에서 인증서 받기' 선택"
    echo ""
    echo "4️⃣  도메인 정보 입력:"
    echo "   ┌─ 주 도메인 ─────────────────────┐"
    echo "   │ crossman.synology.me             │"
    echo "   └─────────────────────────────────┘"
    echo ""
    echo "   ┌─ 주제 대체 이름 (SAN) ──────────┐"
    for service in "${!SERVICES[@]}"; do
        local service_info="${SERVICES[$service]}"
        IFS=':' read -r subdomain external_port internal_port description <<< "$service_info"
        echo "   │ $subdomain                       │"
    done
    echo "   └─────────────────────────────────┘"
    echo ""
    echo "5️⃣  이메일 주소 입력"
    echo ""
    echo "6️⃣  '완료' 클릭"
    echo ""
    
    log_success "인증서가 생성되면 자동으로 서브도메인에 적용됩니다."
    echo ""
}

# 방화벽 설정 가이드
setup_firewall() {
    log_header "🛡️ 방화벽 설정 확인"
    echo "========================"
    echo ""
    
    log_step "DSM 방화벽 규칙 확인:"
    echo ""
    echo "1️⃣  DSM > 제어판 > 보안 > 방화벽"
    echo ""
    echo "2️⃣  다음 포트가 허용되어 있는지 확인:"
    echo ""
    for service in "${!SERVICES[@]}"; do
        local service_info="${SERVICES[$service]}"
        IFS=':' read -r subdomain external_port internal_port description <<< "$service_info"
        printf "   %-8s %s → %s (%s)\n" "$service" "$external_port" "$internal_port" "$description"
    done
    echo "   HTTP     80  (리다이렉션용)"
    echo "   HTTPS    443 (SSL 접속용)"
    echo ""
    
    log_step "라우터 포트 포워딩 확인:"
    echo ""
    echo "3️⃣  ASUS RT-AX88U 라우터 설정 확인"
    echo "   URL: http://192.168.0.1"
    echo ""
    echo "4️⃣  고급 설정 > WAN > 가상 서버 / 포트 포워딩"
    echo ""
    echo "5️⃣  다음 규칙이 설정되어 있는지 확인:"
    for service in "${!SERVICES[@]}"; do
        local service_info="${SERVICES[$service]}"
        IFS=':' read -r subdomain external_port internal_port description <<< "$service_info"
        echo "   외부 포트 $external_port → 192.168.0.5:$internal_port ($service)"
    done
    echo ""
}

# 설정 검증
verify_setup() {
    log_header "🔍 서브도메인 설정 검증"
    echo "=========================="
    echo ""
    
    for service in "${!SERVICES[@]}"; do
        local service_info="${SERVICES[$service]}"
        IFS=':' read -r subdomain external_port internal_port description <<< "$service_info"
        
        echo "🔗 $service ($description)"
        echo "   서브도메인: https://$subdomain"
        echo "   내부 테스트: http://192.168.0.5:$internal_port"
        
        # 포트 연결 테스트
        if command -v nc &> /dev/null; then
            if nc -z 192.168.0.5 $internal_port 2>/dev/null; then
                echo "   상태: ✅ 포트 활성화"
            else
                echo "   상태: ❌ 포트 비활성화"
            fi
        fi
        echo ""
    done
    
    log_info "외부 접속 테스트:"
    echo "   1. 모바일 데이터 또는 외부 네트워크에서 접속"
    echo "   2. 각 서브도메인 URL로 접속 확인"
    echo "   3. SSL 인증서 정상 작동 확인"
    echo ""
}

# 도움말 표시
show_help() {
    cat << 'EOF'
🌐 시놀로지 NAS 서브도메인 설정 도구
====================================

사용법: ./setup-all-subdomains.sh [명령어] [서비스명]

명령어:
  all                     모든 서비스 서브도메인 설정 가이드
  setup [서비스명]        특정 서비스 설정 가이드
  ssl                     SSL 인증서 설정 가이드  
  firewall                방화벽 설정 확인 가이드
  verify                  설정 검증 및 테스트
  list                    지원 서비스 목록 표시
  help                    이 도움말 표시

지원 서비스:
  n8n      n8n.crossman.synology.me (워크플로우 자동화)
  mcp      mcp.crossman.synology.me (모델 컨텍스트 프로토콜)
  uptime   uptime.crossman.synology.me (모니터링 시스템)
  code     code.crossman.synology.me (VSCode 웹 환경)
  gitea    git.crossman.synology.me (Git 저장소)
  dsm      dsm.crossman.synology.me (DSM 관리 인터페이스)

예시:
  ./setup-all-subdomains.sh all           # 모든 서비스 설정
  ./setup-all-subdomains.sh setup n8n     # n8n만 설정
  ./setup-all-subdomains.sh ssl           # SSL 인증서 설정
  ./setup-all-subdomains.sh verify        # 설정 검증

EOF
}

# 서비스 목록 표시
list_services() {
    log_header "🌐 지원 서비스 목록"
    echo "==================="
    echo ""
    printf "%-8s %-35s %-15s %s\n" "서비스" "서브도메인" "포트" "설명"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for service in "${!SERVICES[@]}"; do
        local service_info="${SERVICES[$service]}"
        IFS=':' read -r subdomain external_port internal_port description <<< "$service_info"
        printf "%-8s %-35s %-15s %s\n" "$service" "$subdomain" "$external_port→$internal_port" "$description"
    done
    echo ""
}

# 메인 함수
main() {
    case "$1" in
        "all")
            if check_network; then
                setup_all_services
            fi
            ;;
        "setup")
            if [[ -n "$2" ]]; then
                if check_network; then
                    setup_single_service "$2"
                fi
            else
                log_error "서비스명을 지정하세요. 예: $0 setup n8n"
                show_help
            fi
            ;;
        "ssl")
            setup_ssl_certificates
            ;;
        "firewall")
            setup_firewall
            ;;
        "verify")
            if check_network; then
                verify_setup
            fi
            ;;
        "list")
            list_services
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "알 수 없는 명령어: $1"
            show_help
            exit 1
            ;;
    esac
}

# 스크립트 실행
main "$@"
