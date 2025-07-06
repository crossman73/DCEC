#!/bin/bash
# WSL2 개발환경 기본 세팅 스크립트
# 로그: /mnt/d/Dev/DCEC/Dev_Env/ClI/logs/WSLENV_$(date +%Y%m%d_%H%M%S).log

LOG_DIR="/mnt/d/Dev/DCEC/Dev_Env/ClI/logs"
NOW=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$LOG_DIR/WSLENV_${NOW}.log"

mkdir -p "$LOG_DIR"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [WSLENV] $1" | tee -a "$LOG_FILE"
}

log "WSL2 환경 세팅 시작"

# 1. 기본 경로 세팅
if ! grep -q 'cd /mnt/d/Dev/DCEC' ~/.bashrc; then
  echo 'cd /mnt/d/Dev/DCEC' >> ~/.bashrc
  log "~/.bashrc에 기본 작업 디렉토리 추가: cd /mnt/d/Dev/DCEC"
else
  log "~/.bashrc에 기본 작업 디렉토리 이미 존재"
fi

# 2. npm 글로벌 경로 PATH 추가
NPM_BIN=$(npm bin -g)
if ! grep -q "$NPM_BIN" ~/.bashrc; then
  echo "export PATH=\$PATH:$NPM_BIN" >> ~/.bashrc
  log "~/.bashrc에 npm 글로벌 경로 추가: $NPM_BIN"
else
  log "~/.bashrc에 npm 글로벌 경로 이미 존재: $NPM_BIN"
fi

# 3. 기타 개발 편의 alias 예시
if ! grep -q 'alias ll=' ~/.bashrc; then
  echo "alias ll='ls -alF'" >> ~/.bashrc
  log "~/.bashrc에 alias ll 추가"
fi

log "WSL2 환경 세팅 완료. bash 재시작 또는 'source ~/.bashrc' 필요"
