# 시놀로지 NAS 인증 방식 확인 가이드

## 📋 확인 목록

### 1️⃣ **SSH 키 기반 인증 지원**
- [ ] DSM에서 SSH 서비스 활성화 상태 확인
- [ ] SSH 공개키 인증 활성화 옵션 확인
- [ ] 사용자별 authorized_keys 파일 지원 확인
- [ ] 키 형식 지원 (RSA, ED25519 등)

### 2️⃣ **2FA (Two-Factor Authentication) 지원**
- [ ] DSM 2단계 인증 활성화 상태 확인
- [ ] OTP 앱 지원 (Google Authenticator, Authy 등)
- [ ] SMS 인증 지원
- [ ] 백업 코드 제공

### 3️⃣ **API 토큰 인증**
- [ ] DSM API 토큰 생성 기능
- [ ] Docker API 접근 권한
- [ ] API 토큰 만료 정책

### 4️⃣ **현재 설정 확인**
- [ ] SSH 포트: 22022 (기본 22에서 변경됨)
- [ ] 사용자: crossman
- [ ] 현재 인증 방식: 패스워드 기반

## 🔧 확인 방법

### DSM 웹 인터페이스 접속
```
URL: https://192.168.0.5:5001
또는: https://crossman.synology.me:5001
```

### SSH 서비스 설정 확인 경로
```
DSM → 제어판 → 터미널 및 SNMP → 터미널 탭
- SSH 서비스 활성화 여부
- SSH 포트 설정 (현재 22022)
- 사용자별 홈 디렉토리 접근 권한
```

### 사용자 및 그룹 설정 확인
```
DSM → 제어판 → 사용자 및 그룹
- crossman 사용자 권한 확인
- SSH 접속 권한 확인
- 관리자 권한 확인
```

### 보안 설정 확인
```
DSM → 제어판 → 보안
- 2단계 인증 설정
- 방화벽 규칙
- 자동 블록 설정
```

## 🚀 테스트 시나리오

### 1단계: 현재 인증 상태 확인
```bash
# DSM 버전 확인
ssh -p 22022 crossman@192.168.0.5 "cat /etc/VERSION"

# SSH 설정 확인
ssh -p 22022 crossman@192.168.0.5 "sudo cat /etc/ssh/sshd_config | grep -E 'PubkeyAuthentication|PasswordAuthentication|AuthorizedKeysFile'"

# 사용자 홈 디렉토리 확인
ssh -p 22022 crossman@192.168.0.5 "ls -la ~/"
```

### 2단계: 공개키 인증 설정 테스트
```powershell
# Windows에서 SSH 키 생성
ssh-keygen -t ed25519 -C "crossman@dcec-project" -f ~/.ssh/synology_ed25519

# 공개키를 NAS에 복사 (수동)
scp -P 22022 ~/.ssh/synology_ed25519.pub crossman@192.168.0.5:~/

# NAS에서 authorized_keys 설정
ssh -p 22022 crossman@192.168.0.5 "mkdir -p ~/.ssh && cat ~/synology_ed25519.pub >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

### 3단계: 키 기반 접속 테스트
```powershell
# 키 기반 SSH 접속 테스트
ssh -p 22022 -i ~/.ssh/synology_ed25519 crossman@192.168.0.5 "echo 'SSH Key Authentication Success!'"
```

## 📋 확인 결과 기록

### DSM 버전 및 기능
- DSM 버전: [확인 필요]
- SSH 서비스: [활성화 여부 확인 필요]
- 공개키 인증: [지원 여부 확인 필요]

### 보안 설정
- 2FA 상태: [확인 필요]
- 방화벽: [확인 필요]
- API 토큰: [확인 필요]

### 추천 설정
1. **SSH 키 기반 인증 활성화** (보안 강화)
2. **패스워드 인증 비활성화** (키 설정 후)
3. **2FA 활성화** (추가 보안층)
4. **방화벽 규칙 최적화** (불필요한 포트 차단)

## 🔄 다음 단계
1. DSM 웹 인터페이스 접속하여 설정 확인
2. SSH 키 생성 및 배포
3. 인증 방식 변경 및 테스트
4. 자동화 스크립트 업데이트

---
**작성일**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**작성자**: DCEC Project Team
