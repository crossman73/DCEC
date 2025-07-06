# 시놀로지 NAS에서 n8n 서비스 수동 설정 가이드

## 🐳 1단계: NAS SSH 접속 및 n8n Docker 실행

### SSH 접속
```bash
ssh -p 22022 crossman@192.168.0.5
```

### n8n 데이터 디렉토리 생성
```bash
sudo mkdir -p /volume1/docker/n8n
sudo chown -R crossman:users /volume1/docker/n8n
```

### n8n Docker 컨테이너 실행
```bash
# 기존 컨테이너 정리 (있는 경우)
sudo docker stop n8n 2>/dev/null || true
sudo docker rm n8n 2>/dev/null || true

# n8n 컨테이너 실행
sudo docker run -d \
  --name n8n \
  --restart unless-stopped \
  -p 5678:5678 \
  -v /volume1/docker/n8n:/home/node/.n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=crossman \
  -e N8N_BASIC_AUTH_PASSWORD=changeme123 \
  -e N8N_HOST=n8n.crossman.synology.me \
  -e N8N_PORT=5678 \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL=https://n8n.crossman.synology.me \
  n8nio/n8n:latest
```

### 컨테이너 상태 확인
```bash
# 컨테이너 실행 상태 확인
sudo docker ps | grep n8n

# 포트 바인딩 확인
sudo netstat -tulpn | grep :5678

# n8n 로그 확인
sudo docker logs n8n
```

## 🌐 2단계: DSM 리버스 프록시 설정

### 브라우저에서 DSM 접속
1. 브라우저 열기
2. `http://192.168.0.5:5000` 접속
3. 사용자: `crossman`, 비밀번호 입력

### 응용 프로그램 포털 설정
1. **DSM 메뉴** > **제어판**
2. **응용 프로그램 포털** 클릭
3. **리버스 프록시** 탭 선택
4. **만들기** 버튼 클릭

### 리버스 프록시 규칙 설정

#### 소스 (Source) 설정
```
프로토콜: HTTPS
호스트명: n8n.crossman.synology.me
포트:     443
```

#### 대상 (Destination) 설정
```
프로토콜: HTTP
호스트명: localhost
포트:     5678
```

### 고급 설정 (권장)
1. **고급 설정** 탭 클릭
2. 다음 옵션들 체크:
   - ✅ **WebSocket 사용**
   - ✅ **HTTP/2 사용**
   - ✅ **HSTS 사용**

### 적용 및 저장
1. **확인** 버튼 클릭
2. 설정 저장 완료

## 🔐 3단계: SSL 인증서 설정

### Let's Encrypt 인증서 설정
1. **DSM** > **제어판** > **보안** > **인증서**
2. **추가** 클릭
3. **Let's Encrypt에서 인증서 받기** 선택
4. 도메인 설정:
   ```
   도메인명: *.crossman.synology.me
   이메일: your-email@domain.com
   ```
5. **적용** 클릭

### 인증서 할당
1. **설정** 탭에서 인증서 할당
2. **n8n.crossman.synology.me** → Let's Encrypt 인증서 선택
3. **저장** 클릭

## 🧪 4단계: 서브도메인 테스트

### 내부 테스트
```bash
# NAS에서 내부 포트 확인
curl -I http://localhost:5678

# 응답 예시: HTTP/1.1 200 OK
```

### 외부 테스트
```bash
# 로컬 PC에서 테스트
curl -I https://n8n.crossman.synology.me

# 또는 브라우저에서 접속
https://n8n.crossman.synology.me
```

### n8n 웹 인터페이스 접속
1. 브라우저에서 `https://n8n.crossman.synology.me` 접속
2. 로그인 정보:
   - **사용자명**: crossman
   - **비밀번호**: changeme123
3. n8n 워크플로우 대시보드 확인

## 🔧 문제 해결

### 서브도메인 접속 안됨
```bash
# DNS 확인
nslookup n8n.crossman.synology.me

# 포트 확인
telnet n8n.crossman.synology.me 443
```

### n8n 서비스 재시작
```bash
# SSH로 NAS 접속 후
sudo docker restart n8n
sudo docker logs -f n8n
```

### 리버스 프록시 규칙 확인
1. DSM > 응용 프로그램 포털 > 리버스 프록시
2. 설정된 규칙 확인 및 수정

## 📊 최종 확인 체크리스트

- [ ] n8n Docker 컨테이너 실행 중
- [ ] 포트 5678 바인딩 확인
- [ ] DSM 리버스 프록시 규칙 생성
- [ ] SSL 인증서 설정 완료
- [ ] 외부에서 https://n8n.crossman.synology.me 접속 가능
- [ ] n8n 웹 인터페이스 로그인 성공

## 🎯 다음 단계

n8n 서브도메인이 성공적으로 설정되면:
1. 다른 서비스들(MCP, Uptime Kuma, Code Server, Gitea) 순차적으로 설정
2. Docker Compose로 통합 관리 전환
3. 자동화 스크립트로 배포 프로세스 간소화

성공하시면 알려주세요! 다음 서브도메인 설정을 도와드리겠습니다.
