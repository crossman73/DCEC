#!/bin/bash
# DSM Reverse Proxy - Missing Services Setup Script
# Description: Add missing services to DSM reverse proxy configuration
# Version: 1.0.0

set -euo pipefail

# ===========================================
# Configuration
# ===========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/dsm-missing-services.log"

# NAS 설정
NAS_HOST="192.168.0.5"
NAS_USER="crossman"
BASE_DOMAIN="crossman.synology.me"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ===========================================
# Logging Functions
# ===========================================
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log "${RED}[ERROR]${NC} $1"
}

# ===========================================
# Service Configuration
# ===========================================
declare -A MISSING_SERVICES=(
    ["code"]="code.$BASE_DOMAIN:8484"
    ["mcp"]="mcp.$BASE_DOMAIN:31002"
    ["uptime"]="uptime.$BASE_DOMAIN:31003"
    ["portainer"]="portainer.$BASE_DOMAIN:9000"
)

# ===========================================
# Generate DSM Reverse Proxy Configuration
# ===========================================
generate_reverse_proxy_config() {
    log_info "DSM 리버스 프록시 설정 생성 중..."
    
    cat << 'EOF' > "$SCRIPT_DIR/dsm-reverse-proxy-config.json"
{
  "reverse_proxy_rules": [
    {
      "description": "VS Code Server",
      "source_protocol": "HTTPS",
      "source_hostname": "code.crossman.synology.me",
      "source_port": 443,
      "destination_protocol": "HTTP",
      "destination_hostname": "localhost",
      "destination_port": 8484,
      "enable_websocket": true,
      "enable_hsts": true,
      "enable_http2": true,
      "custom_headers": [
        {
          "name": "X-Forwarded-Proto",
          "value": "https"
        },
        {
          "name": "X-Forwarded-Host",
          "value": "code.crossman.synology.me"
        }
      ]
    },
    {
      "description": "MCP Server",
      "source_protocol": "HTTPS",
      "source_hostname": "mcp.crossman.synology.me",
      "source_port": 443,
      "destination_protocol": "HTTP",
      "destination_hostname": "localhost",
      "destination_port": 31002,
      "enable_websocket": true,
      "enable_hsts": true,
      "enable_http2": true,
      "custom_headers": [
        {
          "name": "X-Forwarded-Proto",
          "value": "https"
        },
        {
          "name": "X-Forwarded-Host",
          "value": "mcp.crossman.synology.me"
        }
      ]
    },
    {
      "description": "Uptime Kuma",
      "source_protocol": "HTTPS",
      "source_hostname": "uptime.crossman.synology.me",
      "source_port": 443,
      "destination_protocol": "HTTP",
      "destination_hostname": "localhost",
      "destination_port": 31003,
      "enable_websocket": true,
      "enable_hsts": true,
      "enable_http2": true,
      "custom_headers": [
        {
          "name": "X-Forwarded-Proto",
          "value": "https"
        },
        {
          "name": "X-Forwarded-Host",
          "value": "uptime.crossman.synology.me"
        }
      ]
    },
    {
      "description": "Portainer",
      "source_protocol": "HTTPS",
      "source_hostname": "portainer.crossman.synology.me",
      "source_port": 443,
      "destination_protocol": "HTTP",
      "destination_hostname": "localhost",
      "destination_port": 9000,
      "enable_websocket": true,
      "enable_hsts": true,
      "enable_http2": true,
      "custom_headers": [
        {
          "name": "X-Forwarded-Proto",
          "value": "https"
        },
        {
          "name": "X-Forwarded-Host",
          "value": "portainer.crossman.synology.me"
        }
      ]
    }
  ]
}
EOF
    
    log_success "DSM 리버스 프록시 설정 파일 생성 완료"
}

# ===========================================
# Generate Manual Setup Guide
# ===========================================
generate_manual_setup_guide() {
    log_info "수동 설정 가이드 생성 중..."
    
    cat << EOF > "$SCRIPT_DIR/missing-services-manual-setup.md"
# DSM 리버스 프록시 - 누락된 서비스 설정 가이드

## 1. VS Code Server (code.crossman.synology.me)
### DSM 제어판 > 애플리케이션 포털 > 리버스 프록시에서 다음 설정:

**소스:**
- 프로토콜: HTTPS
- 호스트 이름: code.crossman.synology.me
- 포트: 443

**대상:**
- 프로토콜: HTTP
- 호스트 이름: localhost
- 포트: 8484

**고급 설정:**
- WebSocket 지원 활성화
- HSTS 활성화
- HTTP/2 활성화

**사용자 정의 헤더:**
```
X-Forwarded-Proto: https
X-Forwarded-Host: code.crossman.synology.me
```

---

## 2. MCP Server (mcp.crossman.synology.me)
### DSM 제어판 > 애플리케이션 포털 > 리버스 프록시에서 다음 설정:

**소스:**
- 프로토콜: HTTPS
- 호스트 이름: mcp.crossman.synology.me
- 포트: 443

**대상:**
- 프로토콜: HTTP
- 호스트 이름: localhost
- 포트: 31002

**고급 설정:**
- WebSocket 지원 활성화
- HSTS 활성화
- HTTP/2 활성화

**사용자 정의 헤더:**
```
X-Forwarded-Proto: https
X-Forwarded-Host: mcp.crossman.synology.me
```

---

## 3. Uptime Kuma (uptime.crossman.synology.me)
### DSM 제어판 > 애플리케이션 포털 > 리버스 프록시에서 다음 설정:

**소스:**
- 프로토콜: HTTPS
- 호스트 이름: uptime.crossman.synology.me
- 포트: 443

**대상:**
- 프로토콜: HTTP
- 호스트 이름: localhost
- 포트: 31003

**고급 설정:**
- WebSocket 지원 활성화
- HSTS 활성화
- HTTP/2 활성화

**사용자 정의 헤더:**
```
X-Forwarded-Proto: https
X-Forwarded-Host: uptime.crossman.synology.me
```

---

## 4. Portainer (portainer.crossman.synology.me)
### DSM 제어판 > 애플리케이션 포털 > 리버스 프록시에서 다음 설정:

**소스:**
- 프로토콜: HTTPS
- 호스트 이름: portainer.crossman.synology.me
- 포트: 443

**대상:**
- 프로토콜: HTTP
- 호스트 이름: localhost
- 포트: 9000

**고급 설정:**
- WebSocket 지원 활성화
- HSTS 활성화
- HTTP/2 활성화

**사용자 정의 헤더:**
```
X-Forwarded-Proto: https
X-Forwarded-Host: portainer.crossman.synology.me
```

---

## 5. 설정 완료 후 확인 사항

### 5.1 포트 포워딩 확인
라우터(ASUS RT-AX88U)에서 다음 포트가 NAS로 포워딩되어 있는지 확인:
- 443 → 192.168.0.111:443 (HTTPS)
- 80 → 192.168.0.111:80 (HTTP, 리디렉션용)

### 5.2 방화벽 설정 확인
DSM 제어판 > 보안 > 방화벽에서:
- 포트 443 (HTTPS) 허용
- 포트 80 (HTTP) 허용
- 서비스별 포트 (8484, 31002, 31003, 9000) 허용

### 5.3 SSL 인증서 확인
DSM 제어판 > 보안 > 인증서에서:
- 와일드카드 인증서 (*.crossman.synology.me) 설정 확인
- 각 서브도메인에 인증서 적용

### 5.4 서비스 상태 확인
각 서비스가 정상적으로 실행되고 있는지 확인:
```bash
# NAS SSH 접속 후 실행
docker ps
docker-compose -f /volume1/dev/docker/docker-compose.yml ps
```

### 5.5 외부 접속 테스트
각 서브도메인에 브라우저로 접속하여 정상 동작 확인:
- https://code.crossman.synology.me
- https://mcp.crossman.synology.me
- https://uptime.crossman.synology.me
- https://portainer.crossman.synology.me

---

## 6. 문제 해결

### 6.1 502 Bad Gateway 오류
- 대상 서비스가 실행 중인지 확인
- 포트 번호가 올바른지 확인
- 방화벽 설정 확인

### 6.2 SSL 인증서 오류
- 와일드카드 인증서 설정 확인
- 도메인 이름 확인
- 인증서 유효기간 확인

### 6.3 WebSocket 연결 오류
- 리버스 프록시에서 WebSocket 지원 활성화
- 사용자 정의 헤더 설정 확인

생성 시간: $(date)
EOF
    
    log_success "수동 설정 가이드 생성 완료: $SCRIPT_DIR/missing-services-manual-setup.md"
}

# ===========================================
# Test Service Connectivity
# ===========================================
test_service_connectivity() {
    log_info "서비스 연결 상태 확인 중..."
    
    for service in "${!MISSING_SERVICES[@]}"; do
        local service_info="${MISSING_SERVICES[$service]}"
        local domain="${service_info%%:*}"
        local port="${service_info##*:}"
        
        log_info "테스트 중: $service ($NAS_HOST:$port)"
        
        if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$NAS_HOST:$port" | grep -q "200\|302\|401"; then
            log_success "$service 서비스 정상 동작 (포트 $port)"
        else
            log_warning "$service 서비스 응답 없음 (포트 $port)"
        fi
    done
}

# ===========================================
# Generate Verification Script
# ===========================================
generate_verification_script() {
    log_info "검증 스크립트 생성 중..."
    
    cat << 'EOF' > "$SCRIPT_DIR/verify-missing-services.sh"
#!/bin/bash
# Verify missing services are properly configured

NAS_HOST="192.168.0.111"
BASE_DOMAIN="crossman.synology.me"

declare -A SERVICES=(
    ["code"]="code.$BASE_DOMAIN:8484"
    ["mcp"]="mcp.$BASE_DOMAIN:31002"
    ["uptime"]="uptime.$BASE_DOMAIN:31003"
    ["portainer"]="portainer.$BASE_DOMAIN:9000"
)

echo "=== 누락된 서비스 상태 확인 ==="
echo "시간: $(date)"
echo

for service in "${!SERVICES[@]}"; do
    service_info="${SERVICES[$service]}"
    domain="${service_info%%:*}"
    port="${service_info##*:}"
    
    echo -n "[$service] "
    
    # Check local port
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$NAS_HOST:$port" | grep -q "200\|302\|401"; then
        echo -n "로컬포트(✓) "
    else
        echo -n "로컬포트(✗) "
    fi
    
    # Check subdomain (if configured)
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "https://$domain" | grep -q "200\|302\|401"; then
        echo "서브도메인(✓)"
    else
        echo "서브도메인(✗)"
    fi
done

echo
echo "=== 추가 설정 필요 사항 ==="
echo "1. DSM 리버스 프록시에서 위의 서비스들 설정"
echo "2. 와일드카드 SSL 인증서 적용"
echo "3. 방화벽 및 포트포워딩 확인"
EOF
    
    chmod +x "$SCRIPT_DIR/verify-missing-services.sh"
    log_success "검증 스크립트 생성 완료: $SCRIPT_DIR/verify-missing-services.sh"
}

# ===========================================
# Main Function
# ===========================================
main() {
    log_info "=========================================="
    log_info "DSM 리버스 프록시 누락 서비스 설정 시작"
    log_info "=========================================="
    
    generate_reverse_proxy_config
    generate_manual_setup_guide
    test_service_connectivity
    generate_verification_script
    
    log_success "=========================================="
    log_success "DSM 리버스 프록시 누락 서비스 설정 완료!"
    log_success "=========================================="
    
    log_info "생성된 파일들:"
    log_info "- 리버스 프록시 설정: $SCRIPT_DIR/dsm-reverse-proxy-config.json"
    log_info "- 수동 설정 가이드: $SCRIPT_DIR/missing-services-manual-setup.md"
    log_info "- 검증 스크립트: $SCRIPT_DIR/verify-missing-services.sh"
    
    log_info "다음 단계:"
    log_info "1. DSM 웹 인터페이스에서 리버스 프록시 규칙 수동 추가"
    log_info "2. 검증 스크립트 실행: ./verify-missing-services.sh"
    log_info "3. 각 서브도메인 외부 접속 테스트"
}

# ===========================================
# Script Execution
# ===========================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
