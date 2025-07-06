#!/bin/bash
# 환경 변수 로드 헬퍼 스크립트

ENV_ROOT="/mnt/d/Dev/DCEC/Dev_Env/Env"

# 전역 환경 변수 로드
function load_global_env() {
    for env_file in "$ENV_ROOT/Global"/*.env; do
        if [ -f "$env_file" ]; then
            source "$env_file"
        fi
    done
}

# 서비스별 환경 변수 로드
function load_service_env() {
    local service=$1
    for env_file in "$ENV_ROOT/Services/$service"/*.env; do
        if [ -f "$env_file" ]; then
            source "$env_file"
        fi
    done
}

# 통합 환경 변수 로드
function load_integration_env() {
    for env_file in "$ENV_ROOT/Integration"/*.env; do
        if [ -f "$env_file" ]; then
            source "$env_file"
        fi
    done
}

# 모든 환경 변수 로드
load_global_env
for service in Claude Gemini Utils; do
    load_service_env "$service"
done
load_integration_env

# 환경 변수 확인을 위한 요약 출력
/usr/bin/echo "[환경 변수 로드 완료]"
/usr/bin/echo "DEV_HOME: $DEV_HOME"
/usr/bin/echo "ENV_HOME: $ENV_HOME"
