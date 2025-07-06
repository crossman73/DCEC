# ProblemTracking.ps1
# 스크립트 전역 변수
$script:ProblemTracker = $null
$script:ProblemConfig = $null
$script:LastSyncTime = $null
function Initialize-ProblemTracking {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$ConfigPath = "D:\Dev\DCEC\Dev_Env\ClI\config\problems",
        [Parameter(Mandatory=$false)]
        [string]$DataFile = "problem_list.csv"
    )
    try {
        # 설정 디렉토리 확인 및 생성
        if (-not (Test-Path $ConfigPath)) {
            New-Item -ItemType Directory -Path $ConfigPath -Force | Out-Null
            Write-Log -Level INFO -Message "문제 추적 설정 디렉토리 생성됨: $ConfigPath"
        }
        $dataFilePath = Join-Path $ConfigPath $DataFile
        # CSV 파일이 존재하지 않으면 새로 생성
        if (-not (Test-Path $dataFilePath)) {
            "Id,Title,Description,Category,Priority,AssignedTo,Status" |
                Out-File -FilePath $dataFilePath -Encoding UTF8
            Write-Log -Level INFO -Message "새 문제 추적 데이터 파일 생성됨: $dataFilePath"
        }
        # 데이터 로드
        $script:ProblemTracker = Import-Csv -Path $dataFilePath
        $script:LastSyncTime = Get-Date
        # 상태 요약 출력
        $summary = $script:ProblemTracker | Group-Object Status |
            Select-Object @{N='상태';E={$_.Name}}, @{N='개수';E={$_.Count}}
        Write-Log -Level INFO -Message "문제 추적 시스템 초기화 완료"
        Write-Log -Level INFO -Message "문제 상태 요약:`n$($summary | Format-Table | Out-String)"
        return $true
    }
    catch {
        Write-Log -Level ERROR -Message "문제 추적 시스템 초기화 실패: $_"
        throw
    }
}
function Add-Problem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [string]$Category,
        [Parameter(Mandatory=$false)]
        [int]$Priority = 3,
        [Parameter(Mandatory=$false)]
        [string]$AssignedTo = "",
        [Parameter(Mandatory=$false)]
        [string]$Status = "New"
    )
    try {
        if (-not $script:ProblemTracker) {
            Initialize-ProblemTracking
        }
        # 새 ID 생성
        $newId = 1
        if ($script:ProblemTracker.Count -gt 0) {
            $newId = ($script:ProblemTracker.Id | Measure-Object -Maximum).Maximum + 1
        }
        # 새 문제 생성
        $newProblem = [PSCustomObject]@{
            Id = $newId
            Title = $Title
            Description = $Description
            Category = $Category
            Priority = $Priority
            AssignedTo = $AssignedTo
            Status = $Status
        }
        # 문제 추가 및 저장
        $script:ProblemTracker += $newProblem
        Save-ProblemData
        Write-Log -Level INFO -Message "새 문제 추가됨: [$newId] $Title"
        return $newProblem
    }
    catch {
        Write-Log -Level ERROR -Message "문제 추가 실패: $_"
        throw
    }
}
function Update-Problem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]$Id,
        [Parameter(Mandatory=$false)]
        [string]$Title,
        [Parameter(Mandatory=$false)]
        [string]$Description,
        [Parameter(Mandatory=$false)]
        [string]$Status,
        [Parameter(Mandatory=$false)]
        [int]$Priority,
        [Parameter(Mandatory=$false)]
        [string]$AssignedTo
    )
    try {
        if (-not $script:ProblemTracker) {
            Initialize-ProblemTracking
        }
        $problem = $script:ProblemTracker | Where-Object { $_.Id -eq $Id }
        if (-not $problem) {
            throw "문제 ID $Id를 찾을 수 없습니다."
        }
        # 필드 업데이트
        if ($Title) { $problem.Title = $Title }
        if ($Description) { $problem.Description = $Description }
        if ($Status) { $problem.Status = $Status }
        if ($Priority) { $problem.Priority = $Priority }
        if ($AssignedTo) { $problem.AssignedTo = $AssignedTo }
        Save-ProblemData
        Write-Log -Level INFO -Message "문제 업데이트됨: [$Id] $($problem.Title)"
        return $problem
    }
    catch {
        Write-Log -Level ERROR -Message "문제 업데이트 실패: $_"
        throw
    }
}
function Get-ProblemSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$Category,
        [Parameter(Mandatory=$false)]
        [string]$Status,
        [Parameter(Mandatory=$false)]
        [string]$AssignedTo,
        [switch]$GenerateReport
    )
    try {
        if (-not $script:ProblemTracker) {
            Initialize-ProblemTracking
        }
        $problems = $script:ProblemTracker
        # 필터 적용
        if ($Category) {
            $problems = $problems | Where-Object { $_.Category -eq $Category }
        }
        if ($Status) {
            $problems = $problems | Where-Object { $_.Status -eq $Status }
        }
        if ($AssignedTo) {
            $problems = $problems | Where-Object { $_.AssignedTo -eq $AssignedTo }
        }
        # 보고서 생성
        if ($GenerateReport) {
            $reportPath = "D:\Dev\DCEC\Dev_Env\ClI\docs\problem_tracking_report.md"
            $report = @"
# 문제 추적 보고서
생성 시각: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
## 상태 요약
$(
    $problems | Group-Object Status | ForEach-Object {
        "- $($_.Name): $($_.Count)건"
    }
)
## 카테고리별 분포
$(
    $problems | Group-Object Category | ForEach-Object {
        "- $($_.Name): $($_.Count)건"
    }
)
## 상세 목록
$(
    $problems | ForEach-Object {
        @"
### [$($_.Id)] $($_.Title)
- 상태: $($_.Status)
- 카테고리: $($_.Category)
- 우선순위: $($_.Priority)
- 담당자: $($_.AssignedTo)
- 설명: $($_.Description)
"@
    }
)
"@
            $report | Out-File -FilePath $reportPath -Encoding UTF8
            Write-Log -Level INFO -Message "문제 추적 보고서 생성됨: $reportPath"
        }
        return $problems
    }
    catch {
        Write-Log -Level ERROR -Message "문제 요약 생성 실패: $_"
        throw
    }
}
function Remove-Problem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]$Id
    )
    try {
        if (-not $script:ProblemTracker) {
            Initialize-ProblemTracking
        }
        $problemToRemove = $script:ProblemTracker | Where-Object { $_.Id -eq $Id }
        if (-not $problemToRemove) {
            throw "문제 ID $Id를 찾을 수 없습니다."
        }
        $script:ProblemTracker = $script:ProblemTracker | Where-Object { $_.Id -ne $Id }
        Save-ProblemData
        Write-Log -Level INFO -Message "문제 삭제됨: [$Id] $($problemToRemove.Title)"
        return $true
    }
    catch {
        Write-Log -Level ERROR -Message "문제 삭제 실패: $_"
        throw
    }
}
function Save-ProblemData {
    try {
        $dataPath = "D:\Dev\DCEC\Dev_Env\ClI\config\problems\problem_list.csv"
        $script:ProblemTracker | Export-Csv -Path $dataPath -NoTypeInformation -Encoding UTF8
        $script:LastSyncTime = Get-Date
        Write-Log -Level INFO -Message "문제 데이터 저장됨: $dataPath"
    }
    catch {
        Write-Log -Level ERROR -Message "문제 데이터 저장 실패: $_"
        throw
    }
}
# 모듈 내보내기
Export-ModuleMember -Function Initialize-ProblemTracking, Add-Problem, Update-Problem,
    Get-ProblemSummary, Remove-Problem
