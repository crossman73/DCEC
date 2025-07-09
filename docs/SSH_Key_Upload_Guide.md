# SSH Public Key 업로드 가이드

## 현재 상황
- ✅ Windows에서 SSH 키 쌍 생성 완료
- ✅ NAS SMB 접속 확인 (`\\192.168.0.5`)
- ✅ NAS 계정 설정 완료
- 🔄 **다음 단계**: SSH public key를 NAS authorized_keys에 추가

## SSH Key 정보
- **Public Key 경로**: `C:\Users\cross\.ssh\id_rsa.pub`
- **Private Key 경로**: `C:\Users\cross\.ssh\id_rsa`
- **대상 NAS**: 192.168.0.5
- **대상 계정**: admin

## Public Key 내용
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDgfrTJYGgXtNUQcv0QoTtPy1grrEcVI8PQkZARcZScLqv4oMGnYhkDOHrq8effoBwDMXHK619+u3VweRqpqc2I7Xg18pHqmxSdyN6OM19cOGMDLrag6ju5UsyvwNi6tPz42RXkLqU9yO0Fhdgv38nZh1SIdMRdGEH2rfoJQODsBoTuj47b687P6KPS8oBJNCwJIk4ihtkOiaifDge9TQOhNGoNEQOjzs0mC3upJdUZau9mCFvDAZNwtIcA4rZ8TChabKSs/whi63dT4hVTpQWc/bCotnQgyJMdWFt4f46kj3iOH+NVYtUx3PDw9m6/2IaWJGzzXrvn0xNJoRQulsORdsEHngI38Ob2M1GjxaoyFLv/FN9cMuSxtetFTJBMMYB65goyHDWWMADoISGfK/Wt8b6OXs3KnGEhG1NY6lOfQatoXDt2cYbs3a92IyUYCxyoZr9Rz8PxqIy3hToDJ6U/TSKBN2EKHjQQ6eD+UWXCW+1kvte0UbqFna15RXxpjfs= crossman@OH-NOTEBOOKYM
```

## 업로드 방법

### 방법 1: SMB를 통한 직접 파일 접근 (권장)
1. Windows 탐색기에서 `\\192.168.0.5` 접속
2. 계정으로 로그인 (이미 설정됨)
3. admin 사용자의 홈 디렉토리 찾기
4. `.ssh` 폴더 생성 (없는 경우)
5. `authorized_keys` 파일 생성/편집
6. 위의 public key 내용 추가

### 방법 2: DSM File Station 사용
1. 브라우저에서 `http://192.168.0.5:5000` 접속
2. admin 계정으로 로그인
3. File Station 앱 실행
4. 홈 디렉토리 이동
5. `.ssh/authorized_keys` 파일 편집

### 방법 3: 현재 계정으로 SSH 접속 후 설정
```bash
ssh admin@192.168.0.5
mkdir -p ~/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDgfrTJYGgXtNUQcv0QoTtPy1grrEcVI8PQkZARcZScLqv4oMGnYhkDOHrq8effoBwDMXHK619+u3VweRqpqc2I7Xg18pHqmxSdyN6OM19cOGMDLrag6ju5UsyvwNi6tPz42RXkLqU9yO0Fhdgv38nZh1SIdMRdGEH2rfoJQODsBoTuj47b687P6KPS8oBJNCwJIk4ihtkOiaifDge9TQOhNGoNEQOjzs0mC3upJdUZau9mCFvDAZNwtIcA4rZ8TChabKSs/whi63dT4hVTpQWc/bCotnQgyJMdWFt4f46kj3iOH+NVYtUx3PDw9m6/2IaWJGzzXrvn0xNJoRQulsORdsEHngI38Ob2M1GjxaoyFLv/FN9cMuSxtetFTJBMMYB65goyHDWWMADoISGfK/Wt8b6OXs3KnGEhG1NY6lOfQatoXDt2cYbs3a92IyUYCxyoZr9Rz8PxqIy3hToDJ6U/TSKBN2EKHjQQ6eD+UWXCW+1kvte0UbqFna15RXxpjfs= crossman@OH-NOTEBOOKYM' >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

## 권한 확인사항
- `~/.ssh` 폴더: 권한 700 (drwx------)
- `~/.ssh/authorized_keys` 파일: 권한 600 (-rw-------)
- 소유자: admin

## 테스트 방법
```powershell
ssh admin@192.168.0.5
```
패스워드 없이 접속되면 성공!

## 다음 단계
1. SSH 키 기반 인증 테스트
2. n8n 도커 컨테이너 배포
3. 리버스 프록시 및 네트워크 설정

---
**생성일**: 2025-07-07  
**작성자**: DCEC Development Team
