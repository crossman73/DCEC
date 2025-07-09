# NAS SSH 폴더 중복 문제 진단 및 해결

## 🚨 문제 상황
- NAS에 `.ssh` 폴더가 2개 발견됨
- SSH 키 인증이 제대로 작동하지 않을 가능성

## 🔍 진단 단계

### 1단계: .ssh 폴더 위치 확인
SMB(`\\192.168.0.5`)를 통해 다음 경로들을 확인:

```
\\192.168.0.5\homes\crossman\.ssh
\\192.168.0.5\crossman\.ssh
\\192.168.0.5\home\crossman\.ssh
\\192.168.0.5\var\services\homes\crossman\.ssh
```

### 2단계: 각 폴더의 권한 및 내용 확인
각 `.ssh` 폴더에서 확인할 사항:
- 폴더 권한 (700이어야 함)
- authorized_keys 파일 존재 여부
- authorized_keys 파일 권한 (600이어야 함)
- 파일 내용 (public key가 올바르게 들어있는지)

### 3단계: SSH 데몬 설정 확인
SSH 서버가 어느 경로의 `.ssh` 폴더를 참조하는지 확인 필요

## 🛠️ 해결 방법

### 방법 1: SSH로 직접 접속하여 확인
```bash
ssh crossman@192.168.0.5
pwd                          # 현재 위치 확인
echo $HOME                   # 홈 디렉토리 확인
ls -la $HOME/.ssh            # .ssh 폴더 내용 확인
cat $HOME/.ssh/authorized_keys  # authorized_keys 내용 확인
```

### 방법 2: 올바른 .ssh 폴더에 키 설정
```bash
# 홈 디렉토리의 .ssh 폴더 사용
mkdir -p $HOME/.ssh
chmod 700 $HOME/.ssh

# public key 추가
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDgfrTJYGgXtNUQcv0QoTtPy1grrEcVI8PQkZARcZScLqv4oMGnYhkDOHrq8effoBwDMXHK619+u3VweRqpqc2I7Xg18pHqmxSdyN6OM19cOGMDLrag6ju5UsyvwNi6tPz42RXkLqU9yO0Fhdgv38nZh1SIdMRdGEH2rfoJQODsBoTuj47b687P6KPS8oBJNCwJIk4ihtkOiaifDge9TQOhNGoNEQOjzs0mC3upJdUZau9mCFvDAZNwtIcA4rZ8TChabKSs/whi63dT4hVTpQWc/bCotnQgyJMdWFt4f46kj3iOH+NVYtUx3PDw9m6/2IaWJGzzXrvn0xNJoRQulsORdsEHngI38Ob2M1GjxaoyFLv/FN9cMuSxtetFTJBMMYB65goyHDWWMADoISGfK/Wt8b6OXs3KnGEhG1NY6lOfQatoXDt2cYbs3a92IyUYCxyoZr9Rz8PxqIy3hToDJ6U/TSKBN2EKHjQQ6eD+UWXCW+1kvte0UbqFna15RXxpjfs= crossman@OH-NOTEBOOKYM' >> $HOME/.ssh/authorized_keys

chmod 600 $HOME/.ssh/authorized_keys
```

### 방법 3: 중복 폴더 정리
```bash
# 올바른 .ssh 폴더만 남기고 나머지 삭제 또는 백업
# (주의: 백업 후 진행할 것)
```

## 🔧 권장 해결 순서

1. **SSH 접속으로 홈 디렉토리 확인**
2. **올바른 $HOME/.ssh 위치에 키 설정**
3. **중복 폴더 제거 또는 백업**
4. **SSH 키 인증 테스트**

## ⚠️ 주의사항
- 기존 SSH 키나 설정을 삭제하기 전에 반드시 백업
- 권한 설정을 정확히 해야 SSH 인증이 작동함
- 시놀로지 NAS는 특별한 경로 구조를 가질 수 있음

## 🧪 테스트 명령어
```powershell
# Windows에서 SSH 키 인증 테스트
ssh crossman@192.168.0.5 -v    # verbose 모드로 연결 과정 확인
```

---
**생성일**: 2025-07-07  
**작성자**: DCEC Development Team
