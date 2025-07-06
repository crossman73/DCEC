# NAS Docker Environment 배포 가이드

## 개요
이 가이드는 NAS(Synology DS920+)에 Docker를 사용하여 여러 서비스를 배포하는 방법을 안내합니다.

## 사전 준비사항

### 1. NAS 설정 확인
- NAS IP: 192.168.0.5
- SSH 포트: 22022 (기본값이 아니므로 주의)
- SSH 사용자: crossman
- SSH 키 기반 인증이 설정되어 있어야 함

### 2. SSH 키 설정 확인
```bash
# SSH 키가 있는지 확인
ls -la ~/.ssh/id_rsa.pub

# 없다면 생성
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# NAS에 공개키 복사
ssh-copy-id -p 22022 crossman@192.168.0.5
```

### 3. 파일 존재 확인
다음 파일들이 존재하는지 확인:
- `d:\Dev\DCEC\Dev_Env\Docker\.env`
- `d:\Dev\DCEC\Dev_Env\Docker\docker-compose.yml`
- `d:\Dev\DCEC\Dev_Env\Docker\nas-setup-complete.sh`
- `d:\Dev\DCEC\Dev_Env\Docker\n8n\20250626_n8n_API_KEY.txt`

## 배포 실행 방법

### 방법 1: Bash 스크립트 (권장)
```bash
# WSL 또는 Git Bash에서 실행
cd d:/Dev/DCEC/Dev_Env/Docker
./deploy-nas-final.sh

# 또는 특정 명령 실행
./deploy-nas-final.sh status    # 상태 확인
./deploy-nas-final.sh debug     # 디버그 정보
./deploy-nas-final.sh restart   # 서비스 재시작
```

### 방법 2: PowerShell 스크립트
```powershell
# PowerShell에서 실행
cd d:\Dev\DCEC\Dev_Env\Docker
.\deploy-nas-final.ps1
```

### 방법 3: 수동 실행 (SSH 직접 사용)
```bash
# 1. 디렉토리 생성
ssh -p 22022 crossman@192.168.0.5 "sudo mkdir -p /volume1/docker/dev"

# 2. 파일 전송
scp -P 22022 d:\Dev\DCEC\Dev_Env\Docker\.env crossman@192.168.0.5:/volume1/docker/dev/
scp -P 22022 d:\Dev\DCEC\Dev_Env\Docker\docker-compose.yml crossman@192.168.0.5:/volume1/docker/dev/
scp -P 22022 d:\Dev\DCEC\Dev_Env\Docker\nas-setup-complete.sh crossman@192.168.0.5:/volume1/docker/dev/
scp -P 22022 d:\Dev\DCEC\Dev_Env\Docker\n8n\20250626_n8n_API_KEY.txt crossman@192.168.0.5:/volume1/docker/dev/config/n8n/api-keys.txt

# 3. 권한 설정 및 셋업 스크립트 실행
ssh -p 22022 crossman@192.168.0.5 "cd /volume1/docker/dev && chmod +x nas-setup-complete.sh && ./nas-setup-complete.sh"

# 4. Docker 서비스 시작
ssh -p 22022 crossman@192.168.0.5 "cd /volume1/docker/dev && docker-compose up -d"

# 5. 상태 확인
ssh -p 22022 crossman@192.168.0.5 "cd /volume1/docker/dev && docker-compose ps"
```

## 배포될 서비스

### 서비스 목록
1. **n8n** - 워크플로우 자동화 (포트: 31001)
2. **Gitea** - Git 저장소 서버 (포트: 8484)
3. **Code Server** - 웹 기반 VS Code (포트: 3000)
4. **Uptime Kuma** - 서비스 모니터링 (포트: 31003)
5. **Portainer** - Docker 관리 (포트: 9000)
6. **MariaDB** - 데이터베이스 (내부 포트: 3306)

### 접속 URL
- n8n: http://192.168.0.5:31001
- Gitea: http://192.168.0.5:8484
- Code Server: http://192.168.0.5:3000
- Uptime Kuma: http://192.168.0.5:31003
- Portainer: http://192.168.0.5:9000

### 서브도메인 URL (DSM 리버스 프록시 설정 후)
- n8n: https://n8n.crossman.synology.me
- Gitea: https://git.crossman.synology.me
- Code Server: https://code.crossman.synology.me
- Uptime Kuma: https://uptime.crossman.synology.me

## 기본 인증 정보

### 서비스 계정
- **n8n**: admin / changeme123
- **Code Server**: changeme123
- **Database**: nasuser / changeme123

### 환경 변수
- `MYSQL_ROOT_PASSWORD`: changeme123
- `MYSQL_DATABASE`: nasdb
- `MYSQL_USER`: nasuser
- `MYSQL_PASSWORD`: changeme123

## 문제 해결

### 1. SSH 연결 실패
```bash
# SSH 연결 테스트
ssh -p 22022 crossman@192.168.0.5 "echo 'SSH works'"

# 포트 확인
nc -zv 192.168.0.5 22022
```

### 2. 파일 전송 실패
```bash
# 권한 확인
ssh -p 22022 crossman@192.168.0.5 "ls -la /volume1/docker/"

# 디렉토리 생성
ssh -p 22022 crossman@192.168.0.5 "sudo mkdir -p /volume1/docker/dev"
```

### 3. Docker 서비스 문제
```bash
# 서비스 상태 확인
ssh -p 22022 crossman@192.168.0.5 "cd /volume1/docker/dev && docker-compose ps"

# 로그 확인
ssh -p 22022 crossman@192.168.0.5 "cd /volume1/docker/dev && docker-compose logs"

# 서비스 재시작
ssh -p 22022 crossman@192.168.0.5 "cd /volume1/docker/dev && docker-compose restart"
```

### 4. 포트 접근 불가
```bash
# 포트 확인
netstat -tuln | grep -E "(31001|8484|3000|31003|9000)"

# 방화벽 확인 (NAS에서)
sudo iptables -L
```

## 배포 후 확인사항

### 1. 서비스 상태 확인
```bash
# 모든 서비스 실행 상태 확인
./deploy-nas-final.sh status

# 개별 서비스 로그 확인
./deploy-nas-final.sh logs n8n
./deploy-nas-final.sh logs gitea
```

### 2. 웹 접속 테스트
각 서비스 URL에 접속하여 정상 동작 확인

### 3. 데이터 백업 설정
- `/volume1/docker/dev/data` 디렉토리 정기 백업 설정
- 데이터베이스 덤프 자동화 설정

## 유지보수 명령어

```bash
# 서비스 시작
./deploy-nas-final.sh start

# 서비스 중지
./deploy-nas-final.sh stop

# 서비스 재시작
./deploy-nas-final.sh restart

# 상태 확인
./deploy-nas-final.sh status

# 디버그 정보
./deploy-nas-final.sh debug

# 서비스 정보 표시
./deploy-nas-final.sh info
```

## 보안 고려사항

1. **기본 비밀번호 변경**: changeme123을 강력한 비밀번호로 변경
2. **SSH 키 관리**: 정기적으로 SSH 키 갱신
3. **방화벽 설정**: 필요한 포트만 열어둠
4. **SSL 인증서**: Let's Encrypt 등을 통한 HTTPS 설정
5. **백업 암호화**: 데이터 백업 시 암호화 적용

## 참고 자료

- Synology DSM 리버스 프록시 설정 가이드
- Docker Compose 설정 가이드
- n8n 설정 및 사용법
- Gitea 관리자 가이드
