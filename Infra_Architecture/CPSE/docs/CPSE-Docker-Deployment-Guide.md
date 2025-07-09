# DCEC CPSE 도커 서비스 배포 가이드

## 1. 개요

이 문서는 DCEC 프로젝트의 CPSE(Code-server, n8n, Gitea) 서비스를 Docker로 배포하는 가이드입니다.

### 1.1 서비스 목록
- **n8n**: 워크플로우 자동화 도구 (포트: 5678)
- **code-server**: 웹 기반 VSCode (포트: 8080)  
- **gitea**: Git 저장소 서비스 (포트: 3000)
- **traefik**: 리버스 프록시 및 로드밸런서 (포트: 80, 443, 8000)

### 1.2 서브도메인 구성
- https://n8n.crossman.synology.me
- https://code.crossman.synology.me
- https://git.crossman.synology.me
- https://traefik.crossman.synology.me

## 2. 현재 상태 확인

### 2.1 SSH 연결 상태
- SSH 키 인증에 일시적 문제 발생
- 웹 UI를 통한 배포 진행 필요

### 2.2 서비스 상태 확인
```bash
# 현재 n8n, code-server 서비스 403 오류 발생
# 서비스가 실행되지 않았거나 리버스 프록시 설정 문제
```

## 3. 배포 방법

### 3.1 방법 1: SSH를 통한 배포 (권장)

SSH 연결이 복구되면 다음 명령어로 배포:

```bash
# NAS에 SSH 접속
ssh -p 22022 crossman@192.168.0.5

# 작업 디렉토리 생성
mkdir -p /volume1/docker/dcec-cpse
cd /volume1/docker/dcec-cpse

# docker-compose 파일 업로드 (SCP 또는 직접 편집)
# 단순 n8n 배포부터 시작
docker-compose -f n8n-simple.yml up -d

# 서비스 상태 확인
docker ps
docker logs dcec-n8n
```

### 3.2 방법 2: 웹 UI를 통한 배포

1. **DSM 접속**: http://192.168.0.5:5000
2. **Docker 패키지 열기**
3. **컨테이너 탭에서 생성**
4. **이미지 다운로드**: n8nio/n8n:latest
5. **컨테이너 생성 및 설정**:
   - 컨테이너 이름: dcec-n8n
   - 포트: 5678:5678
   - 환경변수 설정 (아래 참조)
   - 볼륨 마운트: /home/node/.n8n

### 3.3 방법 3: 파일 복사를 통한 배포

```powershell
# Windows에서 docker-compose 파일을 NAS로 복사
# SMB 공유를 통한 파일 복사
Copy-Item "c:\dev\DCEC\Infra_Architecture\CPSE\docker-configs\*.yml" "\\192.168.0.5\docker\"
```

## 4. n8n 서비스 상세 설정

### 4.1 환경변수
```env
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=dcec_n8n_2024
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://192.168.0.5:5678/
GENERIC_TIMEZONE=Asia/Seoul
DB_TYPE=sqlite
N8N_METRICS=true
N8N_LOG_LEVEL=info
```

### 4.2 포트 매핑
- 호스트: 5678
- 컨테이너: 5678

### 4.3 볼륨 마운트
- 데이터 볼륨: n8n_data → /home/node/.n8n
- 시간 동기화: /etc/localtime:/etc/localtime:ro

## 5. 배포 단계별 절차

### 5.1 1단계: n8n 단독 배포
```bash
# n8n 서비스만 먼저 배포
docker-compose -f n8n-simple.yml up -d

# 서비스 확인
curl http://192.168.0.5:5678
```

### 5.2 2단계: 서비스 접근 확인
```bash
# 로컬 접근 테스트
curl -I http://192.168.0.5:5678

# 기본 인증 테스트
curl -u admin:dcec_n8n_2024 http://192.168.0.5:5678
```

### 5.3 3단계: 리버스 프록시 설정
```bash
# 전체 서비스 배포 (Traefik 포함)
docker-compose -f docker-compose.yml up -d

# 도메인 접근 테스트
curl -I https://n8n.crossman.synology.me
```

## 6. 문제 해결

### 6.1 SSH 키 인증 문제
```bash
# 공개키 확인
cat ~/.ssh/id_rsa.pub

# authorized_keys 확인 및 수정
nano ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

### 6.2 도커 서비스 문제
```bash
# 컨테이너 상태 확인
docker ps -a

# 로그 확인
docker logs dcec-n8n

# 컨테이너 재시작
docker restart dcec-n8n
```

### 6.3 네트워크 접근 문제
```bash
# 포트 리스닝 확인
netstat -tuln | grep 5678

# 방화벽 확인
iptables -L | grep 5678
```

## 7. 배포 후 검증

### 7.1 서비스 상태 확인
- [ ] n8n 컨테이너 실행 중
- [ ] 포트 5678 리스닝 확인
- [ ] 웹 UI 접근 가능 (http://192.168.0.5:5678)
- [ ] 기본 인증 동작 확인

### 7.2 성능 및 안정성 확인
- [ ] 리소스 사용량 정상
- [ ] 로그에 오류 없음
- [ ] 재시작 정책 동작 확인

### 7.3 보안 확인
- [ ] 기본 인증 활성화
- [ ] 불필요한 포트 노출 없음
- [ ] 데이터 볼륨 권한 적절

## 8. 다음 단계

### 8.1 추가 서비스 배포
1. code-server 배포
2. gitea 배포
3. traefik 리버스 프록시 설정

### 8.2 고급 설정
1. SSL 인증서 적용
2. 도메인 기반 라우팅
3. 백업 및 모니터링 설정

## 9. 배포 명령어 요약

```bash
# 1. SSH 접속
ssh -p 22022 crossman@192.168.0.5

# 2. 작업 디렉토리 생성
mkdir -p /volume1/docker/dcec-cpse && cd /volume1/docker/dcec-cpse

# 3. n8n 배포
docker-compose -f n8n-simple.yml up -d

# 4. 상태 확인
docker ps && docker logs dcec-n8n

# 5. 서비스 테스트
curl http://192.168.0.5:5678
```

---

**문서 정보**
- **작성일**: 2024년
- **버전**: 1.0
- **상태**: 배포 준비 완료
- **다음 단계**: SSH 연결 복구 또는 웹 UI 배포 진행
