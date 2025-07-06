#!/bin/bash

# MCP Server 관리 스크립트
# Version: 1.0.0
# Description: Model Context Protocol 서버 관리 자동화

set -euo pipefail

# 설정 파일 로드
source "$(dirname "$0")/../../.env"

# 로그 설정
LOG_FILE="/var/log/mcp-server.log"
SCRIPT_NAME="$(basename "$0")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$SCRIPT_NAME] ERROR: $1" | tee -a "$LOG_FILE" >&2
}

# MCP 서버 상태 확인
check_mcp_status() {
    log "MCP 서버 상태 확인 중..."
    
    if docker ps | grep -q "mcp-server"; then
        log "MCP 서버가 실행 중입니다."
        return 0
    else
        log "MCP 서버가 실행 중이 아닙니다."
        return 1
    fi
}

# MCP 서버 시작
start_mcp() {
    log "MCP 서버 시작 중..."
    
    docker-compose -f "$(dirname "$0")/../../docker-compose.yml" up -d mcp-server
    
    # 서버 준비 대기
    sleep 10
    
    if check_mcp_status; then
        log "MCP 서버가 성공적으로 시작되었습니다."
    else
        error "MCP 서버 시작에 실패했습니다."
        exit 1
    fi
}

# MCP 서버 중지
stop_mcp() {
    log "MCP 서버 중지 중..."
    
    docker-compose -f "$(dirname "$0")/../../docker-compose.yml" stop mcp-server
    
    log "MCP 서버가 중지되었습니다."
}

# MCP 서버 재시작
restart_mcp() {
    log "MCP 서버 재시작 중..."
    
    stop_mcp
    sleep 5
    start_mcp
}

# MCP 서버 헬스 체크
health_check() {
    log "MCP 서버 헬스 체크 중..."
    
    local health_url="http://localhost:31002/health"
    
    if curl -f -s "$health_url" > /dev/null 2>&1; then
        log "MCP 서버 헬스 체크 성공"
        return 0
    else
        error "MCP 서버 헬스 체크 실패"
        return 1
    fi
}

# MCP 서버 로그 확인
show_logs() {
    log "MCP 서버 로그 확인 중..."
    
    docker logs mcp-server --tail 50 -f
}

# MCP 서버 설정 업데이트
update_config() {
    log "MCP 서버 설정 업데이트 중..."
    
    # 컨테이너 재시작으로 환경 변수 적용
    restart_mcp
    
    log "MCP 서버 설정이 업데이트되었습니다."
}

# 사용법 표시
usage() {
    echo "사용법: $0 {start|stop|restart|status|health|logs|update|help}"
    echo ""
    echo "명령어:"
    echo "  start   - MCP 서버 시작"
    echo "  stop    - MCP 서버 중지"
    echo "  restart - MCP 서버 재시작"
    echo "  status  - MCP 서버 상태 확인"
    echo "  health  - MCP 서버 헬스 체크"
    echo "  logs    - MCP 서버 로그 확인"
    echo "  update  - MCP 서버 설정 업데이트"
    echo "  help    - 이 도움말 표시"
}

# 메인 실행부
main() {
    case "${1:-help}" in
        start)
            start_mcp
            ;;
        stop)
            stop_mcp
            ;;
        restart)
            restart_mcp
            ;;
        status)
            check_mcp_status
            ;;
        health)
            health_check
            ;;
        logs)
            show_logs
            ;;
        update)
            update_config
            ;;
        help|*)
            usage
            ;;
    esac
}

# 스크립트 실행
main "$@"
