# 프로젝트 초기화 및 환경 설정 스크립트
param (
    [string]$ProjectName,
    [string]$Description,
    [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
    [string]$LogLevel = 'INFO'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# 모듈 임포트 및 초기화
Import-Module "$PSScriptRoot\..\..\Scripts\modules\core\logging.ps1" -Force
Import-Module "$PSScriptRoot\..\..\Scripts\modules\core\directory_setup.ps1" -Force
# 로깅 초기화
Initialize-Logging -Type "ProjectSetup" -BaseDir $PWD -MinLevel $LogLevel
Write-Log "프로젝트 초기화를 시작합니다: $ProjectName" -Level INFO
Write-ColorLog "프로젝트 초기화를 시작합니다: $ProjectName" -Level INFO -Color Green
# 설정 로드
$configPath = Join-Path $PSScriptRoot "project_config.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json
# 디렉토리 생성
foreach ($dir in $config.environmentSetup.directories) {
    $path = Join-Path $PWD $dir
    New-DirectoryWithContext -Path $path -Description "프로젝트 기본 디렉토리: $dir"
}
# 파일 생성
foreach ($file in $config.environmentSetup.files.PSObject.Properties) {
    $content = $file.Value.ToString()
    $content = $content.Replace('${projectName}', $ProjectName)
    $content = $content.Replace('${description}', $Description)
    $path = Join-Path $PWD $file.Name
    Set-Content -Path $path -Value $content -Encoding UTF8
}
# 환경 설정 파일 생성
$settings = @{
    environment = "development"
    logLevel = $LogLevel
    enableChatLogging = $true
    enableProblemTracking = $true
    projectName = $ProjectName
    description = $Description
    createdAt = (Get-Date).ToString('o')
}
$settingsPath = Join-Path $PWD "config\settings.json"
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
Write-ColorLog "프로젝트 초기화가 완료되었습니다." -Level INFO -Color Green
Write-ChatSummary -SessionId $sessionId
