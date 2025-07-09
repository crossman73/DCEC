# SMB를 통한 SSH Key 설정 가이드

## 현재 상황
- ✅ SSH 키 쌍 생성 완료
- ✅ NAS SMB 접근 가능 (`\\192.168.0.5`)
- ✅ crossman 계정 확인
- 🔄 **진행 중**: authorized_keys 파일 설정

## SSH Public Key 내용
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDgfrTJYGgXtNUQcv0QoTtPy1grrEcVI8PQkZARcZScLqv4oMGnYhkDOHrq8effoBwDMXHK619+u3VweRqpqc2I7Xg18pHqmxSdyN6OM19cOGMDLrag6ju5UsyvwNi6tPz42RXkLqU9yO0Fhdgv38nZh1SIdMRdGEH2rfoJQODsBoTuj47b687P6KPS8oBJNCwJIk4ihtkOiaifDge9TQOhNGoNEQOjzs0mC3upJdUZau9mCFvDAZNwtIcA4rZ8TChabKSs/whi63dT4hVTpQWc/bCotnQgyJMdWFt4f46kj3iOH+NVYtUx3PDw9m6/2IaWJGzzXrvn0xNJoRQulsORdsEHngI38Ob2M1GjxaoyFLv/FN9cMuSxtetFTJBMMYB65goyHDWWMADoISGfK/Wt8b6OXs3KnGEhG1NY6lOfQatoXDt2cYbs3a92IyUYCxyoZr9Rz8PxqIy3hToDJ6U/TSKBN2EKHjQQ6eD+UWXCW+1kvte0UbqFna15RXxpjfs= crossman@OH-NOTEBOOKYM
```

## SMB 접근 방법

### 1단계: Windows 탐색기를 통한 SMB 접근
```
주소창에 입력: \\192.168.0.5
```

### 2단계: crossman 계정 홈 디렉토리 찾기
- NAS에서 crossman 계정의 홈 디렉토리 위치 확인
- 일반적으로 다음 위치 중 하나:
  - `\\192.168.0.5\homes\crossman`
  - `\\192.168.0.5\home\crossman`
  - `\\192.168.0.5\volume1\homes\crossman`

### 3단계: .ssh 디렉토리 생성 (없는 경우)
- crossman 홈 디렉토리에 `.ssh` 폴더 생성
- 폴더 권한: 700 (소유자만 읽기/쓰기/실행)

### 4단계: authorized_keys 파일 생성/편집
- `.ssh` 폴더 내에 `authorized_keys` 파일 생성
- 파일에 위의 SSH public key 내용 추가
- 파일 권한: 600 (소유자만 읽기/쓰기)

### 5단계: PowerShell을 통한 SMB 접근 (대안)
```powershell
# SMB 공유 연결
net use Z: \\192.168.0.5\homes /persistent:no

# crossman 홈 디렉토리로 이동
cd "Z:\crossman"

# .ssh 디렉토리 생성
mkdir .ssh -ErrorAction SilentlyContinue

# authorized_keys 파일에 public key 추가
$publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDgfrTJYGgXtNUQcv0QoTtPy1grrEcVI8PQkZARcZScLqv4oMGnYhkDOHrq8effoBwDMXHK619+u3VweRqpqc2I7Xg18pHqmxSdyN6OM19cOGMDLrag6ju5UsyvwNi6tPz42RXkLqU9yO0Fhdgv38nZh1SIdMRdGEH2rfoJQODsBoTuj47b687P6KPS8oBJNCwJIk4ihtkOiaifDge9TQOhNGoNEQOjzs0mC3upJdUZau9mCFvDAZNwtIcA4rZ8TChabKSs/whi63dT4hVTpQWc/bCotnQgyJMdWFt4f46kj3iOH+NVYtUx3PDw9m6/2IaWJGzzXrvn0xNJoRQulsORdsEHngI38Ob2M1GjxaoyFLv/FN9cMuSxtetFTJBMMYB65goyHDWWMADoISGfK/Wt8b6OXs3KnGEhG1NY6lOfQatoXDt2cYbs3a92IyUYCxyoZr9Rz8PxqIy3hToDJ6U/TSKBN2EKHjQQ6eD+UWXCW+1kvte0UbqFna15RXxpjfs= crossman@OH-NOTEBOOKYM"

Add-Content -Path ".ssh\authorized_keys" -Value $publicKey -Encoding UTF8

# 연결 해제
net use Z: /delete
```

## 테스트 명령어
```powershell
# SSH 키 기반 인증 테스트
ssh crossman@192.168.0.5

# 연결 성공 시 패스워드 없이 접속됨
```

## 문제 해결
- SMB 연결 실패 시: 네트워크 자격 증명 확인
- 권한 문제 시: NAS 관리자 권한으로 폴더/파일 권한 수정
- SSH 접속 실패 시: authorized_keys 파일 내용 및 권한 확인

---
**생성일**: 2025-07-07  
**작성자**: DCEC Development Team
