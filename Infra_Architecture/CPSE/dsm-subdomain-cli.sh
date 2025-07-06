# 시놀로지 DSM CLI 서브도메인 관리 스크립트
# DSM의 웹 API와 CLI를 이용한 서브도메인 자동화

#!/bin/bash

# 설정
NAS_IP="192.168.0.5"
SSH_PORT="22022"
DSM_USER="crossman"
DSM_PASS="your_password"
BASE_DOMAIN="crossman.synology.me"

# DSM API 세션 토큰 획득
get_dsm_token() {
    local response=$(curl -s -X POST \
        "http://${NAS_IP}:5000/webapi/auth.cgi" \
        -d "api=SYNO.API.Auth" \
        -d "version=3" \
        -d "method=login" \
        -d "account=${DSM_USER}" \
        -d "passwd=${DSM_PASS}" \
        -d "session=WebAPI")
    
    echo $response | jq -r '.data.sid'
}

# DDNS 설정 조회
check_ddns_settings() {
    local token=$1
    curl -s -X GET \
        "http://${NAS_IP}:5000/webapi/entry.cgi" \
        -d "api=SYNO.Core.DDNS" \
        -d "version=1" \
        -d "method=list" \
        -d "_sid=${token}"
}

# 리버스 프록시 규칙 추가 (DSM 7.0+)
add_reverse_proxy() {
    local token=$1
    local subdomain=$2
    local target_port=$3
    
    curl -s -X POST \
        "http://${NAS_IP}:5000/webapi/entry.cgi" \
        -d "api=SYNO.Core.ProxyReverse" \
        -d "version=1" \
        -d "method=create" \
        -d "_sid=${token}" \
        -d "source_protocol=https" \
        -d "source_host=${subdomain}.${BASE_DOMAIN}" \
        -d "source_port=443" \
        -d "dest_protocol=http" \
        -d "dest_host=localhost" \
        -d "dest_port=${target_port}"
}

# 포트 포워딩 규칙 추가
add_port_forward() {
    local token=$1
    local external_port=$2
    local internal_port=$3
    local service_name=$4
    
    # DSM의 방화벽 규칙 추가
    curl -s -X POST \
        "http://${NAS_IP}:5000/webapi/entry.cgi" \
        -d "api=SYNO.Core.Security.Firewall" \
        -d "version=1" \
        -d "method=set" \
        -d "_sid=${token}" \
        -d "enable=true" \
        -d "rules=[{\"name\":\"${service_name}\",\"ports\":\"${external_port}\",\"protocol\":\"tcp\",\"action\":\"allow\"}]"
}

# SSL 인증서 설정
configure_ssl() {
    local token=$1
    local subdomain=$2
    
    # Let's Encrypt 인증서 요청
    curl -s -X POST \
        "http://${NAS_IP}:5000/webapi/entry.cgi" \
        -d "api=SYNO.Core.Certificate" \
        -d "version=1" \
        -d "method=create" \
        -d "_sid=${token}" \
        -d "type=lets_encrypt" \
        -d "domain=${subdomain}.${BASE_DOMAIN}"
}

# 서브도메인 전체 설정
setup_subdomain() {
    local subdomain=$1
    local port=$2
    local service_name=$3
    
    echo "🔧 ${subdomain}.${BASE_DOMAIN} 서브도메인 설정 중..."
    
    # 1. DSM 로그인
    local token=$(get_dsm_token)
    if [ "$token" = "null" ]; then
        echo "❌ DSM 로그인 실패"
        return 1
    fi
    
    # 2. 리버스 프록시 설정
    echo "📡 리버스 프록시 설정..."
    add_reverse_proxy "$token" "$subdomain" "$port"
    
    # 3. 포트 포워딩 설정
    echo "🔀 포트 포워딩 설정..."
    add_port_forward "$token" "$port" "$port" "$service_name"
    
    # 4. SSL 인증서 설정
    echo "🔒 SSL 인증서 설정..."
    configure_ssl "$token" "$subdomain"
    
    echo "✅ ${subdomain}.${BASE_DOMAIN} 설정 완료!"
}

# 사용 예시
case "$1" in
    "setup")
        setup_subdomain "$2" "$3" "$4"
        ;;
    "check")
        token=$(get_dsm_token)
        check_ddns_settings "$token"
        ;;
    *)
        echo "사용법: $0 {setup|check} [subdomain] [port] [service_name]"
        echo "예시: $0 setup mcp 31002 'MCP Server'"
        ;;
esac
