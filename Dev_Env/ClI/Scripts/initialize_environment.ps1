# 환경 초기화 스크립트
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# 모듈 경로 설정
$modulesPath = Join-Path (Split-Path -Parent $PSScriptRoot) "lib\Modules"
if ($env:PSModulePath -notlike "*$modulesPath*") {
    $env:PSModulePath = $modulesPath + [System.IO.Path]::PathSeparator + $env:PSModulePath
}
Write-Host "DCEC 환경 초기화를 시작합니다..." -ForegroundColor Cyan
try {
    # DCECCore 모듈 임포트
    Import-Module DCECCore -Force
    # 모듈 초기화
    Initialize-DCECModule -BasePath $PSScriptRoot -LogLevel 'INFO'
    Write-Host "DCEC 환경이 성공적으로 초기화되었습니다." -ForegroundColor Green
}
catch {
    Write-Host "DCEC 환경 초기화 실패: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
