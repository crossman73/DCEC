# PowerShell Version of claude-project-init.ps1
# Use: Run in PowerShell as administrator (if needed)

# 로그 함수 정의
function log_info($msg)  { Write-Host "[INFO]  $msg" -ForegroundColor Green }
function log_warn($msg)  { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function log_error($msg) { Write-Host "[ERROR] $msg" -ForegroundColor Red }
function log_step($msg)  { Write-Host "[STEP]  $msg" -ForegroundColor Cyan }

# 관리자 권한 확인
function check_windows_admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        log_error "관리자 권한이 필요합니다. PowerShell을 '관리자 권한으로 실행' 해 주세요."
        exit 1
    }
}

# Node.js 버전 확인 (기준: 18.0.0 이상)
function version_greater_equal($v1, $v2) {
    [version]$ver1 = $v1
    [version]$ver2 = $v2
    return ($ver1 -ge $ver2)
}

function check_requirements {
    log_step "환경 확인 중..."

    $nodeVersion = & node -v 2>$null
    if (-not $nodeVersion) {
        log_error "Node.js가 설치되어 있지 않습니다."
        exit 1
    }

    $version = $nodeVersion.TrimStart("v")
    if (-not (version_greater_equal $version "18.0.0")) {
        log_error "Node.js 버전이 너무 낮습니다. 현재: $version, 필요: >= 18.0.0"
        exit 1
    } else {
        log_info "Node.js 버전 확인 완료: $version"
    }

    $pnpmVersion = & pnpm -v 2>$null
    if (-not $pnpmVersion) {
        log_warn "pnpm이 설치되어 있지 않습니다. 설치를 시작합니다..."
        npm install -g pnpm
    } else {
        log_info "pnpm 버전: $pnpmVersion"
    }
}

# 프로젝트 초기화
function init_project {
    log_step "프로젝트 초기화 시작..."

    if (-not (Test-Path "./package.json")) {
        log_info "pnpm init 중..."
        pnpm init
    } else {
        log_info "package.json 이미 존재"
    }

    log_info "필수 패키지 설치 중..."
    pnpm add typescript ts-node @types/node -D

    if (-not (Test-Path "./tsconfig.json")) {
        log_info "tsconfig.json 생성 중..."
        pnpm exec tsc --init
    }

    log_info "초기화 완료"
}

# 실행 흐름
check_windows_admin
check_requirements
init_project
