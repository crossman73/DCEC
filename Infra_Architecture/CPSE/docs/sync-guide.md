# 🔄 로컬 ↔ NAS 동기화 시스템 가이드

## 개요

VSCode 로컬 개발환경에서 시놀로지 NAS로 자동 배포하는 통합 동기화 시스템입니다.

## 🏗️ 동기화 구조

```
[VSCode 로컬 개발]
       ↓
[Git 커밋 & 푸시]
       ↓
[GitHub 원격 저장소]
       ↓
[NAS Git Pull]
       ↓
[Docker 서비스 재시작]
       ↓
[서브도메인 서비스 갱신]
```

## 📁 디렉토리 매핑

| 환경 | 경로 | 설명 |
|------|------|------|
| **로컬** | `D:\Dev\DCEC\Infra_Architecture\CPSE` | VSCode 작업 디렉토리 |
| **NAS** | `/volume1/dev/CPSE` | 운영 환경 디렉토리 |
| **Git** | `https://github.com/crossman73/DCEC.git` | 중앙 저장소 |

## 🚀 동기화 방법

### 1. 통합 자동 동기화 (권장)

#### Windows PowerShell
```powershell
# 전체 동기화 (Git → NAS → Docker)
.\sync-to-nas.ps1 -Action sync

# 커밋 메시지 지정
.\sync-to-nas.ps1 -Action sync -Message "서브도메인 설정 업데이트"

# 강제 동기화 (확인 없이)
.\sync-to-nas.ps1 -Action sync -Force
```

#### Linux/WSL
```bash
# 전체 동기화
./sync-to-nas.sh sync

# 커밋 메시지 지정
./sync-to-nas.sh sync "서브도메인 설정 업데이트"

# 강제 동기화
./sync-to-nas.sh sync "메시지" force
```

### 2. 단계별 동기화

#### Git 동기화만
```bash
# PowerShell
.\sync-to-nas.ps1 -Action git -Message "스크립트 수정"

# Linux/WSL
./sync-to-nas.sh git "스크립트 수정"
```

#### Docker 재시작만
```bash
# PowerShell
.\sync-to-nas.ps1 -Action docker

# Linux/WSL
./sync-to-nas.sh docker
```

#### 동기화 상태 확인
```bash
# PowerShell
.\sync-to-nas.ps1 -Action status

# Linux/WSL
./sync-to-nas.sh status
```

## 🔧 동기화 워크플로우

### 자동 동기화 단계

1. **네트워크 연결 확인**
   - NAS SSH 접속 테스트
   - OpenVPN 연결 상태 확인

2. **Git 상태 확인**
   - 로컬 변경사항 확인
   - 사용자 승인 요청 (필요시)

3. **Git 동기화**
   - 변경사항 스테이징 (`git add .`)
   - 커밋 생성 (`git commit -m`)
   - GitHub 푸시 (`git push origin master`)

4. **NAS 동기화**
   - NAS에서 Git Pull 실행
   - 실패 시 SCP 직접 전송으로 대체

5. **Docker 서비스 재시작**
   - Docker Compose 재시작
   - 서비스 상태 확인
   - 포트 바인딩 확인

## 📊 서비스 포트 매핑

| 서비스 | 서브도메인 | 외부 포트 | 내부 포트 | 컨테이너 |
|--------|------------|-----------|-----------|----------|
| **n8n** | n8n.crossman.synology.me | 31001 | 5678 | cpse_n8n |
| **MCP** | mcp.crossman.synology.me | 31002 | 31002 | cpse_mcp |
| **Uptime** | uptime.crossman.synology.me | 31003 | 3001 | cpse_uptime |
| **Code** | code.crossman.synology.me | 8484 | 8080 | cpse_code |
| **Gitea** | git.crossman.synology.me | 3000 | 3000 | cpse_gitea |
| **DSM** | dsm.crossman.synology.me | 5001 | 5001 | (DSM 내장) |

## 🔒 보안 설정

### 네트워크 보안 정책
- **내부 네트워크 (192.168.0.x)**: 직접 접속 허용
- **외부 네트워크**: OpenVPN 필수
- **모든 서브도메인**: HTTPS(443) → HTTP(내부포트) 매핑

### 인증 정보
```bash
# SSH 키 설정 (권장)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/nas_rsa
ssh-copy-id -i ~/.ssh/nas_rsa.pub -p 22022 crossman@192.168.0.5

# SSH 설정 (~/.ssh/config)
Host nas
    HostName 192.168.0.5
    Port 22022
    User crossman
    IdentityFile ~/.ssh/nas_rsa
```

## 🛠️ 수동 동기화 방법

### 1. SCP 직접 전송
```bash
# PowerShell
scp -P 22022 -r D:\Dev\DCEC\Infra_Architecture\CPSE\* crossman@192.168.0.5:/volume1/dev/CPSE/

# Linux/WSL
scp -P 22022 -r ./* crossman@192.168.0.5:/volume1/dev/CPSE/
```

### 2. rsync 동기화
```bash
# Linux/WSL에서 rsync 사용
rsync -avz -e "ssh -p 22022" ./ crossman@192.168.0.5:/volume1/dev/CPSE/
```

### 3. NAS에서 직접 Git Pull
```bash
# NAS SSH 접속
ssh -p 22022 crossman@192.168.0.5

# Git 저장소 초기화 (최초 1회만)
mkdir -p /volume1/dev/CPSE
cd /volume1/dev/CPSE
git clone https://github.com/crossman73/DCEC.git .

# 정기적인 업데이트
cd /volume1/dev/CPSE
git pull origin master
chmod +x *.sh
```

## 🐳 Docker 관리

### Docker Compose 명령어
```bash
# NAS SSH 접속 후
cd /volume1/dev/CPSE

# 모든 서비스 시작
docker-compose up -d

# 특정 서비스 재시작
docker-compose restart n8n

# 서비스 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f n8n

# 모든 서비스 중지
docker-compose down
```

### 개별 서비스 관리
```bash
# n8n 서비스 관리
docker-compose up -d n8n
docker-compose restart n8n
docker-compose logs n8n

# 모든 서비스 강제 재생성
docker-compose down
docker-compose up -d --force-recreate
```

## 🔍 문제 해결

### 1. SSH 연결 실패
```bash
# 네트워크 연결 확인
./network-check.sh check

# OpenVPN 연결 확인
./network-check.sh vpn

# SSH 키 권한 확인
chmod 600 ~/.ssh/nas_rsa
```

### 2. Git 동기화 실패
```bash
# Git 상태 확인
git status

# 충돌 해결 후 다시 시도
git add .
git commit -m "충돌 해결"
git push origin master
```

### 3. Docker 서비스 실패
```bash
# NAS에서 Docker 상태 확인
docker ps -a
docker-compose ps

# 로그 확인
docker-compose logs [서비스명]

# 네트워크 확인
docker network ls
```

## 📈 모니터링

### 동기화 상태 확인
```bash
# 전체 상태 확인
./sync-to-nas.sh status

# 개별 서비스 상태
./reverse-proxy-manager.sh status
```

### 로그 확인
```bash
# NAS 로그 확인
ssh -p 22022 crossman@192.168.0.5 "tail -f /volume1/dev/CPSE/logs/*.log"

# Docker 로그 확인
ssh -p 22022 crossman@192.168.0.5 "cd /volume1/dev/CPSE && docker-compose logs -f"
```

## 🎯 권장 작업 패턴

### 1. 일반적인 개발 사이클
```bash
# 1. 로컬에서 개발 작업
code .

# 2. 테스트 및 검증
./network-check.sh check

# 3. 전체 동기화
./sync-to-nas.sh sync "기능 업데이트"

# 4. 서비스 상태 확인
./sync-to-nas.sh status
```

### 2. 긴급 배포
```bash
# 강제 동기화 (확인 없이)
./sync-to-nas.sh sync "긴급 수정" force

# 또는 PowerShell
.\sync-to-nas.ps1 -Action sync -Message "긴급 수정" -Force
```

### 3. 개발 환경별 관리
```bash
# 개발 브랜치 작업
git checkout -b feature/new-subdomain
# 작업 후
git push origin feature/new-subdomain

# 운영 배포
git checkout master
git merge feature/new-subdomain
./sync-to-nas.sh sync "새 서브도메인 추가"
```

이 동기화 시스템을 통해 로컬 개발에서 NAS 운영까지 끊김 없는 워크플로우를 구축할 수 있습니다!
