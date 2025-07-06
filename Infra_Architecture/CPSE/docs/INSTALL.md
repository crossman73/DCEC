# NAS-SubDomain-Manager 설치 가이드

## 🚀 빠른 시작

### 1. 시스템 요구사항 확인

```bash
# DSM 버전 확인 (7.0 이상 필요)
cat /etc.defaults/VERSION | grep majorversion

# Docker 서비스 상태 확인
docker info

# 디스크 공간 확인 (최소 5GB 필요)
df -h
```

### 2. 프로젝트 다운로드

```bash
# Git 클론 (Git이 설치된 경우)
git clone <repository-url> nas-subdomain-manager
cd nas-subdomain-manager

# 또는 수동으로 파일 복사
mkdir -p nas-subdomain-manager
# 모든 파일을 nas-subdomain-manager 디렉토리에 복사
```

### 3. 초기 설정

```bash
# 스크립트 실행 권한 부여 (Linux/Mac)
find . -name "*.sh" -exec chmod +x {} \;

# main.sh 실행 권한 부여
chmod +x main.sh

# 환경 설정 확인
./main.sh setup
```

### 4. 전체 설치

```bash
# 전체 시스템 설치 (승인 필요)
./main.sh install
```

## 📋 단계별 설치 가이드

### 단계 1: 환경 준비

1. **시놀로지 NAS 접속**
   ```bash
   ssh admin@your-nas-ip
   ```

2. **Docker 설치 확인**
   - DSM → 패키지 센터 → Docker 설치
   - 또는 CLI에서 확인: `docker --version`

3. **작업 디렉토리 생성**
   ```bash
   mkdir -p /volume1/docker/nas-subdomain-manager
   cd /volume1/docker/nas-subdomain-manager
   ```

### 단계 2: 설정 파일 구성

1. **.env 파일 편집**
   ```bash
   # 자동 생성된 .env 파일 확인
   cat .env
   
   # 필요시 수정
   nano .env
   ```

2. **주요 설정 항목**
   ```bash
   DOMAIN_NAME=crossman.synology.me
   SERVICES=mcp,uptime-kuma,code-server,gitea,dsm,portainer
   TIMEZONE=Asia/Seoul
   SSL_EMAIL=admin@crossman.synology.me
   ```

### 단계 3: 네트워크 설정

1. **방화벽 규칙 확인**
   ```bash
   # 필요한 포트 열기
   # 80, 443 (HTTP/HTTPS)
   # 3000 (Gitea)
   # 3001 (Uptime Kuma)
   # 8080 (Code Server)
   # 9000 (Portainer)
   ```

2. **DNS 설정 확인**
   - Cloudflare 또는 DNS 제공업체에서 서브도메인 설정
   - A 레코드: *.crossman.synology.me → NAS IP

### 단계 4: 서비스 설치

1. **승인 시스템 이해**
   ```bash
   # 설치 명령 실행
   ./main.sh install
   
   # 승인 요청이 나타나면 신중히 검토 후 승인
   # 설치: INSTALL_CONFIRMED 입력
   ```

2. **설치 진행 모니터링**
   ```bash
   # 다른 터미널에서 로그 모니터링
   tail -f logs/main.log
   ```

### 단계 5: 설치 후 확인

1. **서비스 상태 확인**
   ```bash
   ./main.sh status
   ```

2. **웹 접속 테스트**
   - Portainer: http://portainer.crossman.synology.me
   - Uptime Kuma: http://uptime.crossman.synology.me
   - Code Server: http://code.crossman.synology.me
   - Gitea: http://git.crossman.synology.me

3. **로그 확인**
   ```bash
   ./main.sh logs
   ```

## 🔧 고급 설치 옵션

### 개별 구성 요소 설치

```bash
# 환경 설정만
./main.sh setup

# 서비스만 시작
./main.sh start

# 보안 설정만
./scripts/security/firewall.sh
```

### 테스트 모드 설치

```bash
# 테스트 모드 활성화 (자동 승인)
./main.sh test-mode-on

# 설치 실행
./main.sh install

# 테스트 모드 비활성화
./main.sh test-mode-off
```

### 백업 기반 설치

```bash
# 기존 백업에서 복원
./main.sh restore

# 특정 백업 파일에서 복원
./scripts/maintenance/restore.sh restore /path/to/backup.tar.gz
```

## 🚨 문제 해결

### 설치 실패 시

1. **로그 확인**
   ```bash
   ./main.sh logs
   cat logs/main.log
   cat logs/approval.log
   ```

2. **시스템 상태 확인**
   ```bash
   ./main.sh status
   docker ps -a
   docker images
   ```

3. **권한 문제**
   ```bash
   # 실행 권한 재부여
   find . -name "*.sh" -exec chmod +x {} \;
   
   # 소유권 확인
   ls -la
   ```

### 서비스 접속 실패

1. **네트워크 확인**
   ```bash
   # 포트 리스닝 확인
   netstat -ln | grep :80
   netstat -ln | grep :443
   
   # 방화벽 상태 확인
   iptables -L
   ```

2. **DNS 확인**
   ```bash
   # DNS 해상도 확인
   nslookup portainer.crossman.synology.me
   ping portainer.crossman.synology.me
   ```

3. **SSL 인증서 확인**
   ```bash
   # SSL 인증서 상태 확인
   docker logs nginx-proxy-manager
   ```

### Docker 관련 문제

1. **Docker 서비스 재시작**
   ```bash
   sudo systemctl restart docker
   ```

2. **네트워크 문제**
   ```bash
   # Docker 네트워크 재생성
   docker network prune
   ./main.sh restart
   ```

3. **볼륨 문제**
   ```bash
   # 볼륨 확인
   docker volume ls
   docker volume inspect <volume_name>
   ```

## 📦 제거 가이드

### 완전 제거

```bash
# 모든 서비스 중지 및 제거
./main.sh stop
docker-compose down -v

# 이미지 제거
docker rmi $(docker images -q)

# 볼륨 제거 (주의: 데이터 손실)
docker volume prune

# 프로젝트 디렉토리 제거
cd ..
rm -rf nas-subdomain-manager
```

### 데이터 보존 제거

```bash
# 백업 생성
./main.sh backup

# 서비스만 중지
./main.sh stop

# 설정 파일만 제거
rm -f .env docker-compose.yml
```

## 🔄 업그레이드 가이드

### 일반 업그레이드

```bash
# 백업 생성
./main.sh backup

# 시스템 업데이트
./main.sh update
```

### 수동 업그레이드

```bash
# 1. 백업
./main.sh backup

# 2. 새 버전 다운로드
git pull origin main

# 3. 권한 재설정
find . -name "*.sh" -exec chmod +x {} \;

# 4. 설정 업데이트
./main.sh setup

# 5. 서비스 재시작
./main.sh restart
```

## 📞 지원 및 문의

### 로그 수집

```bash
# 지원 요청 시 포함할 정보
echo "=== 시스템 정보 ===" > support-info.txt
uname -a >> support-info.txt
docker --version >> support-info.txt
./main.sh status >> support-info.txt

echo "=== 서비스 상태 ===" >> support-info.txt
docker ps -a >> support-info.txt

echo "=== 최근 로그 ===" >> support-info.txt
tail -50 logs/main.log >> support-info.txt

echo "=== 승인 로그 ===" >> support-info.txt
tail -20 logs/approval.log >> support-info.txt
```

### 일반적인 질문

**Q: 설치 중 "승인이 필요합니다" 메시지가 나타납니다.**
A: 이는 정상적인 동작입니다. 각 작업의 위험도를 확인하고 적절한 승인 문구를 입력하세요.

**Q: 테스트 환경에서 승인을 건너뛸 수 있나요?**
A: `./main.sh test-mode-on` 명령으로 테스트 모드를 활성화하면 자동 승인됩니다.

**Q: 백업은 어떻게 스케줄링하나요?**
A: cron을 사용하여 정기 백업을 설정할 수 있습니다:
```bash
echo "0 2 * * * cd /path/to/nas-subdomain-manager && ./main.sh backup" >> /etc/crontab
```

**Q: 특정 서비스만 관리할 수 있나요?**
A: `.env` 파일의 `SERVICES` 변수를 수정하여 원하는 서비스만 포함시킬 수 있습니다.
