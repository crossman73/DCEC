# 문제 추적 및 관리 모듈
using module '.\logging.ps1'
function Initialize-ProblemTracking {
    <#
    .SYNOPSIS
    Initialize-ProblemTracking 함수의 기능을 제공합니다.
    
    .DESCRIPTION
    이 함수는 DCEC 프로젝트의 표준 기능을 제공합니다.
    
    .EXAMPLE
    Initialize-ProblemTracking
    
    .NOTES
    이 함수는 DCEC 네임스페이스를 사용합니다.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath,
        [Parameter(Mandatory=$true)]
        [string]$LogDir
    )
    try {
        # 설정 로드
        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
        # 로그 디렉토리 생성
        if (!(Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }
        # 문제 추적 데이터베이스 초기화
        $problemsDb = Join-Path $LogDir "problems.json"
        if (!(Test-Path $problemsDb)) {
            @{
                problems = @()
                metadata = @{
                    createdAt = Get-Date -Format "o"
                    lastUpdated = Get-Date -Format "o"
                    totalProblems = 0
                    resolvedProblems = 0
                }
            } | ConvertTo-Json -Depth 10 | Set-Content $problemsDb -Encoding UTF8
        }
        return $config
    }
    catch {
        Write-Log -Level ERROR -Message "문제 추적 시스템 초기화 실패" -Category "문제추적" -Result $_.Exception.Message
        throw
    }
}
function New-Problem {
    <#
    .SYNOPSIS
    New-Problem 함수의 기능을 제공합니다.
    
    .DESCRIPTION
    이 함수는 DCEC 프로젝트의 표준 기능을 제공합니다.
    
    .EXAMPLE
    New-Problem
    
    .NOTES
    이 함수는 DCEC 네임스페이스를 사용합니다.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [string]$Category,
        [string]$Severity = "Medium",
        [string]$Status = "Open",
        [string[]]$Tags = @(),
        [string]$AssignedTo = ""
    )
    try {
        $problemId = "PROB-" + (Get-Date -Format "yyyyMMdd-HHmmss")
        $problem = @{
            id = $problemId
            title = $Title
            description = $Description
            category = $Category
            severity = $Severity
            status = $Status
            tags = $Tags
            assignedTo = $AssignedTo
            createdAt = Get-Date -Format "o"
            updatedAt = Get-Date -Format "o"
            history = @(
                @{
                    timestamp = Get-Date -Format "o"
                    action = "Created"
                    details = "문제 생성됨"
                }
            )
        }
        # 문제 데이터베이스 업데이트
        $problemsDbPath = Join-Path $PWD "logs/problems.json"
        $problemsDb = Get-Content $problemsDbPath -Raw | ConvertFrom-Json
        $problemsDb.problems += $problem
        $problemsDb.metadata.totalProblems++
        $problemsDb.metadata.lastUpdated = Get-Date -Format "o"
        $problemsDb | ConvertTo-Json -Depth 10 | Set-Content $problemsDbPath -Encoding UTF8
        Write-Log -Level INFO -Message "새로운 문제 등록: $Title" -Category "문제추적" -ProblemId $problemId
        return $problemId
    }
    catch {
        Write-Log -Level ERROR -Message "문제 등록 실패: $Title" -Category "문제추적" -Result $_.Exception.Message
        throw
    }
}
function Update-ProblemStatus {
    <#
    .SYNOPSIS
    Update-ProblemStatus 함수의 기능을 제공합니다.
    
    .DESCRIPTION
    이 함수는 DCEC 프로젝트의 표준 기능을 제공합니다.
    
    .EXAMPLE
    Update-ProblemStatus
    
    .NOTES
    이 함수는 DCEC 네임스페이스를 사용합니다.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$ProblemId,
        [Parameter(Mandatory=$true)]
        [string]$Status,
        [string]$Resolution = "",
        [string]$Comment = ""
    )
    try {
        $problemsDbPath = Join-Path $PWD "logs/problems.json"
        $problemsDb = Get-Content $problemsDbPath -Raw | ConvertFrom-Json
        $problem = $problemsDb.problems | Where-Object { $_.id -eq $ProblemId }
        if (!$problem) {
            throw "문제 ID를 찾을 수 없습니다: $ProblemId"
        }
        $oldStatus = $problem.status
        $problem.status = $Status
        $problem.updatedAt = Get-Date -Format "o"
        $historyEntry = @{
            timestamp = Get-Date -Format "o"
            action = "StatusChanged"
            details = "상태 변경: $oldStatus -> $Status"
            resolution = $Resolution
            comment = $Comment
        }
        $problem.history += $historyEntry
        if ($Status -eq "Resolved") {
            $problemsDb.metadata.resolvedProblems++
        }
        $problemsDb.metadata.lastUpdated = Get-Date -Format "o"
        $problemsDb | ConvertTo-Json -Depth 10 | Set-Content $problemsDbPath -Encoding UTF8
        Write-Log -Level INFO -Message "문제 상태 업데이트: $ProblemId -> $Status" -Category "문제추적" -ProblemId $ProblemId
    }
    catch {
        Write-Log -Level ERROR -Message "문제 상태 업데이트 실패: $ProblemId" -Category "문제추적" -Result $_.Exception.Message
        throw
    }
}
function Get-ProblemReport {
    <#
    .SYNOPSIS
    Get-ProblemReport 함수의 기능을 제공합니다.
    
    .DESCRIPTION
    이 함수는 DCEC 프로젝트의 표준 기능을 제공합니다.
    
    .EXAMPLE
    Get-ProblemReport
    
    .NOTES
    이 함수는 DCEC 네임스페이스를 사용합니다.
    #>
    param (
        [string]$Category,
        [string]$Status,
        [string]$Severity,
        [switch]$Detailed
    )
    try {
        $problemsDbPath = Join-Path $PWD "logs/problems.json"
        $problemsDb = Get-Content $problemsDbPath -Raw | ConvertFrom-Json
        $problems = $problemsDb.problems
        if ($Category) {
            $problems = $problems | Where-Object { $_.category -eq $Category }
        }
        if ($Status) {
            $problems = $problems | Where-Object { $_.status -eq $Status }
        }
        if ($Severity) {
            $problems = $problems | Where-Object { $_.severity -eq $Severity }
        }
        if ($Detailed) {
            return $problems | Select-Object id, title, description, category, severity, status, assignedTo, createdAt, updatedAt, history
        }
        else {
            return $problems | Select-Object id, title, category, severity, status
        }
    }
    catch {
        Write-Log -Level ERROR -Message "문제 보고서 생성 실패" -Category "문제추적" -Result $_.Exception.Message
        throw
    }
}
Export-ModuleMember -Function Initialize-ProblemTracking, New-Problem, Update-ProblemStatus, Get-ProblemReport

