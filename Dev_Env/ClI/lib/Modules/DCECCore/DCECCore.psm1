# DCEC Core Module
$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = "1.0.0"
# 전역 변수 초기화
$script:LogDirectory = $null
$script:LogFile = $null
$script:SessionId = $null
$script:ChatLogFile = $null
$script:DirectoryHistory = @()
$script:EnvironmentInfo = $null
$script:WorkContext = $null
# 내부 함수 로드
$internalFunctions = @(
    'Initialize-Environment.ps1',
    'Logging.ps1',
    'DirectorySetup.ps1',
    'ProblemTracking.ps1'
)
foreach ($function in $internalFunctions) {
    $functionPath = Join-Path $PSScriptRoot "Functions\$function"
    if (Test-Path $functionPath) {
        . $functionPath
    }
    else {
        Write-Warning "함수 파일을 찾을 수 없음: $function"
    }
}
# 모듈 초기화 코드
$script:Config = @{
    DefaultLogLevel = 'INFO'
    DefaultEncoding = 'UTF8'
    EnableDebugMode = $false
}
# 모듈 초기화 함수
function Initialize-DCECModule {
    param (
        [string]$BasePath = $PWD,
        [string]$LogLevel = 'INFO'
    )
    $script:Config.DefaultLogLevel = $LogLevel
    # 기본 디렉토리 확인 및 생성
    $requiredDirs = @('logs', 'config', 'temp')
    foreach ($dir in $requiredDirs) {
        $path = Join-Path $BasePath $dir
        if (!(Test-Path $path)) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }
    # 로깅 초기화
    Initialize-Logging -BaseDir $BasePath -LogLevel $LogLevel
    Write-Log -Level INFO -Message "DCEC 모듈이 초기화되었습니다. 버전: $script:ModuleVersion"
}
# 모듈 언로드 시 정리 작업
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Log -Level INFO -Message "DCEC 모듈이 언로드됩니다."
}
