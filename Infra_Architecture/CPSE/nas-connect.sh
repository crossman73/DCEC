# 시놀로지 NAS SSH 접속 도우미 스크립트
# 사용자: crossman, 포트: 22022

#!/bin/bash

# NAS 연결 정보
NAS_IP="192.168.0.5"
SSH_PORT="22022"
SSH_USER="crossman"

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🔌 시놀로지 NAS 접속 도우미${NC}"
echo -e "${YELLOW}접속 정보: ${SSH_USER}@${NAS_IP}:${SSH_PORT}${NC}"
echo ""

# 접속 방법 선택
case "$1" in
    "ssh")
        echo -e "${GREEN}SSH 접속 중...${NC}"
        ssh -p ${SSH_PORT} ${SSH_USER}@${NAS_IP}
        ;;
    "scp")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "사용법: $0 scp <로컬파일> <원격경로>"
            echo "예시: $0 scp ./test.txt /volume1/homes/crossman/"
            exit 1
        fi
        echo -e "${GREEN}파일 복사 중: $2 -> $3${NC}"
        scp -P ${SSH_PORT} "$2" ${SSH_USER}@${NAS_IP}:"$3"
        ;;
    "rsync")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "사용법: $0 rsync <로컬디렉토리> <원격경로>"
            echo "예시: $0 rsync ./project/ /volume1/docker/"
            exit 1
        fi
        echo -e "${GREEN}디렉토리 동기화 중: $2 -> $3${NC}"
        rsync -avz -e "ssh -p ${SSH_PORT}" "$2" ${SSH_USER}@${NAS_IP}:"$3"
        ;;
    "test")
        echo -e "${GREEN}NAS 연결 테스트 중...${NC}"
        ssh -p ${SSH_PORT} -o ConnectTimeout=5 ${SSH_USER}@${NAS_IP} "echo '✅ NAS 연결 성공!' && uname -a"
        ;;
    "dsm")
        echo -e "${GREEN}DSM API 토큰 테스트 중...${NC}"
        # DSM API를 통한 간단한 연결 테스트
        curl -s -X POST \
            "http://${NAS_IP}:5000/webapi/auth.cgi" \
            -d "api=SYNO.API.Auth" \
            -d "version=3" \
            -d "method=login" \
            -d "account=${SSH_USER}" \
            -d "passwd=test" \
            -d "session=WebAPI" | jq .
        ;;
    *)
        echo -e "${GREEN}사용법:${NC}"
        echo "  $0 ssh          # SSH 직접 접속"
        echo "  $0 test         # 연결 테스트"
        echo "  $0 scp <file> <dest>   # 파일 복사"
        echo "  $0 rsync <dir> <dest>  # 디렉토리 동기화"
        echo "  $0 dsm          # DSM API 테스트"
        echo ""
        echo -e "${YELLOW}수동 접속 명령어:${NC}"
        echo "  ssh -p ${SSH_PORT} ${SSH_USER}@${NAS_IP}"
        ;;
esac
