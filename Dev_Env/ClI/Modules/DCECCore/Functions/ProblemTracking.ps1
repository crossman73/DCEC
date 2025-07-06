# Functions/ProblemTracking.ps1
# 전역 설정
$Script:ProblemTrackingDefaults = @{
    ConfigPath = Join-Path $env:DCEC_CLI "config\problem_tracking.json"
    BackupPath = Join-Path $env:DCEC_CLI "config\problem_tracking_backup"
    LogPath = Join-Path $env:DCEC_CLI "logs\problem_tracking.log"
    Categories = @(
        "Environment",
        "CLI",
        "Integration",
        "Documentation",
        "Performance",
        "Security",
        "Testing",
        "Other"
    )
    Statuses = @(
        "New",
        "InProgress",
        "Testing",
        "Resolved",
        "Closed",
        "Reopened"
    )
    PriorityLevels = @{
        1 = "Critical"
        2 = "High"
        3 = "Medium"
        4 = "Low"
        5 = "Planning"
    }
}
function Write-ProblemLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $Script:ProblemTrackingDefaults.LogPath -Value $logMessage
    switch ($Level) {
        "WARNING" { Write-Warning $Message }
        "ERROR" { Write-Error $Message }
        default { Write-Verbose $Message }
    }
}
function Backup-ProblemTracking {
    $backupDir = $Script:ProblemTrackingDefaults.BackupPath
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = Join-Path $backupDir "problem_tracking_$timestamp.json"
    try {
        Copy-Item -Path $Script:ProblemTrackingDefaults.ConfigPath -Destination $backupFile -Force
        Write-ProblemLog "문제 추적 데이터 백업 완료: $backupFile" -Level "INFO"
    }
    catch {
        Write-ProblemLog "문제 추적 데이터 백업 실패: $_" -Level "ERROR"
        throw
    }
}
function Initialize-ProblemTracking {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$ConfigPath = $Script:ProblemTrackingDefaults.ConfigPath,
        [switch]$Force
    )
    # 로그 디렉토리 생성
    $logDir = Split-Path $Script:ProblemTrackingDefaults.LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    # 설정 파일 로드 또는 생성
    try {
        if (Test-Path $ConfigPath) {
            if ($Force) {
                Backup-ProblemTracking
            }
            $Script:ProblemTrackingConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            Write-ProblemLog "문제 추적 설정 로드 완료" -Level "INFO"
        }
        else {
            $Script:ProblemTrackingConfig = @{
                problems = @()
                lastId = 0
                categories = $Script:ProblemTrackingDefaults.Categories
                statuses = $Script:ProblemTrackingDefaults.Statuses
                priorityLevels = $Script:ProblemTrackingDefaults.PriorityLevels
                lastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $configDir = Split-Path $ConfigPath -Parent
            if (-not (Test-Path $configDir)) {
                New-Item -Path $configDir -ItemType Directory -Force | Out-Null
            }
            $Script:ProblemTrackingConfig | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
            Write-ProblemLog "새 문제 추적 설정 파일 생성 완료" -Level "INFO"
        }
    }
    catch {
        Write-ProblemLog "문제 추적 초기화 실패: $_" -Level "ERROR"
        throw
    }
}
function New-Problem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            $_ -in $Script:ProblemTrackingDefaults.Categories
        })]
        [string]$Category,
        [Parameter(Mandatory=$false)]
        [string]$AssignedTo,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,5)]
        [int]$Priority = 3,
        [Parameter(Mandatory=$false)]
        [ValidateScript({
            $_ -in $Script:ProblemTrackingDefaults.Statuses
        })]
        [string]$Status = "New",
        [Parameter(Mandatory=$false)]
        [string[]]$Tags,
        [Parameter(Mandatory=$false)]
        [string]$RelatedTo
    )
    if (-not $Script:ProblemTrackingConfig) {
        Initialize-ProblemTracking
    }
    try {
        # 백업
        Backup-ProblemTracking
        $Script:ProblemTrackingConfig.lastId++
        $NewProblem = @{
            id = $Script:ProblemTrackingConfig.lastId
            title = $Title
            description = $Description
            category = $Category
            status = $Status
            assignedTo = $AssignedTo
            priority = $Priority
            priorityText = $Script:ProblemTrackingDefaults.PriorityLevels[$Priority]
            tags = $Tags
            relatedTo = $RelatedTo
            createdDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            lastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            history = @()
        }
        $Script:ProblemTrackingConfig.problems += $NewProblem
        Save-ProblemTrackingConfig
        Write-ProblemLog "새 문제 등록 완료: [$($NewProblem.id)] $Title" -Level "INFO"
        return $NewProblem
    }
    catch {
        Write-ProblemLog "문제 등록 실패: $_" -Level "ERROR"
        throw
    }
}
function Update-Problem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]$Id,
        [Parameter(Mandatory=$false)]
        [ValidateScript({
            $_ -in $Script:ProblemTrackingDefaults.Statuses
        })]
        [string]$Status,
        [Parameter(Mandatory=$false)]
        [string]$AssignedTo,
        [Parameter(Mandatory=$false)]
        [string]$Resolution,
        [Parameter(Mandatory=$false)]
        [ValidateRange(1,5)]
        [int]$Priority,
        [Parameter(Mandatory=$false)]
        [string]$Comment,
        [Parameter(Mandatory=$false)]
        [string[]]$Tags,
        [Parameter(Mandatory=$false)]
        [string]$RelatedTo
    )
    if (-not $Script:ProblemTrackingConfig) {
        Initialize-ProblemTracking
    }
    try {
        $Problem = $Script:ProblemTrackingConfig.problems | Where-Object { $_.id -eq $Id }
        if (-not $Problem) {
            throw "문제 ID $Id를 찾을 수 없습니다."
        }
        # 백업
        Backup-ProblemTracking
        # 이전 상태 저장
        $oldState = @{
            status = $Problem.status
            assignedTo = $Problem.assignedTo
            priority = $Problem.priority
            resolution = $Problem.resolution
        }
        # 변경사항 적용
        if ($Status) {
            $Problem.status = $Status
            # 재오픈 처리
            if ($Status -eq "Reopened" -and $oldState.status -in @("Resolved", "Closed")) {
                $Comment = "문제가 재오픈되었습니다." + $(if ($Comment) { " - $Comment" } else { "" })
            }
        }
        if ($AssignedTo) { $Problem.assignedTo = $AssignedTo }
        if ($Priority) {
            $Problem.priority = $Priority
            $Problem.priorityText = $Script:ProblemTrackingDefaults.PriorityLevels[$Priority]
        }
        if ($Resolution) { $Problem.resolution = $Resolution }
        if ($Tags) { $Problem.tags = $Tags }
        if ($RelatedTo) { $Problem.relatedTo = $RelatedTo }
        # 변경 이력 추가
        $changes = @()
        if ($Status -and $Status -ne $oldState.status) {
            $changes += "상태: $($oldState.status) -> $Status"
        }
        if ($AssignedTo -and $AssignedTo -ne $oldState.assignedTo) {
            $changes += "담당자: $($oldState.assignedTo) -> $AssignedTo"
        }
        if ($Priority -and $Priority -ne $oldState.priority) {
            $changes += "우선순위: $($oldState.priority) -> $Priority"
        }
        if (-not $Problem.history) {
            $Problem.history = @()
        }
        $historyEntry = @{
            timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            changes = $changes
            comment = $Comment
        }
        $Problem.history += $historyEntry
        $Problem.lastModified = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Save-ProblemTrackingConfig
        Write-ProblemLog "문제 업데이트 완료: [$Id] $(if($changes){$changes -join ', '})" -Level "INFO"
    }
    catch {
        Write-ProblemLog "문제 업데이트 실패: $_" -Level "ERROR"
        throw
    }
}
function Get-ProblemReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Status,
        [Parameter(Mandatory=$false)]
        [string]$Category,
        [Parameter(Mandatory=$false)]
        [string]$AssignedTo
    )
    if (-not $Script:ProblemTrackingConfig) {
        Initialize-ProblemTracking
    }
    $Problems = $Script:ProblemTrackingConfig.problems
    if ($Status) {
        $Problems = $Problems | Where-Object { $_.status -eq $Status }
    }
    if ($Category) {
        $Problems = $Problems | Where-Object { $_.category -eq $Category }
    }
    if ($AssignedTo) {
        $Problems = $Problems | Where-Object { $_.assignedTo -eq $AssignedTo }
    }
    return $Problems
}
function Get-ProblemDetails {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]$Id
    )
    if (-not $Script:ProblemTrackingConfig) {
        Initialize-ProblemTracking
    }
    $Problem = $Script:ProblemTrackingConfig.problems | Where-Object { $_.id -eq $Id }
    if (-not $Problem) {
        throw "문제 ID $Id를 찾을 수 없습니다."
    }
    return $Problem
}
function Get-ProblemSummary {
    [CmdletBinding()]
    param (
        [switch]$GenerateReport
    )
    if (-not $Script:ProblemTrackingConfig) {
        Initialize-ProblemTracking
    }
    $summary = @{
        totalCount = $Script:ProblemTrackingConfig.problems.Count
        byStatus = $Script:ProblemTrackingConfig.problems | Group-Object status | ForEach-Object {
            @{
                status = $_.Name
                count = $_.Count
            }
        }
        byCategory = $Script:ProblemTrackingConfig.problems | Group-Object category | ForEach-Object {
            @{
                category = $_.Name
                count = $_.Count
            }
        }
        byPriority = $Script:ProblemTrackingConfig.problems | Group-Object priority | ForEach-Object {
            @{
                priority = $_.Name
                count = $_.Count
            }
        }
    }
    if ($GenerateReport) {
        $reportPath = Join-Path (Split-Path $Script:ProblemTrackingDefaults.ConfigPath -Parent) "problem_summary.md"
        $report = @"
# 문제 추적 요약 보고서
생성 시간: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
## 전체 통계
- 총 문제 수: $($summary.totalCount)
## 상태별 통계
$(($summary.byStatus | ForEach-Object { "- $($_.status): $($_.count)" }) -join "`n")
## 카테고리별 통계
$(($summary.byCategory | ForEach-Object { "- $($_.category): $($_.count)" }) -join "`n")
## 우선순위별 통계
$(($summary.byPriority | ForEach-Object {
    $priorityText = $Script:ProblemTrackingDefaults.PriorityLevels[$_.priority]
    "- $priorityText (Level $($_.priority)): $($_.count)"
}) -join "`n")
## 최근 업데이트된 문제
$($Script:ProblemTrackingConfig.problems |
    Sort-Object lastModified -Descending |
    Select-Object -First 5 |
    ForEach-Object { "- [$($_.id)] $($_.title) ($(Get-Date $_.lastModified -Format 'MM-dd HH:mm'))" } |
    Join-String -Separator "`n")
"@
        $report | Set-Content $reportPath -Encoding utf8
        return $reportPath
    }
    return $summary
}
function Save-ProblemTrackingConfig {
    try {
        $Script:ProblemTrackingConfig |
            ConvertTo-Json -Depth 10 |
            Set-Content $Script:ProblemTrackingDefaults.ConfigPath -Encoding utf8
        Write-ProblemLog "문제 추적 설정 저장 완료" -Level "INFO"
    }
    catch {
        Write-ProblemLog "문제 추적 설정 저장 실패: $_" -Level "ERROR"
        throw
    }
}
# 모듈 내보내기
Export-ModuleMember -Function @(
    'Initialize-ProblemTracking',
    'New-Problem',
    'Update-Problem',
    'Get-ProblemReport',
    'Get-ProblemDetails',
    'Get-ProblemSummary',
    'Backup-ProblemTracking'
)
