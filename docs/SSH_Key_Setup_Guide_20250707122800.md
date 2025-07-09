# 시놀로지 NAS SSH 키 인증 설정 가이드

## 📋 설정 정보
- **생성일**: 2025-07-07 12:28:00
- **대상 NAS**: 시놀로지 DS920+ (192.168.0.5:22022)
- **사용자**: crossman
- **키 타입**: ed25519

## 🔑 현재 SSH 키 정보
```
공개키 위치: C:\Users\{USER}\.ssh\id_ed25519.pub
개인키 위치: C:\Users\{USER}\.ssh\id_ed25519
키 내용: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVX3LWy6zG81yun+EeCWgx7T/FTyhkiBCAVPJeOPB0I crossman737@gmail.com
```

## 🏗️ SSH 키 등록 방법

### 방법 1: DSM 웹 인터페이스 (권장)
1. **DSM 로그인**: https://192.168.0.5:5001
2. **제어판 → 터미널 및 SNMP → 터미널**
3. **SSH 서비스 활성화 확인**
4. **사용자 계정 → 고급 → 사용자 홈 서비스 활성화**
5. **SSH 공개키 등록**:
   - 사용자 디렉토리: `/var/services/homes/crossman`
   - `.ssh/authorized_keys` 파일에 공개키 추가

### 방법 2: 패스워드 로그인 후 키 등록 (임시)
```bash
# 임시로 패스워드 로그인하여 키 등록
ssh -p 22022 crossman@192.168.0.5

# 홈 디렉토리에 .ssh 폴더 생성
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# authorized_keys 파일 생성 및 공개키 추가
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVX3LWy6zG81yun+EeCWgx7T/FTyhkiBCAVPJeOPB0I crossman737@gmail.com" >> ~/.ssh/authorized_keys

# 권한 설정
chmod 600 ~/.ssh/authorized_keys

# SSH 설정 확인
cat ~/.ssh/authorized_keys
```

### 방법 3: 시놀로지 CLI 사용
```bash
# 시놀로지에서 사용자 홈 서비스 활성화 확인
sudo synouser --get crossman

# SSH 키 디렉토리 생성
sudo mkdir -p /var/services/homes/crossman/.ssh
sudo chown crossman:users /var/services/homes/crossman/.ssh
sudo chmod 700 /var/services/homes/crossman/.ssh

# authorized_keys 파일 생성
sudo touch /var/services/homes/crossman/.ssh/authorized_keys
sudo chown crossman:users /var/services/homes/crossman/.ssh/authorized_keys
sudo chmod 600 /var/services/homes/crossman/.ssh/authorized_keys
```

## ✅ 등록 후 테스트
```powershell
# SSH 키 기반 인증 테스트
ssh -p 22022 -o PreferredAuthentications=publickey crossman@192.168.0.5 "echo 'SSH 키 인증 성공!'"

# 일반 명령 테스트
ssh -p 22022 crossman@192.168.0.5 "docker --version"
```

## 🔧 SSH 설정 최적화

### DSM SSH 설정 확인사항
1. **터미널 서비스 활성화**: 제어판 → 터미널 및 SNMP
2. **사용자 홈 서비스**: 제어판 → 사용자 계정 → 고급 → 사용자 홈 서비스
3. **SSH 포트**: 22022 (보안을 위해 기본 22에서 변경됨)
4. **방화벽 규칙**: SSH 포트 22022 허용

### SSH 클라이언트 설정 (.ssh/config)
```
Host synology-nas
    HostName 192.168.0.5
    Port 22022
    User crossman
    IdentityFile ~/.ssh/id_ed25519
    PreferredAuthentications publickey
```

## 🚨 문제 해결

### SSH 키 인증 실패 시
1. **권한 확인**: authorized_keys 파일 권한이 600인지 확인
2. **경로 확인**: 사용자 홈 디렉토리 경로 확인
3. **SSH 로그**: `/var/log/messages`에서 SSH 관련 오류 확인
4. **DSM 로그**: DSM → 로그 센터에서 연결 로그 확인

### 일반적인 오류들
- **Permission denied**: 키 파일 권한 또는 경로 문제
- **Connection refused**: SSH 서비스 비활성화 또는 포트 차단
- **Host key verification failed**: known_hosts 파일 문제

---

**작성자**: DCEC Development Team  
**최종 수정**: 2025-07-07 12:28:00  
**다음 단계**: SSH 키 등록 후 n8n Docker 배포 진행
