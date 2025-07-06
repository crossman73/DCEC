# Initialize-DCECEnvironment.ps1
# DCEC 환경 초기화 스크립트
$ErrorActionPreference = 'Stop'
try {
    # 모듈 경로 설정
    $ModulePath = Join-Path $PSScriptRoot "Modules"
    if ($env:PSModulePath -notlike "*$ModulePath*") {
        $env:PSModulePath = "$ModulePath;$env:PSModulePath"
    }
    # DCECCore 모듈 임포트
    Import-Module DCECCore -Force
    # 환경 초기화
    Install-DCECEnvironment -BasePath $PSScriptRoot
    Write-Host "DCEC environment initialized successfully."
}
catch {
    Write-Error "환경 초기화 중 오류가 발생했습니다: $_"
    exit 1
}
