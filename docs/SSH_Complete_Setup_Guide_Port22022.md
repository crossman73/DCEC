# NAS SSH 키 설정 완전 가이드 (포트 22022)

## 🔧 현재 상황 정리
- **NAS 주소**: 192.168.0.5
- **SSH 포트**: 22022 (기본 22가 아님!)
- **계정**: crossman
- **문제**: .ssh 폴더가 2개 존재 (하나는 키 있음, 하나는 빈 폴더)
- **목표**: 빈 .ssh 폴더 제거 후 SSH 키 기반 인증 설정

## 📋 SSH Public Key 정보
```
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDgfrTJYGgXtNUQcv0QoTtPy1grrEcVI8PQkZARcZScLqv4oMGnYhkDOHrq8effoBwDMXHK619+u3VweRqpqc2I7Xg18pHqmxSdyN6OM19cOGMDLrag6ju5UsyvwNi6tPz42RXkLqU9yO0Fhdgv38nZh1SIdMRdGEH2rfoJQODsBoTuj47b687P6KPS8oBJNCwJIk4ihtkOiaifDge9TQOhNGoNEQOjzs0mC3upJdUZau9mCFvDAZNwtIcA4rZ8TChabKSs/whi63dT4hVTpQWc/bCotnQgyJMdWFt4f46kj3iOH+NVYtUx3PDw9m6/2IaWJGzzXrvn0xNJoRQulsORdsEHngI38Ob2M1GjxaoyFLv/FN9cMuSxtetFTJBMMYB65goyHDWWMADoISGfK/Wt8b6OXs3KnGEhG1NY6lOfQatoXDt2cYbs3a92IyUYCxyoZr9Rz8PxqIy3hToDJ6U/TSKBN2EKHjQQ6eD+UWXCW+1kvte0UbqFna15RXxpjfs= crossman@OH-NOTEBOOKYM
```

## 🚀 해결 단계

### 1단계: SSH 접속으로 .ssh 폴더 확인
```bash
# 올바른 포트로 SSH 접속
ssh crossman@192.168.0.5 -p 22022

# 홈 디렉토리 확인
pwd
echo $HOME

# 모든 .ssh 폴더 찾기
find $HOME -name ".ssh" -type d 2>/dev/null
find / -name ".ssh" -type d 2>/dev/null | grep crossman

# 각 .ssh 폴더 내용 확인
ls -la ~/.ssh/
ls -la /var/services/homes/crossman/.ssh/ 2>/dev/null || echo "경로 없음"
```

### 2단계: .ssh 폴더 상태 분석
```bash
# 각 폴더의 내용과 권한 확인
for dir in $(find $HOME -name ".ssh" -type d 2>/dev/null); do
    echo "=== $dir ==="
    ls -la "$dir/"
    echo "권한: $(stat -c %a "$dir")"
    if [ -f "$dir/authorized_keys" ]; then
        echo "authorized_keys 존재"
        echo "권한: $(stat -c %a "$dir/authorized_keys")"
        echo "내용:"
        cat "$dir/authorized_keys"
    else
        echo "authorized_keys 없음"
    fi
    echo
done
```

### 3단계: 빈 .ssh 폴더 제거
```bash
# 백업 생성 (안전을 위해)
mkdir -p ~/ssh_backup_$(date +%Y%m%d_%H%M%S)

# 빈 .ssh 폴더 찾기 및 제거
for dir in $(find $HOME -name ".ssh" -type d 2>/dev/null); do
    if [ ! -f "$dir/authorized_keys" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
        echo "빈 폴더 발견: $dir"
        rmdir "$dir"
        echo "제거 완료: $dir"
    fi
done
```

### 4단계: 올바른 .ssh 폴더에 키 설정
```bash
# 홈 디렉토리의 .ssh 폴더 확인/생성
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# authorized_keys 파일에 public key 추가
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDgfrTJYGgXtNUQcv0QoTtPy1grrEcVI8PQkZARcZScLqv4oMGnYhkDOHrq8effoBwDMXHK619+u3VweRqpqc2I7Xg18pHqmxSdyN6OM19cOGMDLrag6ju5UsyvwNi6tPz42RXkLqU9yO0Fhdgv38nZh1SIdMRdGEH2rfoJQODsBoTuj47b687P6KPS8oBJNCwJIk4ihtkOiaifDge9TQOhNGoNEQOjzs0mC3upJdUZau9mCFvDAZNwtIcA4rZ8TChabKSs/whi63dT4hVTpQWc/bCotnQgyJMdWFt4f46kj3iOH+NVYtUx3PDw9m6/2IaWJGzzXrvn0xNJoRQulsORdsEHngI38Ob2M1GjxaoyFLv/FN9cMuSxtetFTJBMMYB65goyHDWWMADoISGfK/Wt8b6OXs3KnGEhG1NY6lOfQatoXDt2cYbs3a92IyUYCxyoZr9Rz8PxqIy3hToDJ6U/TSAKBN2EKHjQQ6eD+UWXCW+1kvte0UbqFna15RXxpjfs= crossman@OH-NOTEBOOKYM' >> ~/.ssh/authorized_keys

# 권한 설정
chmod 600 ~/.ssh/authorized_keys

# 설정 확인
ls -la ~/.ssh/
cat ~/.ssh/authorized_keys
```

## 🧪 테스트

### Windows에서 SSH 키 인증 테스트
```powershell
# 올바른 포트로 SSH 접속 테스트
ssh crossman@192.168.0.5 -p 22022

# verbose 모드로 연결 과정 확인
ssh crossman@192.168.0.5 -p 22022 -v

# 키 파일 명시적 지정
ssh crossman@192.168.0.5 -p 22022 -i $env:USERPROFILE\.ssh\id_rsa
```

## 📝 Windows SSH 설정 파일 업데이트
SSH 설정 파일에 포트 정보 추가:
```
# $env:USERPROFILE\.ssh\config
Host nas
    HostName 192.168.0.5
    Port 22022
    User crossman
    IdentityFile ~/.ssh/id_rsa
```

설정 후 간단한 접속:
```powershell
ssh nas
```

## ✅ 성공 확인
- 패스워드 없이 SSH 접속 가능
- .ssh 폴더가 1개만 존재
- authorized_keys 파일 권한이 600
- .ssh 폴더 권한이 700

---
**생성일**: 2025-07-07  
**작성자**: DCEC Development Team  
**중요**: SSH 포트 22022 사용!
