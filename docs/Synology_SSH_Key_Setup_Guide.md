# 시놀로지 NAS SSH 키 기반 인증 설정 가이드

## 📋 문서 정보
- **참조**: [시놀로지 공식 가이드](https://kb.synology.com/ko-kr/DSM/tutorial/How_to_log_in_to_DSM_with_key_pairs_as_admin_or_root_permission_via_SSH_on_computers)
- **작성일**: 2025-07-07
- **프로젝트**: DCEC SSH 인증 설정

## 🎯 목적
SSH를 통해 RSA 키 쌍을 사용하여 시놀로지 DSM에 관리자 권한으로 로그인하는 방법 설명

## ⚠️ 주의사항
- SSH 서비스 활성화는 시스템에 보안 위험을 초래할 수 있음
- 필요한 경우에만 활성화하고 시스템 구성을 함부로 변경하지 말 것
- DSM 6.2.4 이상에서만 적용 가능

## 📋 진행 단계

### A. 시작하기 전 준비사항
1. **관리자 계정으로 DSM 로그인**
   - administrators 그룹에 속하는 계정 사용

2. **SSH 서비스 활성화**
   - 제어판 → 터미널 및 SNMP → 터미널
   - "SSH 서비스 활성화" 선택

3. **사용자 홈 서비스 활성화** (관리자로 로그인하는 경우)
   - 제어판 → 사용자 및 그룹 (DSM 7.0 이상) 또는 사용자 (DSM 6.2.4) → 고급 → 사용자 홈
   - "사용자 홈 서비스 활성화" 선택
   - "homes" 공유 폴더가 기본 권한을 사용하는지 확인

### B. RSA 키 쌍 생성

#### Windows 10 이상에서 OpenSSH 사용
```powershell
# Windows 클라이언트에서 키 생성
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

#### 저장 위치
- 기본 위치: `C:\Users\{사용자명}\.ssh\`
- Private Key: `id_rsa`
- Public Key: `id_rsa.pub`

### C. Synology NAS에 공개 키 업로드

#### 방법 1: DSM 파일 관리자 사용 (권장)
1. **DSM 웹 인터페이스 접속**
   - 브라우저에서 `http://192.168.0.5:5000` 접속
   - 관리자 계정으로 로그인

2. **File Station에서 업로드**
   - File Station 앱 실행
   - homes/사용자명 폴더로 이동
   - .ssh 폴더 생성 (없는 경우)
   - id_rsa.pub 파일을 .ssh 폴더에 업로드

3. **SSH 터미널에서 설정**
   ```bash
   # NAS SSH 접속
   ssh -p 22022 crossman@192.168.0.5
   
   # .ssh 디렉토리로 이동
   cd ~/.ssh
   
   # 공개 키를 authorized_keys에 추가
   cat id_rsa.pub >> authorized_keys
   
   # 권한 설정
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   chmod 644 ~/.ssh/id_rsa.pub
   ```

#### 방법 2: SCP를 통한 직접 업로드
```powershell
# Windows에서 공개 키 업로드
scp -P 22022 C:\Users\{사용자명}\.ssh\id_rsa.pub crossman@192.168.0.5:~/.ssh/
```

### D. SSH 키 기반 로그인 테스트

#### Windows 10에서 OpenSSH 사용
```powershell
# 키 기반 인증으로 접속
ssh -i C:\Users\{사용자명}\.ssh\id_rsa -p 22022 crossman@192.168.0.5
```

#### 접속 확인사항
- 비밀번호 입력 없이 로그인 가능해야 함
- 패스프레이즈 설정 시에만 패스프레이즈 입력 요구

## 🔧 문제 해결

### 권한 문제
```bash
# SSH 디렉토리 및 파일 권한 재설정
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
```

### 접속 디버그
```powershell
# 상세 로그로 접속 시도
ssh -v -i C:\Users\{사용자명}\.ssh\id_rsa -p 22022 crossman@192.168.0.5
```

## 📝 현재 DCEC 프로젝트 상태

### 완료된 작업
- [x] NAS에서 SSH 키 생성 완료
- [x] authorized_keys 설정 완료
- [ ] Windows에서 키 다운로드 및 설정
- [ ] SSH 키 기반 인증 테스트
- [ ] n8n Docker 배포 준비

### 다음 단계
1. **DSM File Station을 통한 키 다운로드**
   - 웹 브라우저에서 DSM 접속
   - File Station에서 ~/.ssh/id_rsa 파일 다운로드

2. **Windows에서 키 설정**
   - 다운로드한 키를 ~/.ssh/ 폴더에 저장
   - 권한 설정 및 SSH 설정 확인

3. **SSH 키 기반 인증 테스트**
   - 비밀번호 없이 NAS 접속 확인

## 🔗 참고 자료
- [시놀로지 공식 SSH 키 가이드](https://kb.synology.com/ko-kr/DSM/tutorial/How_to_log_in_to_DSM_with_key_pairs_as_admin_or_root_permission_via_SSH_on_computers)
- [시놀로지 기본 권한 설정](https://kb.synology.com/ko-kr/DSM/tutorial/default_permissions_of_homes)

---
**작성자**: DCEC Development Team  
**최종 수정**: 2025-07-07 13:48:00  
**버전**: 1.0
