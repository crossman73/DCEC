# PowerShell 스크립트 템플릿
param (
    [Parameter(Mandatory=$true)]
    [string]$ScriptName,
    [Parameter(Mandatory=$false)]
    [string]$Description = "",
    [Parameter(Mandatory=$false)]
    [string]$Author = $env:USERNAME,
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0.0"
)
# 엄격한 오류 처리 활성화
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"
# Import 필요한 모듈 확인 및 설치
$RequiredModules = @(
    @{Name="PSScriptAnalyzer"; MinimumVersion="1.21.0"},
    @{Name="Pester"; MinimumVersion="5.4.0"}
)
foreach ($module in $RequiredModules) {
    if (-not(Get-Module -ListAvailable -Name $module.Name |
        Where-Object {$_.Version -ge $module.MinimumVersion})) {
        Install-Module -Name $module.Name -Scope CurrentUser -Force
    }
    Import-Module -Name $module.Name -MinimumVersion $module.MinimumVersion
}
# 스크립트 헤더 템플릿
$ScriptHeader = @"
<#
.SYNOPSIS
    $ScriptName
.DESCRIPTION
    $Description
.NOTES
    File Name  : $ScriptName.ps1
    Author     : $Author
    Version    : $Version
    Created    : $(Get-Date -Format "yyyy-MM-dd")
#>
# 엄격한 오류 처리 활성화
Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"
# 공통 모듈 Import
`$ScriptPath = Split-Path -Parent `$MyInvocation.MyCommand.Path
. "`$ScriptPath\common\logging.ps1"
. "`$ScriptPath\common\error_handling.ps1"
# 전역 변수 및 상수 정의
`$script:Config = @{
    LogPath = Join-Path `$ScriptPath "logs"
    ConfigPath = Join-Path `$ScriptPath "config"
    Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
}
# 함수 정의
function Initialize-Environment {
    [CmdletBinding()]
    param()
    try {
        # 로그 디렉토리 생성
        if (-not(Test-Path `$script:Config.LogPath)) {
            New-Item -Path `$script:Config.LogPath -ItemType Directory -Force | Out-Null
        }
        # 설정 로드
        if (Test-Path (Join-Path `$script:Config.ConfigPath "settings.json")) {
            `$script:Config.Settings = Get-Content -Path (Join-Path `$script:Config.ConfigPath "settings.json") |
                ConvertFrom-Json
        }
        Write-Log -Level INFO -Message "환경 초기화 완료"
    }
    catch {
        Write-Log -Level ERROR -Message "환경 초기화 실패: `$_"
        throw
    }
}
function main {
    try {
        Initialize-Environment
        # 메인 로직 구현
        Write-Log -Level INFO -Message "스크립트 실행 시작"
        # TODO: 여기에 메인 로직 구현
        Write-Log -Level INFO -Message "스크립트 실행 완료"
    }
    catch {
        Write-Log -Level ERROR -Message "스크립트 실행 중 오류 발생: `$_"
        throw
    }
}
# 스크립트 실행
if (`$MyInvocation.InvocationName -ne '.') {
    main
}
"@
# 로깅 모듈 템플릿
$LoggingModule = @'
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    # 로그 파일에 기록
    $logFile = Join-Path $script:Config.LogPath "script_$($script:Config.Timestamp).log"
    Add-Content -Path $logFile -Value $logLine -Encoding UTF8
    # 콘솔에 출력
    switch ($Level) {
        'ERROR' { Write-Error $Message }
        'WARNING' { Write-Warning $Message }
        'INFO' { Write-Verbose $Message }
        'DEBUG' { Write-Debug $Message }
    }
}
'@
# 오류 처리 모듈 템플릿
$ErrorHandlingModule = @'
function Write-ErrorRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )
    $errorMessage = @(
        "예외 발생 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "오류 메시지: $($ErrorRecord.Exception.Message)"
        "오류 종류: $($ErrorRecord.CategoryInfo.Category)"
        "오류 대상: $($ErrorRecord.TargetObject)"
        "스크립트: $($ErrorRecord.InvocationInfo.ScriptName)"
        "라인 번호: $($ErrorRecord.InvocationInfo.ScriptLineNumber)"
        "라인 위치: $($ErrorRecord.InvocationInfo.PositionMessage)"
        "호출 스택:`n$($ErrorRecord.ScriptStackTrace)"
    ) -join "`n"
    Write-Log -Level ERROR -Message $errorMessage
}
function Test-LastError {
    if ($LASTEXITCODE) {
        throw "이전 명령이 종료 코드 $LASTEXITCODE로 실패했습니다."
    }
}
'@
# 테스트 템플릿
$TestTemplate = @'
Describe "ScriptName" {
    BeforeAll {
        . $PSCommandPath.Replace('.Tests.ps1','.ps1')
    }
    Context "기본 기능" {
        It "초기화가 성공적으로 완료됨" {
            # Arrange
            $testPath = "TestDrive:\test"
            # Act
            Initialize-Environment
            # Assert
            $script:Config | Should -Not -BeNull
            Test-Path $script:Config.LogPath | Should -BeTrue
        }
    }
}
'@
# 디렉토리 구조 생성
$ProjectPath = Join-Path $PWD $ScriptName
New-Item -Path $ProjectPath -ItemType Directory -Force | Out-Null
New-Item -Path "$ProjectPath\common" -ItemType Directory -Force | Out-Null
New-Item -Path "$ProjectPath\config" -ItemType Directory -Force | Out-Null
New-Item -Path "$ProjectPath\logs" -ItemType Directory -Force | Out-Null
New-Item -Path "$ProjectPath\tests" -ItemType Directory -Force | Out-Null
# 파일 생성
Set-Content -Path "$ProjectPath\$ScriptName.ps1" -Value $ScriptHeader -Encoding UTF8
Set-Content -Path "$ProjectPath\common\logging.ps1" -Value $LoggingModule -Encoding UTF8
Set-Content -Path "$ProjectPath\common\error_handling.ps1" -Value $ErrorHandlingModule -Encoding UTF8
Set-Content -Path "$ProjectPath\tests\$ScriptName.Tests.ps1" -Value $TestTemplate -Encoding UTF8
# settings.json 템플릿
$SettingsTemplate = @{
    LogLevel = "INFO"
    MaxLogSize = 10MB
    MaxLogAge = 30
    DefaultTimeoutSeconds = 300
} | ConvertTo-Json -Depth 10
Set-Content -Path "$ProjectPath\config\settings.json" -Value $SettingsTemplate -Encoding UTF8
# .gitignore 생성
$GitIgnoreContent = @"
# 로그
logs/
*.log
# 설정
config/secure.env
# PowerShell 관련
*.dll
*.exe
*.msi
*.zip
*.ps1xml
# 임시 파일
[Tt]emp/
*.tmp
*.temp
"@
Set-Content -Path "$ProjectPath\.gitignore" -Value $GitIgnoreContent -Encoding UTF8
Write-Output "PowerShell 프로젝트가 생성되었습니다: $ProjectPath"
