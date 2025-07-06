#!/bin/bash

# Approval System - 요청/승인 시스템
# 모든 중요한 작업에 대해 사용자 승인을 요구하는 시스템

# 색상 정의
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# 승인 로그 파일
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly APPROVAL_LOG="${PROJECT_ROOT}/logs/approval.log"

# 승인 요청 함수
request_approval() {
    local action="$1"
    local description="$2"
    local risk_level="${3:-medium}"
    local confirmation_text="${4:-yes}"
    
    echo -e "${CYAN}===============================================${NC}"
    echo -e "${WHITE}  🔒 승인 요청 (Approval Request)${NC}"
    echo -e "${CYAN}===============================================${NC}"
    echo -e "${YELLOW}작업 (Action):${NC} ${action}"
    echo -e "${YELLOW}설명 (Description):${NC} ${description}"
    echo -e "${YELLOW}위험 등급 (Risk Level):${NC} $(get_risk_color ${risk_level})${risk_level}${NC}"
    echo -e "${YELLOW}시간 (Time):${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # 위험 등급별 추가 경고
    case "${risk_level}" in
        "high"|"critical")
            echo -e "${RED}⚠️  높은 위험 작업입니다. 신중하게 검토해주세요.${NC}"
            echo -e "${RED}⚠️  이 작업은 서비스 중단이나 데이터 손실을 초래할 수 있습니다.${NC}"
            echo ""
            ;;
        "medium")
            echo -e "${YELLOW}⚠️  보통 위험 작업입니다. 계속 진행하시겠습니까?${NC}"
            echo ""
            ;;
        "low")
            echo -e "${GREEN}ℹ️  낮은 위험 작업입니다.${NC}"
            echo ""
            ;;
    esac
    
    # 승인 요청
    echo -e "${CYAN}이 작업을 승인하시겠습니까?${NC}"
    echo -e "${WHITE}계속 진행하려면 '${confirmation_text}'를 입력하세요 (취소하려면 Enter 또는 다른 값):${NC}"
    echo -n "> "
    
    read -r user_input
    
    # 로그 기록
    log_approval_request "${action}" "${description}" "${risk_level}" "${user_input}" "${confirmation_text}"
    
    # 승인 확인
    if [[ "${user_input}" == "${confirmation_text}" ]]; then
        echo -e "${GREEN}✅ 승인되었습니다. 작업을 계속 진행합니다.${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ 승인이 거부되었습니다. 작업을 중단합니다.${NC}"
        echo ""
        return 1
    fi
}

# 위험 등급별 색상 반환
get_risk_color() {
    local risk_level="$1"
    case "${risk_level}" in
        "critical") echo "${RED}" ;;
        "high") echo "${RED}" ;;
        "medium") echo "${YELLOW}" ;;
        "low") echo "${GREEN}" ;;
        *) echo "${WHITE}" ;;
    esac
}

# 승인 로그 기록
log_approval_request() {
    local action="$1"
    local description="$2"
    local risk_level="$3"
    local user_input="$4"
    local confirmation_text="$5"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local status="DENIED"
    
    if [[ "${user_input}" == "${confirmation_text}" ]]; then
        status="APPROVED"
    fi
    
    # 로그 디렉토리 생성
    mkdir -p "$(dirname "${APPROVAL_LOG}")"
    
    # 로그 기록
    echo "[${timestamp}] ACTION: ${action} | DESCRIPTION: ${description} | RISK: ${risk_level} | STATUS: ${status} | USER_INPUT: ${user_input}" >> "${APPROVAL_LOG}"
}

# 파괴적 작업 승인 요청 (높은 위험도)
request_destructive_approval() {
    local action="$1"
    local description="$2"
    local confirmation_text="I_UNDERSTAND_THE_RISKS"
    
    echo -e "${RED}⚠️  파괴적 작업 경고 (DESTRUCTIVE OPERATION WARNING)${NC}"
    echo -e "${RED}⚠️  이 작업은 데이터 손실이나 서비스 중단을 초래할 수 있습니다.${NC}"
    echo -e "${RED}⚠️  백업이 있는지 확인하고 신중하게 진행하세요.${NC}"
    echo ""
    
    request_approval "${action}" "${description}" "critical" "${confirmation_text}"
}

# 서비스 중단 승인 요청
request_service_interruption_approval() {
    local action="$1"
    local description="$2"
    local services="$3"
    local confirmation_text="PROCEED_WITH_INTERRUPTION"
    
    echo -e "${YELLOW}⚠️  서비스 중단 경고 (SERVICE INTERRUPTION WARNING)${NC}"
    echo -e "${YELLOW}⚠️  다음 서비스들이 일시적으로 중단될 수 있습니다:${NC}"
    echo -e "${YELLOW}⚠️  ${services}${NC}"
    echo ""
    
    request_approval "${action}" "${description}" "medium" "${confirmation_text}"
}

# 백업 확인 요청
request_backup_confirmation() {
    local action="$1"
    local description="$2"
    
    echo -e "${CYAN}💾 백업 확인 요청${NC}"
    echo -e "${WHITE}이 작업을 진행하기 전에 백업이 있는지 확인해주세요.${NC}"
    echo ""
    
    request_approval "${action}" "${description}" "medium" "BACKUP_CONFIRMED"
}

# 자동 승인 (로그만 기록)
auto_approve() {
    local action="$1"
    local description="$2"
    local risk_level="${3:-low}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${GREEN}🔓 자동 승인: ${action}${NC}"
    echo -e "${WHITE}   ${description}${NC}"
    echo ""
    
    # 로그 기록
    mkdir -p "$(dirname "${APPROVAL_LOG}")"
    echo "[${timestamp}] ACTION: ${action} | DESCRIPTION: ${description} | RISK: ${risk_level} | STATUS: AUTO_APPROVED" >> "${APPROVAL_LOG}"
}

# 승인 로그 보기
show_approval_log() {
    local lines="${1:-20}"
    
    if [[ -f "${APPROVAL_LOG}" ]]; then
        echo -e "${CYAN}최근 승인 로그 (최근 ${lines}개):${NC}"
        tail -n "${lines}" "${APPROVAL_LOG}"
    else
        echo -e "${YELLOW}승인 로그가 없습니다.${NC}"
    fi
}

# 승인 통계
show_approval_stats() {
    if [[ -f "${APPROVAL_LOG}" ]]; then
        echo -e "${CYAN}승인 통계:${NC}"
        echo -e "${WHITE}전체 요청: $(wc -l < "${APPROVAL_LOG}")${NC}"
        echo -e "${GREEN}승인된 요청: $(grep -c "STATUS: APPROVED" "${APPROVAL_LOG}" 2>/dev/null || echo "0")${NC}"
        echo -e "${GREEN}자동 승인: $(grep -c "STATUS: AUTO_APPROVED" "${APPROVAL_LOG}" 2>/dev/null || echo "0")${NC}"
        echo -e "${RED}거부된 요청: $(grep -c "STATUS: DENIED" "${APPROVAL_LOG}" 2>/dev/null || echo "0")${NC}"
        echo ""
        echo -e "${CYAN}위험 등급별 통계:${NC}"
        echo -e "${RED}Critical: $(grep -c "RISK: critical" "${APPROVAL_LOG}" 2>/dev/null || echo "0")${NC}"
        echo -e "${RED}High: $(grep -c "RISK: high" "${APPROVAL_LOG}" 2>/dev/null || echo "0")${NC}"
        echo -e "${YELLOW}Medium: $(grep -c "RISK: medium" "${APPROVAL_LOG}" 2>/dev/null || echo "0")${NC}"
        echo -e "${GREEN}Low: $(grep -c "RISK: low" "${APPROVAL_LOG}" 2>/dev/null || echo "0")${NC}"
    else
        echo -e "${YELLOW}승인 로그가 없습니다.${NC}"
    fi
}

# 테스트 모드 (승인 없이 진행)
enable_test_mode() {
    export NAS_APPROVAL_TEST_MODE=true
    echo -e "${YELLOW}⚠️  테스트 모드가 활성화되었습니다. 모든 승인 요청이 자동으로 승인됩니다.${NC}"
}

disable_test_mode() {
    unset NAS_APPROVAL_TEST_MODE
    echo -e "${GREEN}✅ 테스트 모드가 비활성화되었습니다. 정상적인 승인 프로세스가 적용됩니다.${NC}"
}

# 테스트 모드 확인
is_test_mode() {
    [[ "${NAS_APPROVAL_TEST_MODE:-false}" == "true" ]]
}

# 테스트 모드에서의 승인 요청
request_approval_safe() {
    local action="$1"
    local description="$2"
    local risk_level="${3:-medium}"
    local confirmation_text="${4:-yes}"
    
    if is_test_mode; then
        auto_approve "${action}" "${description}" "${risk_level}"
        return 0
    else
        request_approval "${action}" "${description}" "${risk_level}" "${confirmation_text}"
        return $?
    fi
}
