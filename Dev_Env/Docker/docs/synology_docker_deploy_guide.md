# Synology Docker CLI 배포 스크립트 가이드

## 목차
- [환경 설정](#환경-설정)
- [프로젝트 구조](#프로젝트-구조)
- [배포 스크립트](#배포-스크립트)
- [Docker 관리 스크립트](#docker-관리-스크립트)
- [사용 방법](#사용-방법)
- [트러블슈팅](#트러블슈팅)

---

## 환경 설정

### 1. 시놀로지 SSH 활성화
```bash
# DSM 제어판 → 터미널 및 SNMP → SSH 서비스 활성화
# 포트: 22 (기본값)
```

### 2. 기본 디렉토리 구조
```bash
# 시놀로지 NAS 기본 경로
/volume1/dev/                    # 개발 프로젝트 루트
├── projects/                    # 프로젝트 폴더
│   └── nestjs-app/             # NestJS 애플리케이션
├── scripts/                     # 배포 스크립트
├── docker-compose/              # Docker Compose 파일들
└── logs/                        # 로그 파일들
```

### 3. 환경 변수 설정
```bash
# .env 파일 생성
cat > /volume1/dev/.env << 'EOF'
# Synology 환경 설정
SYNOLOGY_HOST=crossman.synology.me
SYNOLOGY_USER=admin
SYNOLOGY_SSH_PORT=22

# Docker 설정
DOCKER_NETWORK=dev-network
DOCKER_REGISTRY=localhost:5000

# 프로젝트 설정
PROJECT_NAME=nestjs-app
PROJECT_VERSION=1.0.0
PROJECT_PORT=3000
EOF
```

---

## 프로젝트 구조

### Dockerfile (NestJS 예제)
```dockerfile
FROM node:20-alpine

# 작업 디렉토리 설정
WORKDIR /app

# 포트 노출
EXPOSE 3000

# pnpm 설치
RUN npm install -g pnpm

# 패키지 파일 복사 및 설치
COPY package*.json ./
RUN pnpm install

# 소스 코드 복사
COPY . .

# 빌드
RUN pnpm run build

# 애플리케이션 실행
CMD ["node", "dist/main.js"]
```

### docker-compose.yml
```yaml
version: '3.8'

services:
  nestjs-app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nestjs-app
    ports:
      - "3000:3000"
    volumes:
      - ./dist:/app/dist
      - ./logs:/app/logs
    environment:
      - NODE_ENV=production
      - DB_HOST=${DB_HOST:-localhost}
      - DB_PORT=${DB_PORT:-5432}
      - DB_NAME=${DB_NAME:-nestjs}
      - DB_USER=${DB_USER:-postgres}
      - DB_PASSWORD=${DB_PASSWORD:-password}
    restart: unless-stopped
    networks:
      - dev-network

networks:
  dev-network:
    driver: bridge
```

---

## 배포 스크립트

### 1. 메인 배포 스크립트 (deploy.sh)
```bash
#!/bin/bash

# 로그 디렉토리 생성
mkdir -p /volume1/dev/logs

# 로그 파일 설정
LOG_FILE="/volume1/dev/logs/$(date +%y%m%d%H%M%S)_${PROJECT_NAME:-deploy}.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Docker 배포 스크립트 시작 ==="
echo "시작 시간: $(date)"

# 환경 변수 로드
source /volume1/dev/.env

# 함수 정의
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되어 있지 않습니다."
        exit 1
    fi
    log_info "Docker 버전: $(docker --version)"
}

# 배포 함수
deploy_application() {
    local project_dir="$1"
    local project_name="$2"
    local project_version="$3"
    local project_port="$4"
    
    log_info "프로젝트 배포 시작: $project_name"
    
    # 프로젝트 디렉토리로 이동
    cd "$project_dir" || {
        log_error "프로젝트 디렉토리를 찾을 수 없습니다: $project_dir"
        exit 1
    }
    
    # 기존 컨테이너 중지 및 제거
    if docker ps -a --format 'table {{.Names}}' | grep -q "^$project_name$"; then
        log_info "기존 컨테이너 중지 및 제거: $project_name"
        docker stop "$project_name"
        docker rm "$project_name"
    fi
    
    # 기존 이미지 제거
    if docker images --format 'table {{.Repository}}:{{.Tag}}' | grep -q "^$project_name:$project_version$"; then
        log_info "기존 이미지 제거: $project_name:$project_version"
        docker rmi "$project_name:$project_version"
    fi
    
    # 새 이미지 빌드
    log_info "Docker 이미지 빌드 시작"
    docker build -t "$project_name:$project_version" .
    
    if [ $? -eq 0 ]; then
        log_info "Docker 이미지 빌드 완료"
    else
        log_error "Docker 이미지 빌드 실패"
        exit 1
    fi
    
    # 컨테이너 실행
    log_info "컨테이너 실행 시작"
    docker run -d \
        --name "$project_name" \
        --restart unless-stopped \
        -p "$project_port:$project_port" \
        -v "$(pwd)/dist:/app/dist" \
        -v "$(pwd)/logs:/app/logs" \
        -e NODE_ENV=production \
        -e DB_HOST="${DB_HOST:-localhost}" \
        -e DB_PORT="${DB_PORT:-5432}" \
        -e DB_NAME="${DB_NAME:-nestjs}" \
        -e DB_USER="${DB_USER:-postgres}" \
        -e DB_PASSWORD="${DB_PASSWORD:-password}" \
        "$project_name:$project_version"
    
    if [ $? -eq 0 ]; then
        log_info "컨테이너 실행 완료"
        log_info "애플리케이션 URL: http://$SYNOLOGY_HOST:$project_port"
    else
        log_error "컨테이너 실행 실패"
        exit 1
    fi
}

# 헬스 체크
health_check() {
    local project_name="$1"
    local project_port="$2"
    local max_attempts=30
    local attempt=1
    
    log_info "헬스 체크 시작"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "http://localhost:$project_port/health" > /dev/null 2>&1; then
            log_info "헬스 체크 성공 (시도: $attempt/$max_attempts)"
            return 0
        fi
        
        log_info "헬스 체크 대기 중... (시도: $attempt/$max_attempts)"
        sleep 5
        ((attempt++))
    done
    
    log_error "헬스 체크 실패"
    return 1
}

# 메인 실행
main() {
    check_docker
    
    # 프로젝트 설정
    PROJECT_DIR="/volume1/dev/projects/${PROJECT_NAME:-nestjs-app}"
    PROJECT_NAME="${PROJECT_NAME:-nestjs-app}"
    PROJECT_VERSION="${PROJECT_VERSION:-1.0.0}"
    PROJECT_PORT="${PROJECT_PORT:-3000}"
    
    # 배포 실행
    deploy_application "$PROJECT_DIR" "$PROJECT_NAME" "$PROJECT_VERSION" "$PROJECT_PORT"
    
    # 헬스 체크
    health_check "$PROJECT_NAME" "$PROJECT_PORT"
    
    log_info "배포 완료"
    echo "완료 시간: $(date)"
}

# 스크립트 실행
main "$@"
```

### 2. Docker Compose 배포 스크립트 (deploy-compose.sh)
```bash
#!/bin/bash

# 로그 설정
LOG_FILE="/volume1/dev/logs/$(date +%y%m%d%H%M%S)_compose-deploy.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Docker Compose 배포 스크립트 시작 ==="
echo "시작 시간: $(date)"

# 환경 변수 로드
source /volume1/dev/.env

# 함수 정의
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Docker Compose 배포
deploy_compose() {
    local project_dir="$1"
    local compose_file="$2"
    
    log_info "Docker Compose 배포 시작"
    
    cd "$project_dir" || {
        log_error "프로젝트 디렉토리를 찾을 수 없습니다: $project_dir"
        exit 1
    }
    
    # 기존 서비스 중지 및 제거
    if [ -f "$compose_file" ]; then
        log_info "기존 서비스 중지 및 제거"
        docker-compose -f "$compose_file" down --remove-orphans
    fi
    
    # 새 서비스 시작
    log_info "새 서비스 시작"
    docker-compose -f "$compose_file" up -d --build
    
    if [ $? -eq 0 ]; then
        log_info "Docker Compose 배포 완료"
    else
        log_error "Docker Compose 배포 실패"
        exit 1
    fi
}

# 메인 실행
main() {
    PROJECT_DIR="/volume1/dev/projects/${PROJECT_NAME:-nestjs-app}"
    COMPOSE_FILE="docker-compose.yml"
    
    deploy_compose "$PROJECT_DIR" "$COMPOSE_FILE"
    
    log_info "배포 완료"
    echo "완료 시간: $(date)"
}

main "$@"
```

---

## Docker 관리 스크립트

### 1. 컨테이너 업데이트 스크립트 (update.sh)
```bash
#!/bin/bash

# 로그 설정
LOG_FILE="/volume1/dev/logs/$(date +%y%m%d%H%M%S)_update.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Docker 컨테이너 업데이트 스크립트 ==="
echo "시작 시간: $(date)"

# 환경 변수 로드
source /volume1/dev/.env

# 함수 정의
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

update_container() {
    local container_name="$1"
    
    log_info "컨테이너 업데이트 시작: $container_name"
    
    # 이미지 풀
    docker-compose pull "$container_name"
    
    # 컨테이너 재시작
    docker-compose up -d "$container_name"
    
    log_info "컨테이너 업데이트 완료: $container_name"
}

# 모든 컨테이너 업데이트
update_all() {
    cd "/volume1/dev/projects/${PROJECT_NAME:-nestjs-app}" || exit 1
    
    docker-compose pull
    docker-compose up -d
    
    log_info "모든 컨테이너 업데이트 완료"
}

# 메인 실행
if [ "$1" = "all" ]; then
    update_all
elif [ -n "$1" ]; then
    update_container "$1"
else
    echo "사용법: $0 [container_name|all]"
    exit 1
fi
```

### 2. 컨테이너 백업 스크립트 (backup.sh)
```bash
#!/bin/bash

# 로그 설정
LOG_FILE="/volume1/dev/logs/$(date +%y%m%d%H%M%S)_backup.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Docker 컨테이너 백업 스크립트 ==="
echo "시작 시간: $(date)"

# 환경 변수 로드
source /volume1/dev/.env

# 백업 디렉토리 생성
BACKUP_DIR="/volume1/dev/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# 함수 정의
log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

backup_container() {
    local container_name="$1"
    local backup_file="$BACKUP_DIR/${container_name}_$(date +%Y%m%d_%H%M%S).tar"
    
    log_info "컨테이너 백업 시작: $container_name"
    
    # 컨테이너 이미지 백업
    docker save "$container_name" > "$backup_file"
    
    if [ $? -eq 0 ]; then
        log_info "컨테이너 백업 완료: $backup_file"
    else
        log_error "컨테이너 백업 실패: $container_name"
    fi
}

# 볼륨 백업
backup_volumes() {
    local project_dir="/volume1/dev/projects/${PROJECT_NAME:-nestjs-app}"
    local volume_backup="$BACKUP_DIR/volumes_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    log_info "볼륨 백업 시작"
    
    tar -czf "$volume_backup" -C "$project_dir" .
    
    if [ $? -eq 0 ]; then
        log_info "볼륨 백업 완료: $volume_backup"
    else
        log_error "볼륨 백업 실패"
    fi
}

# 메인 실행
backup_container "${PROJECT_NAME:-nestjs-app}"
backup_volumes

log_info "백업 완료"
echo "완료 시간: $(date)"
```

### 3. 컨테이너 모니터링 스크립트 (monitor.sh)
```bash
#!/bin/bash

# 환경 변수 로드
source /volume1/dev/.env

# 함수 정의
show_status() {
    echo "=== Docker 컨테이너 상태 ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
}

show_logs() {
    local container_name="$1"
    local lines="${2:-50}"
    
    echo "=== $container_name 로그 (최근 $lines 줄) ==="
    docker logs --tail "$lines" "$container_name"
    echo
}

show_resources() {
    echo "=== 시스템 리소스 사용량 ==="
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
    echo
}

# 메인 실행
case "$1" in
    status)
        show_status
        ;;
    logs)
        show_logs "${2:-${PROJECT_NAME:-nestjs-app}}" "${3:-50}"
        ;;
    resources)
        show_resources
        ;;
    *)
        echo "사용법: $0 [status|logs|resources] [container_name] [lines]"
        exit 1
        ;;
esac
```

---

## 사용 방법

### 1. 스크립트 설치
```bash
# SSH로 시놀로지 접속
ssh -p 22 admin@crossman.synology.me

# 스크립트 디렉토리 생성
mkdir -p /volume1/dev/scripts

# 스크립트 파일 생성 및 권한 설정
chmod +x /volume1/dev/scripts/*.sh
```

### 2. 배포 실행
```bash
# 단일 컨테이너 배포
/volume1/dev/scripts/deploy.sh

# Docker Compose 배포
/volume1/dev/scripts/deploy-compose.sh

# 컨테이너 업데이트
/volume1/dev/scripts/update.sh nestjs-app

# 모든 컨테이너 업데이트
/volume1/dev/scripts/update.sh all
```

### 3. 모니터링
```bash
# 컨테이너 상태 확인
/volume1/dev/scripts/monitor.sh status

# 로그 확인
/volume1/dev/scripts/monitor.sh logs nestjs-app

# 리소스 사용량 확인
/volume1/dev/scripts/monitor.sh resources
```

### 4. 백업
```bash
# 컨테이너 및 볼륨 백업
/volume1/dev/scripts/backup.sh
```

### 5. 작업 스케줄러 설정
```bash
# DSM → 제어판 → 작업 스케줄러 → 생성 → 사용자 정의 스크립트

# 매일 자정 백업
0 0 * * * /volume1/dev/scripts/backup.sh

# 매주 일요일 업데이트
0 2 * * 0 /volume1/dev/scripts/update.sh all
```

---

## 트러블슈팅

### 1. Docker 명령어 찾을 수 없음
```bash
# 해결법 1: PATH 설정
export PATH=$PATH:/usr/local/bin

# 해결법 2: 절대 경로 사용
/usr/local/bin/docker ps

# 해결법 3: 심볼릭 링크 생성
ln -s /usr/local/bin/docker /usr/bin/docker
```

### 2. 권한 문제
```bash
# Docker 그룹에 사용자 추가
sudo usermod -aG docker $USER

# 또는 sudo 사용
sudo docker ps
```

### 3. 포트 충돌
```bash
# 포트 사용 확인
netstat -tuln | grep :3000

# 사용 중인 포트 변경
docker run -p 3001:3000 ...
```

### 4. 볼륨 마운트 문제
```bash
# 절대 경로 사용
-v /volume1/dev/data:/app/data

# 권한 확인
ls -la /volume1/dev/data
```

### 5. 로그 확인
```bash
# 컨테이너 로그
docker logs nestjs-app

# 시스템 로그
tail -f /var/log/messages

# 배포 로그
tail -f /volume1/dev/logs/*.log
```

---

## 추가 기능

### 1. 원격 배포
```bash
# 원격 서버에서 배포
ssh -p 22 admin@crossman.synology.me '/volume1/dev/scripts/deploy.sh'
```

### 2. 환경별 배포
```bash
# 개발 환경
ENV=development /volume1/dev/scripts/deploy.sh

# 운영 환경
ENV=production /volume1/dev/scripts/deploy.sh
```

### 3. 롤백 기능
```bash
# 이전 버전으로 롤백
docker tag nestjs-app:1.0.0 nestjs-app:rollback
docker stop nestjs-app
docker run -d --name nestjs-app nestjs-app:rollback
```

이 가이드를 통해 시놀로지 NAS에서 Docker 컨테이너를 CLI로 효율적으로 배포하고 관리할 수 있습니다.