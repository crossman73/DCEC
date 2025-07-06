# 누락된 서비스 DSM 리버스 프록시 설정 가이드

## 📋 현재 상황 분석

### ✅ 설정 완료된 서비스 (DSM 리버스 프록시)
- `HA` → ha.crossman.synology.me → localhost:8123
- `gitea` → gitea.crossman.synology.me → localhost:3000  
- `n8n` → n8n.crossman.synology.me → localhost:5678

### ❌ 누락된 서비스 (추가 설정 필요)
- `code` → code.crossman.synology.me → localhost:8484
- `mcp` → mcp.crossman.synology.me → localhost:31002
- `uptime` → uptime.crossman.synology.me → localhost:31003
- `portainer` → portainer.crossman.synology.me → localhost:9000

---

## 🔧 DSM 리버스 프록시 수동 설정

### 1. DSM 제어판 접속
```
https://192.168.0.5:5001
또는
https://dsm.crossman.synology.me
```

### 2. 로그인 및 응용 프로그램 포털 접속
1. DSM 관리자 계정으로 로그인
2. **제어판** → **응용 프로그램 포털** → **리버스 프록시** 선택

### 3. 누락된 서비스별 설정

#### 3.1 VSCode 웹 환경 (code)
```
규칙 이름: code
원본:
  프로토콜: HTTPS
  호스트 이름: code.crossman.synology.me
  포트: 443
  
대상:
  프로토콜: HTTP
  호스트 이름: localhost
  포트: 8484
```

#### 3.2 MCP 서버 (mcp)
```
규칙 이름: mcp
원본:
  프로토콜: HTTPS
  호스트 이름: mcp.crossman.synology.me
  포트: 443
  
대상:
  프로토콜: HTTP
  호스트 이름: localhost
  포트: 31002
```

#### 3.3 Uptime Kuma (uptime)
```
규칙 이름: uptime
원본:
  프로토콜: HTTPS
  호스트 이름: uptime.crossman.synology.me
  포트: 443
  
대상:
  프로토콜: HTTP
  호스트 이름: localhost
  포트: 31003
```

#### 3.4 Portainer (portainer)
```
규칙 이름: portainer
원본:
  프로토콜: HTTPS
  호스트 이름: portainer.crossman.synology.me
  포트: 443
  
대상:
  프로토콜: HTTP
  호스트 이름: localhost
  포트: 9000
```

---

## 🚀 서비스 컨테이너 시작

현재 대부분의 서비스 포트가 비활성화되어 있어 컨테이너를 시작해야 합니다.

### 1. Docker 컨테이너 확인
```bash
# NAS SSH 접속 후 실행
docker ps -a
docker-compose ps
```

### 2. 서비스별 컨테이너 시작

#### VSCode Server
```bash
docker run -d \
  --name vscode-server \
  -p 8484:8080 \
  --restart unless-stopped \
  -e PASSWORD=SecureVSCodePassword123! \
  codercom/code-server:latest
```

#### MCP Server
```bash
docker run -d \
  --name mcp-server \
  -p 31002:31002 \
  --restart unless-stopped \
  mcp-server:latest
```

#### Uptime Kuma
```bash
docker run -d \
  --name uptime-kuma \
  -p 31003:3001 \
  --restart unless-stopped \
  -v uptime-kuma:/app/data \
  louislam/uptime-kuma:1
```

#### Portainer
```bash
docker run -d \
  --name portainer \
  -p 9000:9000 \
  --restart unless-stopped \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

---

## 🔒 SSL/TLS 인증서 설정

각 서브도메인에 대해 Let's Encrypt 인증서가 자동으로 발급됩니다.

### 1. DDNS 설정 확인
- **제어판** → **외부 액세스** → **DDNS**
- `crossman.synology.me` 설정 확인

### 2. 인증서 확인
- **제어판** → **보안** → **인증서**
- Let's Encrypt 인증서 상태 확인

---

## 🔥 방화벽 규칙 설정

### 1. 외부 포트 허용
**제어판** → **보안** → **방화벽**에서 다음 포트 허용:
- 443 (HTTPS)
- 80 (HTTP - 리다이렉션용)

### 2. 내부 서비스 포트 차단
보안상 다음 포트는 외부 접근 차단:
- 8484 (VSCode 직접 접근)
- 31002 (MCP 직접 접근)
- 31003 (Uptime 직접 접근)
- 9000 (Portainer 직접 접근)

---

## ✅ 설정 검증

### 1. 내부 접속 테스트
```bash
curl -I http://192.168.0.5:8484  # VSCode
curl -I http://192.168.0.5:31002 # MCP
curl -I http://192.168.0.5:31003 # Uptime
curl -I http://192.168.0.5:9000  # Portainer
```

### 2. 외부 접속 테스트
```bash
curl -I https://code.crossman.synology.me
curl -I https://mcp.crossman.synology.me
curl -I https://uptime.crossman.synology.me
curl -I https://portainer.crossman.synology.me
```

### 3. PowerShell 자동 검증
```powershell
cd "d:\Dev\DCEC\Infra_Architecture\CPSE"
.\setup-all-subdomains.ps1 -Action verify
```

---

## 🛠️ 문제 해결

### 서비스 포트 비활성화 문제
1. Docker 컨테이너 상태 확인
2. 포트 바인딩 확인
3. 방화벽 설정 확인
4. 서비스 로그 확인

### SSL 인증서 오류
1. DDNS 설정 확인
2. 도메인 DNS 전파 대기 (최대 24시간)
3. Let's Encrypt 제한 확인 (주간 발급 제한)

### 리버스 프록시 연결 실패
1. 대상 서비스 실행 상태 확인
2. 포트 번호 정확성 확인
3. 호스트명 설정 확인

---

## 📞 지원 및 문의

추가 설정이나 문제가 발생할 경우:
1. 로그 파일 확인: `/var/log/nginx/`
2. Docker 로그: `docker logs [container_name]`
3. DSM 로그: **제어판** → **로그 센터**

---

*마지막 업데이트: 2025-01-05*
*작성자: DCEC Infrastructure Team*
