#!/bin/bash
# WSL2 환경에서 Gemini CLI와 Claude Code 사용 시 로그를 남기는 래퍼 스크립트
# 사용 예시:
#   ./ai_tool_wrapper.sh gemini "Create a REST API for user management"
#   ./ai_tool_wrapper.sh claude-code "Review and enhance the API design"

LOG_DIR="/mnt/d/Dev/DCEC/Dev_Env/ClI/logs"
if [ ! -d "$LOG_DIR" ]; then
  mkdir -p "$LOG_DIR"
fi
NOW=$(date '+%Y%m%d_%H%M%S')
LOG_TYPE="AIWRAP"
LOG_FILE="$LOG_DIR/${LOG_TYPE}_$NOW.log"
TOOL=$1
PROMPT=$2
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')


# 프롬프트 및 결과 로그 기록 (규칙 적용)
function log_prompt() {
    echo "$TIMESTAMP [$LOG_TYPE] $TOOL - $PROMPT [START]" >> "$LOG_FILE"
}

function log_result() {
    echo "$TIMESTAMP [$LOG_TYPE] $TOOL RESULT START" >> "$LOG_FILE"
    cat "$1" >> "$LOG_FILE"
    echo "$TIMESTAMP [$LOG_TYPE] $TOOL RESULT END" >> "$LOG_FILE"
}

if [ -z "$TOOL" ] || [ -z "$PROMPT" ]; then
    echo "사용법: $0 [gemini|claude-code] '프롬프트'"
    exit 1
fi

TMP_OUT="/tmp/ai_tool_result.txt"
log_prompt

if [ "$TOOL" = "gemini" ]; then
    gemini "$PROMPT" | tee "$TMP_OUT"
elif [ "$TOOL" = "claude-code" ]; then
    claude-code "$PROMPT" | tee "$TMP_OUT"
else
    echo "지원하지 않는 도구입니다: $TOOL"
    exit 2
fi

log_result "$TMP_OUT"
rm -f "$TMP_OUT"
