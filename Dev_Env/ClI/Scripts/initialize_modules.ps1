# 모듈 초기화 스크립트
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# 현재 스크립트 위치 기준으로 모듈 경로 설정
$scriptRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $scriptRoot "lib\core"
if ($env:PSModulePath -notlike "*$modulePath*") {
    $env:PSModulePath = $modulePath + [System.IO.Path]::PathSeparator + $env:PSModulePath
}
Write-Host "모듈 경로: $modulePath" -ForegroundColor Cyan
# 필수 모듈 임포트
$requiredModules = @(
    'logging_system',
    'directory_setup',
    'problem_tracking',
    'env_manager',
    'directory_manager',
    'doc_log_manager',
    'doc_template_manager'
)
foreach ($module in $requiredModules) {
    $moduleName = $module
    $moduleFile = Join-Path $modulePath "$moduleName.ps1"
    Write-Host "모듈 파일 확인: $moduleFile" -ForegroundColor Cyan
    if (Test-Path $moduleFile) {
        try {
            . $moduleFile
            Write-Host "모듈 로드됨: $moduleName" -ForegroundColor Green
        }
        catch {
            Write-Host "모듈 로드 실패: $moduleName - $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
    else {
        Write-Host "모듈을 찾을 수 없음: $moduleFile" -ForegroundColor Yellow
    }
}
# 환경 설정 초기화
$configDir = Join-Path $scriptRoot "config"
$logsDir = Join-Path $scriptRoot "logs"
if (!(Test-Path $configDir)) {
    New-Item -Path $configDir -ItemType Directory -Force | Out-Null
}
if (!(Test-Path $logsDir)) {
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
}
Write-Host "모듈 초기화 완료" -ForegroundColor Green
