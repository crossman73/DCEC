# 로깅 시스템 함수
function Initialize-Logging {
    param (
        [string]$BaseDir,
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$LogLevel = 'INFO'
    )
    try {
        $script:LogDirectory = Join-Path $BaseDir "logs"
        if (!(Test-Path $script:LogDirectory)) {
            New-Item -Path $script:LogDirectory -ItemType Directory -Force | Out-Null
        }
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $script:LogFile = Join-Path $script:LogDirectory "dcec_${timestamp}.log"
        $script:SessionId = [guid]::NewGuid().ToString()
        Write-Log -Level INFO -Message "로깅 시스템이 초기화되었습니다."
        Write-Log -Level INFO -Message "세션 ID: $script:SessionId"
        Write-Log -Level INFO -Message "로그 레벨: $LogLevel"
        return $script:SessionId
    }
    catch {
        Write-Error "로깅 시스템 초기화 실패: $($_.Exception.Message)"
        throw
    }
}
function Write-Log {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',
        [string]$Category = "일반",
        [string]$ProblemId = "",
        [string]$Result = ""
    )
    if (!$script:LogFile) {
        throw "로깅 시스템이 초기화되지 않았습니다."
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Level] [$Category] $Message"
    if ($ProblemId) {
        $logEntry += " [문제ID: $ProblemId]"
    }
    if ($Result) {
        $logEntry += " [결과: $Result]"
    }
    Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8
    # 콘솔 출력 색상 설정
    $color = switch ($Level) {
        'DEBUG' { 'Gray' }
        'INFO'  { 'White' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'White' }
    }
    Write-Host $logEntry -ForegroundColor $color
}
function Initialize-ChatLogging {
    param (
        [Parameter(Mandatory=$true)]
        [string]$SessionId
    )
    if (!$script:LogDirectory) {
        throw "로깅 시스템이 초기화되지 않았습니다."
    }
    $timestamp = Get-Date -Format "yyyyMMdd"
    $script:ChatLogFile = Join-Path $script:LogDirectory "chat_${timestamp}_${SessionId}.log"
    Write-Log -Level INFO -Message "채팅 로깅이 초기화되었습니다." -Category "채팅"
}
