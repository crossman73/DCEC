#!/bin/bash
# SSH 키 자동 등록 스크립트

# 공개키 내용
PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPVX3LWy6zG81yun+EeCWgx7T/FTyhkiBCAVPJeOPB0I crossman737@gmail.com"

echo "=== SSH 키 등록 시작 ==="

# .ssh 디렉토리 생성
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# authorized_keys 파일에 공개키 추가 (중복 방지)
if ! grep -q "$PUBLIC_KEY" ~/.ssh/authorized_keys 2>/dev/null; then
    echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
    echo "✅ SSH 공개키가 추가되었습니다."
else
    echo "ℹ️ SSH 공개키가 이미 등록되어 있습니다."
fi

# 권한 설정
chmod 600 ~/.ssh/authorized_keys

# 결과 확인
echo "=== SSH 키 등록 결과 ==="
echo "📁 .ssh 디렉토리 권한: $(ls -ld ~/.ssh)"
echo "📄 authorized_keys 권한: $(ls -l ~/.ssh/authorized_keys)"
echo "🔑 등록된 키 개수: $(wc -l < ~/.ssh/authorized_keys)"

echo "=== 등록 완료 ==="
