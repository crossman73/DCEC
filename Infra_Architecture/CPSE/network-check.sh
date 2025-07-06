# 시놀로지 NAS 네트워크 환경별 접속 가이드
# OpenVPN 보안 환경에서의 NAS 접속 관리

#!/bin/bash

# 네트워크 환경 감지
detect_network_environment() {
    echo "🔍 네트워크 환경 감지 중..."
    
    # 내부 네트워크 확인 (192.168.0.x 대역)
    local_ip=$(ip route get 1 | awk '{print $7}' | head -1 2>/dev/null)
    
    if [[ $local_ip == 192.168.0.* ]]; then
        echo "✅ 내부 네트워크 (로컬) 감지됨: $local_ip"
        export NETWORK_ENV="local"
        export NAS_IP="192.168.0.5"
    else
        echo "🌐 외부 네트워크 감지됨: $local_ip"
        echo "🔒 OpenVPN 연결 확인 중..."
        
        # OpenVPN 인터페이스 확인
        if ip link show | grep -q "tun\|tap"; then
            # VPN 연결 시 NAS IP 확인
            if ping -c 1 -W 2 192.168.0.5 &>/dev/null; then
                echo "✅ OpenVPN 연결됨 - NAS 접근 가능"
                export NETWORK_ENV="vpn"
                export NAS_IP="192.168.0.5"
            else
                echo "❌ OpenVPN 연결되었으나 NAS 접근 불가"
                export NETWORK_ENV="vpn_error"
            fi
        else
            echo "❌ OpenVPN 연결 안됨 - 외부에서 NAS 접근 불가"
            export NETWORK_ENV="external_blocked"
        fi
    fi
}

# 접속 가능 여부 확인
check_nas_access() {
    case $NETWORK_ENV in
        "local")
            echo "✅ 로컬 네트워크에서 직접 접속 가능"
            echo "   SSH: ssh -p 22022 crossman@192.168.0.5"
            echo "   DSM: http://192.168.0.5:5000"
            return 0
            ;;
        "vpn")
            echo "✅ OpenVPN을 통한 접속 가능"
            echo "   SSH: ssh -p 22022 crossman@192.168.0.5"
            echo "   DSM: http://192.168.0.5:5000"
            return 0
            ;;
        "vpn_error")
            echo "⚠️  OpenVPN 연결 문제 - 연결 상태 확인 필요"
            echo "   해결 방법:"
            echo "   1. OpenVPN 클라이언트 재연결"
            echo "   2. VPN 설정 확인"
            echo "   3. 네트워크 재시작"
            return 1
            ;;
        "external_blocked")
            echo "🚫 외부에서 직접 접속 차단됨 (보안 정책)"
            echo "   접속 방법:"
            echo "   1. OpenVPN 클라이언트 연결 후 접속"
            echo "   2. 내부 네트워크로 이동 후 접속"
            echo ""
            echo "📱 OpenVPN 연결 가이드:"
            echo "   - Windows: OpenVPN GUI 실행"
            echo "   - 설정 파일: RT_ax88u_router_client.ovpn"
            echo "   - 연결 후 다시 시도"
            return 1
            ;;
    esac
}

# OpenVPN 연결 도우미
connect_openvpn() {
    echo "🔐 OpenVPN 연결 도우미"
    echo ""
    
    # Windows OpenVPN 확인
    if command -v openvpn &> /dev/null; then
        echo "OpenVPN 클라이언트 발견됨"
        if [ -f "../../Vpn/RT_ax88u_router_client.ovpn" ]; then
            echo "✅ VPN 설정 파일 발견: RT_ax88u_router_client.ovpn"
            echo ""
            echo "연결 명령어:"
            echo "sudo openvpn --config ../../Vpn/RT_ax88u_router_client.ovpn"
        else
            echo "❌ VPN 설정 파일을 찾을 수 없습니다."
            echo "파일 위치: d:/Dev/DCEC/Infra_Architecture/Vpn/RT_ax88u_router_client.ovpn"
        fi
    else
        echo "📱 Windows에서 OpenVPN GUI 사용 권장:"
        echo "1. OpenVPN GUI 실행 (관리자 권한)"
        echo "2. RT_ax88u_router_client.ovpn 파일 가져오기"
        echo "3. 연결 후 스크립트 재실행"
    fi
}

# 메인 함수
main() {
    echo "🏠 시놀로지 NAS 네트워크 접속 체크"
    echo "=================================="
    
    detect_network_environment
    echo ""
    
    if check_nas_access; then
        echo ""
        echo "🎯 NAS 서비스 포트:"
        echo "   DSM (HTTP):  5000"
        echo "   DSM (HTTPS): 5001"
        echo "   SSH:         22022"
        echo ""
        echo "🚀 서브도메인 관리 가능!"
    else
        echo ""
        if [ "$NETWORK_ENV" = "external_blocked" ]; then
            connect_openvpn
        fi
    fi
}

# 실행
case "$1" in
    "check")
        main
        ;;
    "vpn")
        connect_openvpn
        ;;
    *)
        echo "사용법: $0 {check|vpn}"
        echo "  check - 네트워크 환경 및 접속 가능성 확인"
        echo "  vpn   - OpenVPN 연결 가이드"
        ;;
esac
