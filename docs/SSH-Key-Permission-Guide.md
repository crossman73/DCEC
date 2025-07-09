# SSH 키 권한 설정 가이드

## 현재 상태 확인

NAS에서 다음 명령어들로 현재 권한을 확인하세요:

```bash
# 현재 디렉토리와 파일 권한 확인
ls -la ~/.ssh/

# 각 파일의 상세 권한 확인
ls -l ~/.ssh/authorized_keys
ls -l ~/.ssh/id_rsa
ls -l ~/.ssh/id_rsa.pub
```

## 올바른 권한 설정

### 1. .ssh 디렉토리 권한
```bash
chmod 700 ~/.ssh
```

### 2. 개인키 파일 권한 (id_rsa)
```bash
chmod 600 ~/.ssh/id_rsa
```

### 3. 공개키 파일 권한 (id_rsa.pub)
```bash
chmod 644 ~/.ssh/id_rsa.pub
```

### 4. authorized_keys 파일 권한
```bash
chmod 600 ~/.ssh/authorized_keys
```

### 5. known_hosts 파일 권한
```bash
chmod 644 ~/.ssh/known_hosts
```

## 소유권 확인 및 설정

```bash
# 현재 소유권 확인
ls -la ~/.ssh/

# 필요시 소유권 변경 (crossman 사용자로)
chown crossman:users ~/.ssh/
chown crossman:users ~/.ssh/*
```

## 권한 설정 스크립트 (한 번에 실행)

```bash
# 한 번에 모든 권한 설정
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub
chmod 600 ~/.ssh/authorized_keys
chmod 644 ~/.ssh/known_hosts

# 소유권 확인
chown crossman:users ~/.ssh/
chown crossman:users ~/.ssh/*

echo "SSH 키 권한 설정 완료"
ls -la ~/.ssh/
```

## authorized_keys 파일 확인 및 수정

```bash
# authorized_keys 내용 확인
cat ~/.ssh/authorized_keys

# Windows에서 생성한 공개키 추가 (필요시)
# id_rsa.pub 내용을 authorized_keys에 추가
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDgfrTJYGgXtNUQcv0QoTtPy1grr..." >> ~/.ssh/authorized_keys

# 중복 제거 (필요시)
sort ~/.ssh/authorized_keys | uniq > ~/.ssh/authorized_keys.tmp
mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys

# 권한 다시 설정
chmod 600 ~/.ssh/authorized_keys
```

## SSH 데몬 설정 확인

```bash
# SSH 설정 확인
sudo grep -E "(PubkeyAuthentication|AuthorizedKeysFile|PasswordAuthentication)" /etc/ssh/sshd_config

# 필요시 SSH 서비스 재시작
sudo systemctl restart ssh
```

## 트러블슈팅

### 1. 권한 문제 해결
```bash
# 모든 권한 재설정
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/.ssh/authorized_keys
chmod 644 ~/.ssh/id_rsa.pub
chmod 644 ~/.ssh/known_hosts
```

### 2. SELinux 문제 (해당시)
```bash
# SELinux 컨텍스트 확인
ls -Z ~/.ssh/

# SELinux 컨텍스트 복원
restorecon -R ~/.ssh/
```

### 3. SSH 연결 테스트
```bash
# 로컬에서 테스트
ssh -i ~/.ssh/id_rsa -p 22022 crossman@192.168.0.5 -v
```

## 성공 지표

권한 설정이 완료되면 다음과 같이 표시되어야 합니다:

```
drwx------ 2 crossman users  4096 Jul  7 14:30 .ssh/
-rw------- 1 crossman users  1675 Jul  7 14:30 id_rsa
-rw-r--r-- 1 crossman users   401 Jul  7 14:30 id_rsa.pub
-rw------- 1 crossman users   401 Jul  7 14:30 authorized_keys
-rw-r--r-- 1 crossman users   444 Jul  7 14:30 known_hosts
```

---
**참고**: 권한 설정 후 SSH 연결이 여전히 안 될 경우, SSH 로그를 확인하세요:
```bash
sudo tail -f /var/log/auth.log
```
