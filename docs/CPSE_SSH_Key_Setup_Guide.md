# 시놀로지 NAS SSH 키 설정 가이드

## 📋 SSH 키 설정 개요
- **목적**: 시놀로지 DS920+ NAS에서 SSH 키 기반 인증 설정
- **참고**: https://jd6186.github.io/NAS_CI_CD/
- **생성일**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## 🔑 1단계: Windows에서 SSH 키 생성 (이미 완료)

### 기존 SSH 키 확인
```powershell
# SSH 키 존재 여부 확인
if (Test-Path "$env:USERPROFILE\.ssh\id_rsa.pub") {
    Write-Host "✅ SSH 공개키가 존재합니다"
    Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"
} else {
    Write-Host "❌ SSH 키가 없습니다. 생성이 필요합니다."
    ssh-keygen -t rsa -b 4096 -C "crossman@dcec-project"
}
```

## 🏠 2단계: 시놀로지 NAS에 SSH 키 등록

### 방법 1: ssh-copy-id 사용 (권장)
```bash
# Windows에서 실행
ssh-copy-id -p 22022 crossman@192.168.0.5
```

### 방법 2: 수동 등록
```bash
# 1. NAS에 SSH로 접속
ssh -p 22022 crossman@192.168.0.5

# 2. .ssh 디렉토리 생성 (없을 경우)
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 3. authorized_keys 파일 생성/편집
nano ~/.ssh/authorized_keys

# 4. Windows의 공개키 내용을 붙여넣기
# (c:\Users\cross\.ssh\id_rsa.pub 내용)

# 5. 권한 설정
chmod 600 ~/.ssh/authorized_keys
```

### 방법 3: PowerShell 스크립트 사용
```powershell
# Windows 공개키 읽기
$publicKey = Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"

# NAS에 키 등록 (패스워드 인증 필요)
$commands = @(
    "mkdir -p ~/.ssh",
    "chmod 700 ~/.ssh",
    "echo '$publicKey' >> ~/.ssh/authorized_keys",
    "chmod 600 ~/.ssh/authorized_keys",
    "echo 'SSH 키 등록 완료'"
)

foreach ($cmd in $commands) {
    ssh -p 22022 crossman@192.168.0.5 "$cmd"
}
```

## ⚙️ 3단계: 시놀로지 DSM SSH 설정 확인

### DSM 웹 인터페이스에서 확인사항:
1. **제어판 → 터미널 & SNMP → 터미널**
   - SSH 서비스 활성화 확인
   - 포트 22022 설정 확인

2. **제어판 → 사용자 → 고급 → 홈 폴더**
   - 홈 폴더 서비스 활성화 확인

3. **제어판 → 보안 → 방화벽**
   - SSH 포트 22022 허용 확인

## 🔒 4단계: SSH 키 인증 테스트

### 인증 테스트 명령어
```powershell
# 키 기반 인증 테스트
ssh -p 22022 -o PreferredAuthentications=publickey crossman@192.168.0.5 "echo 'SSH 키 인증 성공!'"

# 패스워드 인증 비활성화 테스트
ssh -p 22022 -o PreferredAuthentications=publickey -o PasswordAuthentication=no crossman@192.168.0.5 "whoami"
```

## 🚨 문제 해결

### 일반적인 문제
1. **Permission denied (publickey)**
   - authorized_keys 파일 권한 확인: `chmod 600 ~/.ssh/authorized_keys`
   - .ssh 디렉토리 권한 확인: `chmod 700 ~/.ssh`

2. **SSH 서비스 비활성화**
   - DSM → 제어판 → 터미널 & SNMP에서 SSH 활성화

3. **방화벽 차단**
   - DSM → 제어판 → 보안 → 방화벽에서 22022 포트 허용

### 디버깅 명령어
```bash
# SSH 연결 상세 로그
ssh -v -p 22022 crossman@192.168.0.5

# NAS에서 SSH 서비스 상태 확인
sudo systemctl status sshd

# SSH 설정 파일 확인
sudo cat /etc/ssh/sshd_config | grep -E "PubkeyAuthentication|AuthorizedKeysFile"
```

## 📝 체크리스트

### SSH 키 설정 완료 체크리스트:
- [ ] Windows에서 SSH 키 쌍 생성 완료
- [ ] 시놀로지 NAS ~/.ssh 디렉토리 생성
- [ ] authorized_keys 파일에 공개키 등록
- [ ] 파일 권한 설정 (600, 700)
- [ ] DSM SSH 서비스 활성화 확인
- [ ] 방화벽 22022 포트 허용 확인
- [ ] SSH 키 인증 테스트 성공

---
**참고 문서**: https://jd6186.github.io/NAS_CI_CD/  
**작성자**: DCEC Development Team  
**최종 수정**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
