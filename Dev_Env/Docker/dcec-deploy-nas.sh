#!/bin/bash
# DCEC 통합 배포 자동화 스크립트 (NAS: /volume1/dev/docker)
# 실행 전제: crossman 계정 SSH 키 인증, sudo 패스워드 없이 사용 가능
# 모든 서비스/설정/권한/상태/로그를 일괄 관리

set -e

# 1. 변수 선언 (DCEC 네이밍)
DCEC_ROOT="/volume1/dev/docker"
DCEC_DATA="$DCEC_ROOT/data"
DCEC_CONFIG="$DCEC_ROOT/config"
DCEC_LOGS="$DCEC_ROOT/logs"
DCEC_COMPOSE="$DCEC_ROOT/docker-compose.yml"
DCEC_ENV="$DCEC_ROOT/.env"
DCEC_DEPLOY_LOG="$DCEC_ROOT/dcec_deploy_$(date +%Y%m%d_%H%M%S).log"
DCEC_PASSWORD="data!5522"

# 2. 디렉토리/권한 생성
sudo mkdir -p "$DCEC_DATA" "$DCEC_CONFIG" "$DCEC_LOGS"
sudo chown -R crossman:users "$DCEC_ROOT"
sudo chmod -R 755 "$DCEC_ROOT"

# 3. .env 파일 생성 (필요시)
if [ ! -f "$DCEC_ENV" ]; then
  cat > "$DCEC_ENV" <<EOF
# DCEC 통합 환경 변수
DB_PASSWORD=$DCEC_PASSWORD
N8N_PASSWORD=$DCEC_PASSWORD
VSCODE_PASSWORD=$DCEC_PASSWORD
GITEA_PASSWORD=$DCEC_PASSWORD
EOF
fi

# 4. docker-compose.yml 파일 존재 확인
if [ ! -f "$DCEC_COMPOSE" ]; then
  echo "[ERROR] $DCEC_COMPOSE 파일이 없습니다. 로컬에서 업로드 후 다시 실행하세요." | tee -a "$DCEC_DEPLOY_LOG"
  exit 1
fi

# 5. 도커 네트워크 생성 (존재하지 않으면)
docker network inspect nas-services-network >/dev/null 2>&1 || \
  docker network create nas-services-network

# 6. 서비스 배포
cd "$DCEC_ROOT"
echo "[DCEC] Docker Compose Pull & Up..." | tee -a "$DCEC_DEPLOY_LOG"
docker-compose pull | tee -a "$DCEC_DEPLOY_LOG"
docker-compose up -d | tee -a "$DCEC_DEPLOY_LOG"

# 7. 상태/로그 확인
sleep 5
echo "[DCEC] 서비스 상태 확인" | tee -a "$DCEC_DEPLOY_LOG"
docker-compose ps | tee -a "$DCEC_DEPLOY_LOG"
echo "[DCEC] n8n 로그 (최근 50줄)" | tee -a "$DCEC_DEPLOY_LOG"
docker logs nas-n8n --tail 50 | tee -a "$DCEC_DEPLOY_LOG"

echo "[DCEC] 통합 배포 완료. 상세 로그: $DCEC_DEPLOY_LOG"
