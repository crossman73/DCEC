# 로깅 기능 모듈
# PowerShell 스타일 가이드를 준수하는 로깅 시스템
# 로그 레벨 enum 정의
enum LogLevel {
    INFO = 0
    WARNING = 1
    ERROR = 2
    DEBUG = 3
}
# 색상 매핑
$script:LogColors = @{
    INFO = 'White'
    WARNING = 'Yellow'
    ERROR = 'Red'
    DEBUG = 'Cyan'
}
# 스크립트 전역 변수
$script:LogType = ""
$script:LogFile = ""
$script:MinLogLevel = [LogLevel]::INFO
# 채팅 로그 관련 변수
$script:ChatLogDir = ""
$script:CurrentChatFile = ""
$script:ChatSummaryPoints = @()
# 세션 및 로그 추적 변수
$script:SessionId = ""
$script:LogCounter = 0
$script:ProblemTracker = @{}
function Initialize-Logging {
    param (
        [string]$Type,
        [string]$BaseDir,
        [LogLevel]$MinLevel = [LogLevel]::INFO
    )
    try {
        $now = Get-Date -Format "yyyyMMdd_HHmmss"
        $script:LogType = $Type
        $script:MinLogLevel = $MinLevel
        $script:SessionId = "SESSION_${Type}_$now"
        $script:LogCounter = 0
        $LogDir = Join-Path $BaseDir "logs"
        if (!(Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }
        $script:LogFile = Join-Path $LogDir ("${Type}_$now.log")
        Write-Log -Level INFO -Message "로깅 초기화 완료" -Result $script:LogFile -Category "시스템"
    }
    catch {
        Write-Error "로깅 초기화 실패: $_"
        throw
    }
}
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [LogLevel]$Level,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Result = "",
        [string]$Category = "일반",
        [string]$ProblemId = ""
    )
    if ($Level -lt $script:MinLogLevel) { return }
    try {
        $script:LogCounter++
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logNumber = $script:LogCounter.ToString("000")
        # 문제 추적 ID 처리
        if ($ProblemId -ne "") {
            if (!$script:ProblemTracker.ContainsKey($ProblemId)) {
                $script:ProblemTracker[$ProblemId] = @{
                    StartTime = $timestamp
                    Status = "진행중"
                    LogEntries = @()
                }
            }
            $script:ProblemTracker[$ProblemId].LogEntries += $logNumber
        }
        $logLine = "[$script:SessionId][$logNumber][$timestamp][$Category][$Level] $Message"
        if ($Result -ne "") { $logLine += " [$Result]" }
        if ($ProblemId -ne "") { $logLine += " [문제ID:$ProblemId]" }
        # 콘솔에 색상을 적용하여 출력
        Write-Host $logLine -ForegroundColor $script:LogColors[$Level.ToString()]
        # 파일에 로그 기록
        if ($script:LogFile) {
            $logLine | Out-File -FilePath $script:LogFile -Append -Encoding utf8
        }
    }
    catch {
        Write-Error "로그 기록 실패: $_"
    }
}
function Initialize-ChatLogging {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ProjectName,
        [string]$BaseDir = $(if ($script:LogFile) { Split-Path $script:LogFile -Parent } else { "." }),
        [string]$ProblemId = ""
    )
    try {
        # 채팅 로그 디렉토리 생성
        $script:ChatLogDir = Join-Path $BaseDir "chat"
        if (!(Test-Path $script:ChatLogDir)) {
            New-Item -Path $script:ChatLogDir -ItemType Directory -Force | Out-Null
        }
        # 채팅 로그 파일 생성 (세션 ID 포함)
        $timestamp = Get-Date -Format "yyMMddHHmmss"
        $script:CurrentChatFile = Join-Path $script:ChatLogDir "${ProjectName}_${timestamp}.chat"
        # 채팅 로그 파일 헤더 작성
        @"
===========================================
Session ID: $script:SessionId
Project: $ProjectName
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Problem ID: $($ProblemId ? $ProblemId : "N/A")
===========================================
"@ | Out-File -FilePath $script:CurrentChatFile -Encoding utf8
        Write-Log -Level INFO -Message "채팅 로그 초기화 완료" -Result $script:CurrentChatFile -Category "채팅" -ProblemId $ProblemId
    }
    catch {
        Write-Log -Level ERROR -Message "채팅 로그 초기화 실패" -Result $_.Exception.Message -Category "채팅" -ProblemId $ProblemId
        throw
    }
}
function Add-ChatMessage {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet('User', 'Assistant')]
        [string]$Sender,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$ProblemId = ""
    )
    if (!$script:CurrentChatFile) {
        Write-Log -Level ERROR -Message "채팅 로그가 초기화되지 않았습니다." -Category "채팅"
        return
    }
    try {
        $logNumber = $script:LogCounter + 1
        $timestamp = Get-Date -Format "HH:mm:ss"
        $chatEntry = @"
[$logNumber][$timestamp] ${Sender}:
$Message
"@
        $chatEntry | Out-File -FilePath $script:CurrentChatFile -Append -Encoding utf8
        Write-Log -Level DEBUG -Message "채팅 메시지 기록" -Result "$Sender 메시지" -Category "채팅" -ProblemId $ProblemId
    }
    catch {
        Write-Log -Level ERROR -Message "채팅 메시지 기록 실패" -Result $_.Exception.Message -Category "채팅" -ProblemId $ProblemId
    }
}
function Start-ProblemTracking {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ProblemId,
        [Parameter(Mandatory=$true)]
        [string]$Description
    )
    $script:ProblemTracker[$ProblemId] = @{
        StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Description = $Description
        Status = "시작됨"
        LogEntries = @()
    }
    Write-Log -Level INFO -Message "문제 추적 시작: $Description" -Category "문제추적" -ProblemId $ProblemId
}
function Update-ProblemStatus {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ProblemId,
        [Parameter(Mandatory=$true)]
        [ValidateSet('진행중', '해결됨', '실패')]
        [string]$Status,
        [string]$Resolution = ""
    )
    if ($script:ProblemTracker.ContainsKey($ProblemId)) {
        $script:ProblemTracker[$ProblemId].Status = $Status
        if ($Resolution) {
            $script:ProblemTracker[$ProblemId].Resolution = $Resolution
        }
        Write-Log -Level INFO -Message "문제 상태 업데이트: $Status" -Result $Resolution -Category "문제추적" -ProblemId $ProblemId
        if ($Status -eq '해결됨' -and $script:CurrentChatFile) {
            @"
[문제 해결 완료 - $ProblemId]
해결 시각: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
해결 내용: $Resolution
"@ | Out-File -FilePath $script:CurrentChatFile -Append -Encoding utf8
        }
    }
}
function Write-ChatSummary {
    if (!$script:CurrentChatFile -or $script:ChatSummaryPoints.Count -eq 0) {
        Write-Log -Level WARNING -Message "작성할 채팅 요약이 없습니다." -Category "채팅"
        return
    }
    try {
        @"
===========================================
대화 요약 (세션: $script:SessionId)
===========================================
"@ | Out-File -FilePath $script:CurrentChatFile -Append -Encoding utf8
        foreach ($point in $script:ChatSummaryPoints) {
            "- $point" | Out-File -FilePath $script:CurrentChatFile -Append -Encoding utf8
        }
        # 문제 추적 요약 추가
        if ($script:ProblemTracker.Count -gt 0) {
            @"
문제 해결 현황:
-------------------------------------------
"@ | Out-File -FilePath $script:CurrentChatFile -Append -Encoding utf8
            foreach ($problem in $script:ProblemTracker.GetEnumerator()) {
                @"
[$($problem.Key)]
- 상태: $($problem.Value.Status)
- 시작: $($problem.Value.StartTime)
- 설명: $($problem.Value.Description)
$(if ($problem.Value.Resolution) {"- 해결: $($problem.Value.Resolution)"})
"@ | Out-File -FilePath $script:CurrentChatFile -Append -Encoding utf8
            }
        }
        "`n" | Out-File -FilePath $script:CurrentChatFile -Append -Encoding utf8
        Write-Log -Level INFO -Message "채팅 요약 작성 완료" -Category "채팅"
    }
    catch {
        Write-Log -Level ERROR -Message "채팅 요약 작성 실패" -Result $_.Exception.Message -Category "채팅"
    }
}
Export-ModuleMember -Function Initialize-Logging, Write-Log, Initialize-ChatLogging, Add-ChatMessage,
    Add-ChatSummaryPoint, Write-ChatSummary, Start-ProblemTracking, Update-ProblemStatus
