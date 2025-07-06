#!/bin/bash
# 로컬 ↔ NAS 동기화 스크립트 (Linux/WSL)
# VSCode 작업 → NAS 배포 자동화

# 설정 변수
LOCAL_PATH="$(pwd)"
NAS_HOST="crossman@192.168.0.5"
NAS_PATH="/volume1/dev/CPSE"
NAS_PORT="22022"
GIT_REPO="https://github.com/crossman73/DCEC.git"

# 색상 출력 함수
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 네트워크 연결 확인
test_nas_connection() {
    log_info "NAS 연결 상태 확인 중..."
    
    # SSH 연결 테스트
    if ssh -p $NAS_PORT -o ConnectTimeout=5 $NAS_HOST "echo 'SSH 연결 성공'" 2>/dev/null; then
        log_success "NAS SSH 연결 성공: $NAS_HOST"
        return 0
    else
        log_error "NAS SSH 연결 실패. OpenVPN 연결 또는 인증 정보를 확인하세요."
        return 1
    fi
}

# 로컬 Git 상태 확인
get_git_status() {
    log_info "Git 상태 확인 중..."
    
    # Git 상태 확인
    if git status --porcelain | grep -q .; then
        log_warning "Git 작업 디렉토리에 변경사항이 있습니다:"
        git status --short
        return 1
    else
        log_success "Git 작업 디렉토리가 깨끗합니다."
        return 0
    fi
}

# Git 커밋 및 푸시
sync_git_changes() {
    local commit_message="$1"
    
    log_info "Git 동기화 시작..."
    
    # 변경사항 스테이징
    git add .
    log_success "변경사항 스테이징 완료"
    
    # 커밋
    if git commit -m "$commit_message"; then
        log_success "커밋 완료: $commit_message"
    else
        log_info "커밋할 변경사항이 없습니다."
    fi
    
    # 푸시
    if git push origin master; then
        log_success "GitHub 푸시 완료"
        return 0
    else
        log_error "GitHub 푸시 실패"
        return 1
    fi
}

# NAS에 직접 동기화 (SCP)
sync_to_nas_directly() {
    log_info "NAS로 직접 동기화 시작..."
    
    # NAS에서 디렉토리 생성
    ssh -p $NAS_PORT $NAS_HOST "mkdir -p $NAS_PATH"
    
    # SCP로 파일 복사
    log_info "파일 전송 중..."
    if scp -P $NAS_PORT -r ./* ${NAS_HOST}:${NAS_PATH}/; then
        log_success "NAS 동기화 완료"
        return 0
    else
        log_error "NAS 동기화 실패"
        return 1
    fi
}

# NAS에서 Git Pull
sync_nas_from_git() {
    log_info "NAS에서 Git Pull 실행..."
    
    # NAS에서 Git 저장소 확인 및 동기화
    ssh -p $NAS_PORT $NAS_HOST << 'EOF'
# Git 저장소 확인
if [ ! -d "/volume1/dev/CPSE/.git" ]; then
    echo "Git 저장소 초기화 중..."
    mkdir -p /volume1/dev/CPSE
    cd /volume1/dev/CPSE
    git clone https://github.com/crossman73/DCEC.git .
else
    echo "기존 Git 저장소에서 Pull 실행..."
    cd /volume1/dev/CPSE
    git pull origin master
fi

# 권한 설정
chmod +x *.sh
echo "NAS Git 동기화 완료"
EOF
    
    if [ $? -eq 0 ]; then
        log_success "NAS Git 동기화 완료"
        return 0
    else
        log_error "NAS Git 동기화 실패"
        return 1
    fi
}

# Docker 컨테이너 재시작
restart_nas_docker_services() {
    log_info "NAS Docker 서비스 재시작..."
    
    ssh -p $NAS_PORT $NAS_HOST << 'EOF'
cd /volume1/dev/CPSE

# Docker Compose 실행
if [ -f "docker-compose.yml" ]; then
    echo "Docker Compose 재시작 중..."
    docker-compose down
    docker-compose up -d
    
    echo "컨테이너 상태 확인..."
    docker-compose ps
else
    echo "docker-compose.yml 파일이 없습니다."
fi

# 개별 서비스 상태 확인
echo "서비스 포트 확인..."
ss -tlnp | grep -E "(5678|31002|31003|8484|3000|5001)"
EOF
    
    if [ $? -eq 0 ]; then
        log_success "Docker 서비스 재시작 완료"
        return 0
    else
        log_error "Docker 서비스 재시작 실패"
        return 1
    fi
}

# 동기화 상태 확인
get_sync_status() {
    log_info "동기화 상태 확인 중..."
    
    # 로컬 Git 상태
    log_info "=== 로컬 Git 상태 ==="
    git status --short
    local_commit=$(git rev-parse HEAD)
    log_info "로컬 커밋: ${local_commit:0:8}"
    
    # NAS 연결 가능한 경우 NAS 상태 확인
    if test_nas_connection; then
        log_info "=== NAS 상태 ==="
        
        ssh -p $NAS_PORT $NAS_HOST << 'EOF'
cd /volume1/dev/CPSE 2>/dev/null || { echo "NAS 디렉토리가 존재하지 않습니다."; exit 1; }

echo "NAS 디렉토리 내용:"
ls -la

if [ -d ".git" ]; then
    echo "NAS Git 커밋: $(git rev-parse HEAD | cut -c1-8)"
    echo "NAS Git 상태:"
    git status --short
else
    echo "NAS에 Git 저장소가 없습니다."
fi

echo "Docker 컨테이너 상태:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
EOF
    fi
}

# 완전 동기화 워크플로우
start_full_sync() {
    local commit_message="$1"
    local force_sync="$2"
    
    log_step "🔄 전체 동기화 워크플로우 시작"
    log_step "================================="
    
    # 1. 네트워크 연결 확인
    if ! test_nas_connection; then
        log_error "NAS 연결 실패. 동기화를 중단합니다."
        return 1
    fi
    
    # 2. Git 상태 확인
    if [ "$force_sync" != "true" ] && ! get_git_status; then
        read -p "변경사항이 있습니다. 계속하시겠습니까? (y/N): " response
        if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
            log_warning "동기화가 취소되었습니다."
            return 1
        fi
    fi
    
    # 3. Git 커밋 및 푸시
    if sync_git_changes "$commit_message"; then
        log_success "✅ 1단계: Git 동기화 완료"
    else
        log_error "❌ 1단계: Git 동기화 실패"
        return 1
    fi
    
    # 4. NAS에서 Git Pull
    if sync_nas_from_git; then
        log_success "✅ 2단계: NAS Git 동기화 완료"
    else
        log_error "❌ 2단계: NAS Git 동기화 실패"
        log_warning "직접 동기화로 전환합니다..."
        
        if sync_to_nas_directly; then
            log_success "✅ 2단계(대체): 직접 동기화 완료"
        else
            log_error "❌ 2단계(대체): 직접 동기화 실패"
            return 1
        fi
    fi
    
    # 5. Docker 서비스 재시작
    if restart_nas_docker_services; then
        log_success "✅ 3단계: Docker 서비스 재시작 완료"
    else
        log_error "❌ 3단계: Docker 서비스 재시작 실패"
    fi
    
    log_success "🎉 전체 동기화 완료!"
    return 0
}

# 도움말 표시
show_help() {
    cat << 'EOF'
🔄 로컬 ↔ NAS 동기화 스크립트
==============================

사용법: ./sync-to-nas.sh <명령어> [옵션]

명령어:
  sync [메시지]    전체 동기화 워크플로우 실행 (Git → NAS → Docker)
  git [메시지]     Git 커밋 및 푸시만 실행
  docker           NAS Docker 서비스 재시작만 실행
  status           로컬 및 NAS 동기화 상태 확인
  help             이 도움말 표시

예시:
  ./sync-to-nas.sh sync
  ./sync-to-nas.sh sync "서브도메인 설정 업데이트"
  ./sync-to-nas.sh git "스크립트 수정"
  ./sync-to-nas.sh status
  ./sync-to-nas.sh docker

작업 흐름:
  [VSCode 로컬] → [Git Push] → [NAS Git Pull] → [Docker 재시작]
  로컬 CPSE      →  GitHub    →  /volume1/dev/CPSE  →  서비스 갱신

EOF
}

# 메인 실행 로직
case "$1" in
    "sync")
        message="${2:-Auto sync from local to NAS}"
        start_full_sync "$message" "$3"
        ;;
    "git")
        message="${2:-Auto commit from local}"
        if test_nas_connection; then
            sync_git_changes "$message"
        fi
        ;;
    "docker")
        if test_nas_connection; then
            restart_nas_docker_services
        fi
        ;;
    "status")
        get_sync_status
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
