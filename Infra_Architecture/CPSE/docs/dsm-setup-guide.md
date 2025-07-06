# 🌐 시놀로지 DSM 서브도메인 실제 설정 가이드

## 🎯 목표
crossman.synology.me 도메인의 모든 서브도메인을 DSM 리버스 프록시로 설정

## 📋 설정할 서브도메인 목록

| 순서 | 서브도메인 | 대상 포트 | 상태 | 설명 |
|------|------------|-----------|------|------|
| 1 | dsm.crossman.synology.me | 5001 | ✅ 활성화 | DSM 관리 인터페이스 |
| 2 | n8n.crossman.synology.me | 5678 | ❌ 대기 | 워크플로우 자동화 |
| 3 | mcp.crossman.synology.me | 31002 | ❌ 대기 | 모델 컨텍스트 프로토콜 |
| 4 | uptime.crossman.synology.me | 31003 | ❌ 대기 | 모니터링 시스템 |
| 5 | code.crossman.synology.me | 8484 | ❌ 대기 | VSCode 웹 환경 |
| 6 | git.crossman.synology.me | 3000 | ❌ 대기 | Git 저장소 |

## 🚀 단계별 설정 진행

### 1단계: DSM 웹 인터페이스 접속
```
URL: http://192.168.0.5:5000 또는 https://192.168.0.5:5001
계정: crossman
```

### 2단계: 응용 프로그램 포털 접속
1. DSM 메인 메뉴에서 **제어판** 클릭
2. **응용 프로그램 포털** 클릭
3. **리버스 프록시** 탭 클릭

### 3단계: 첫 번째 서브도메인 설정 (DSM)

#### 리버스 프록시 규칙 생성
1. **만들기** 버튼 클릭
2. 다음 정보 입력:

**소스 설정:**
```
프로토콜: HTTPS
호스트 이름: dsm.crossman.synology.me
포트: 443
HSTS 활성화: ✅ (체크)
HTTP/2 활성화: ✅ (체크)
```

**대상 설정:**
```
프로토콜: HTTPS  (※ DSM은 HTTPS로 설정)
호스트 이름: localhost
포트: 5001
```

**고급 설정:**
```
사용자 정의 헤더 탭:
- 추가할 헤더: X-Forwarded-For
- 값: $proxy_add_x_forwarded_for

- 추가할 헤더: X-Forwarded-Proto  
- 값: $scheme

- 추가할 헤더: X-Real-IP
- 값: $remote_addr
```

3. **저장** 클릭

### 4단계: 나머지 서브도메인 설정

각 서비스에 대해 동일한 방식으로 설정:

#### n8n.crossman.synology.me
```
소스: HTTPS, n8n.crossman.synology.me, 443
대상: HTTP, localhost, 5678
고급: WebSocket 지원 활성화 ✅
```

#### mcp.crossman.synology.me
```
소스: HTTPS, mcp.crossman.synology.me, 443
대상: HTTP, localhost, 31002
고급: WebSocket 지원 활성화 ✅
```

#### uptime.crossman.synology.me
```
소스: HTTPS, uptime.crossman.synology.me, 443
대상: HTTP, localhost, 31003
고급: WebSocket 지원 활성화 ✅
```

#### code.crossman.synology.me
```
소스: HTTPS, code.crossman.synology.me, 443
대상: HTTP, localhost, 8484
고급: WebSocket 지원 활성화 ✅
```

#### git.crossman.synology.me
```
소스: HTTPS, git.crossman.synology.me, 443
대상: HTTP, localhost, 3000
고급: WebSocket 지원 활성화 ✅
```

### 5단계: SSL 인증서 설정

#### Let's Encrypt 인증서 생성
1. **제어판** > **보안** > **인증서**
2. **추가** 버튼 클릭
3. **Let's Encrypt에서 인증서 받기** 선택
4. 다음 정보 입력:

```
도메인 이름: crossman.synology.me
주제 대체 이름:
- dsm.crossman.synology.me
- n8n.crossman.synology.me  
- mcp.crossman.synology.me
- uptime.crossman.synology.me
- code.crossman.synology.me
- git.crossman.synology.me

이메일: [관리자 이메일 주소]
```

5. **완료** 클릭

### 6단계: 방화벽 규칙 확인

#### DSM 방화벽 설정
1. **제어판** > **보안** > **방화벽**
2. 다음 포트가 허용되어 있는지 확인:
   - HTTP: 80
   - HTTPS: 443
   - SSH: 22022
   - DSM: 5000, 5001

#### 라우터 포트 포워딩 확인
ASUS RT-AX88U에서 다음 규칙 확인:
```
외부 포트 443 → 192.168.0.5:443 (HTTPS)
외부 포트 80 → 192.168.0.5:80 (HTTP)
외부 포트 31001 → 192.168.0.5:5678 (n8n)
외부 포트 31002 → 192.168.0.5:31002 (MCP)
외부 포트 31003 → 192.168.0.5:31003 (Uptime)
외부 포트 8484 → 192.168.0.5:8484 (Code)
외부 포트 3000 → 192.168.0.5:3000 (Gitea)
```

### 7단계: 테스트 및 검증

#### 내부 테스트
```
✅ DSM: http://192.168.0.5:5001
❌ n8n: http://192.168.0.5:5678 (서비스 시작 후)
❌ MCP: http://192.168.0.5:31002 (서비스 시작 후)
❌ Uptime: http://192.168.0.5:31003 (서비스 시작 후)
❌ Code: http://192.168.0.5:8484 (서비스 시작 후)
❌ Gitea: http://192.168.0.5:3000 (서비스 시작 후)
```

#### 외부 테스트 (SSL 인증서 설정 후)
```
- https://dsm.crossman.synology.me
- https://n8n.crossman.synology.me (서비스 시작 후)
- https://mcp.crossman.synology.me (서비스 시작 후)
- https://uptime.crossman.synology.me (서비스 시작 후)
- https://code.crossman.synology.me (서비스 시작 후)
- https://git.crossman.synology.me (서비스 시작 후)
```

## 🔧 문제 해결

### 일반적인 문제
1. **502 Bad Gateway**: 대상 서비스가 실행되지 않음
2. **SSL 인증서 오류**: Let's Encrypt 인증서 재생성 필요
3. **접속 불가**: 방화벽 또는 포트 포워딩 설정 확인

### 로그 확인
```
DSM > 로그 센터 > 시스템 로그
- 웹 서비스 로그
- 네트워크 로그
- 보안 로그
```

## 📝 설정 완료 체크리스트

- [ ] DSM 리버스 프록시 규칙 6개 생성
- [ ] Let's Encrypt SSL 인증서 생성
- [ ] 방화벽 규칙 확인
- [ ] 라우터 포트 포워딩 확인
- [ ] DSM 서브도메인 테스트
- [ ] 각 서비스 시작 후 개별 테스트

## 🎯 다음 단계

1. **DSM 설정 완료 후**
2. **개별 서비스들을 순차적으로 시작**
3. **각 서브도메인 접속 테스트**
4. **SSL 인증서 자동 갱신 설정 확인**
