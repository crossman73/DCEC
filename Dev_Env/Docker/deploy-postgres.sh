#!/bin/bash
# DCEC 1단계: Postgres 단독 배포/운영/상태/백업 자동화
# 실행 위치: /volume1/dev/docker
# 로그: /volume1/dev/docker/logs/dcec_postgres_deploy_$(date +%Y%m%d_%H%M%S).log

set -e
DCEC_ROOT="/volume1/dev/docker"
DCEC_DATA="$DCEC_ROOT/data/postgres"
DCEC_COMPOSE="$DCEC_ROOT/postgres-only-compose.yml"
DCEC_ENV="$DCEC_ROOT/.env.postgres"
DCEC_LOG="$DCEC_ROOT/logs/dcec_postgres_deploy_$(date +%Y%m%d_%H%M%S).log"

# 1. 디렉토리/권한
sudo mkdir -p "$DCEC_DATA" "$DCEC_ROOT/logs"
sudo chown -R crossman:users "$DCEC_DATA" "$DCEC_ROOT/logs"
sudo chmod -R 755 "$DCEC_DATA" "$DCEC_ROOT/logs"

# 2. 배포
cd "$DCEC_ROOT"
echo "[DCEC] Postgres 배포 시작" | tee -a "$DCEC_LOG"
docker-compose -f "$DCEC_COMPOSE" --env-file "$DCEC_ENV" pull | tee -a "$DCEC_LOG"
docker-compose -f "$DCEC_COMPOSE" --env-file "$DCEC_ENV" up -d | tee -a "$DCEC_LOG"

# 3. 상태/로그
sleep 3
echo "[DCEC] Postgres 상태 확인" | tee -a "$DCEC_LOG"
docker ps -a | grep dcec-postgres | tee -a "$DCEC_LOG"
docker logs dcec-postgres --tail 30 | tee -a "$DCEC_LOG"

# 4. 백업(예시)
BACKUP_DIR="$DCEC_ROOT/backup/postgres_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
docker exec dcec-postgres pg_dumpall -U n8n > "$BACKUP_DIR/pg_backup.sql"
echo "[DCEC] Postgres 백업 완료: $BACKUP_DIR/pg_backup.sql" | tee -a "$DCEC_LOG"

echo "[DCEC] 1단계(Postgres) 배포/운영/백업 완료. 로그: $DCEC_LOG"
