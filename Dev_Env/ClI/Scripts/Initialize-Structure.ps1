# Initialize-Structure.ps1
# 기본 디렉토리 구조 초기화
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$BaseDirectories = @(
    'bin',
    'lib',
    'lib\vendor',
    'lib\Modules',
    'Common',
    'Common\project_templates',
    'config',
    'docs',
    'Logs',
    'Scripts',
    'Tests'
)
# 현재 스크립트의 위치를 기준으로 상위 디렉토리를 Base로 설정
$BasePath = Split-Path -Parent $PSScriptRoot
foreach ($Dir in $BaseDirectories) {
    $Path = Join-Path $BasePath $Dir
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force
        Write-Host "Created directory: $Path"
    }
}
# 기본 설정 파일 생성
$ConfigFiles = @{
    'problem_tracking.json' = @{
        problems = @()
        lastId = 0
        categories = @(
            "Environment",
            "CLI",
            "Integration",
            "Documentation",
            "Performance",
            "Security"
        )
        statuses = @(
            "New",
            "InProgress",
            "Testing",
            "Resolved",
            "Closed"
        )
    }
    'environment.json' = @{
        version = "0.1.0"
        lastUpdate = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        paths = @{
            modules = Join-Path $BasePath "lib\Modules"
            scripts = Join-Path $BasePath "Scripts"
            logs = Join-Path $BasePath "Logs"
            config = Join-Path $BasePath "config"
        }
    }
    'logging.json' = @{
        logLevel = "INFO"
        logPath = Join-Path $BasePath "Logs"
        format = "[{timestamp}] [{level}] {message}"
        rolloverSizeMB = 10
        maxHistory = 30
    }
}
$ConfigPath = Join-Path $BasePath "config"
foreach ($File in $ConfigFiles.Keys) {
    $FilePath = Join-Path $ConfigPath $File
    $ConfigFiles[$File] | ConvertTo-Json -Depth 10 | Set-Content -Path $FilePath -Force
    Write-Host "Created config file: $FilePath"
}
Write-Host "기본 디렉토리 구조 및 설정 파일 생성이 완료되었습니다."
