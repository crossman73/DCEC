# PowerShell 문제 추적 및 해결 도구
param (
    [Parameter(Mandatory=$true)]
    [ValidateSet('list', 'add', 'update', 'report')]
    [string]$Command,
    [Parameter()]
    [string]$Id,
    [Parameter()]
    [string]$Title,
    [Parameter()]
    [string]$Description,
    [Parameter()]
    [ValidateSet('Environment', 'CLI', 'Code', 'Security', 'Performance', 'Documentation')]
    [string]$Category,
    [Parameter()]
    [ValidateSet(1, 2, 3)]
    [int]$Priority,
    [Parameter()]
    [string]$AssignedTo,
    [Parameter()]
    [ValidateSet('New', 'InProgress', 'Testing', 'Resolved', 'Closed')]
    [string]$Status
)
$ErrorActionPreference = 'Stop'
$ProblemListPath = Join-Path $PSScriptRoot "..\config\problem_list.csv"
function Get-Problems {
    $problems = Import-Csv -Path $ProblemListPath
    return $problems
}
function Add-Problem {
    param(
        [string]$Title,
        [string]$Description,
        [string]$Category,
        [int]$Priority,
        [string]$AssignedTo
    )
    $problems = Get-Problems
    $newId = ($problems | Measure-Object -Property Id -Maximum).Maximum + 1
    $newProblem = [PSCustomObject]@{
        Id = $newId
        Title = $Title
        Description = $Description
        Category = $Category
        Priority = $Priority
        AssignedTo = $AssignedTo
        Status = 'New'
    }
    $problems += $newProblem
    $problems | Export-Csv -Path $ProblemListPath -NoTypeInformation
    Write-Host "새로운 문제가 등록되었습니다. (ID: $newId)"
}
function Update-ProblemStatus {
    param(
        [string]$Id,
        [string]$Status
    )
    $problems = Get-Problems
    $problem = $problems | Where-Object { $_.Id -eq $Id }
    if ($problem) {
        $problem.Status = $Status
        $problems | Export-Csv -Path $ProblemListPath -NoTypeInformation
        Write-Host "문제 상태가 업데이트되었습니다. (ID: $Id, 상태: $Status)"
    }
    else {
        Write-Error "문제를 찾을 수 없습니다. (ID: $Id)"
    }
}
function Get-ProblemReport {
    $problems = Get-Problems
    $summary = @{
        Total = $problems.Count
        ByStatus = $problems | Group-Object -Property Status | ForEach-Object {
            @{$_.Name = $_.Count}
        }
        ByCategory = $problems | Group-Object -Property Category | ForEach-Object {
            @{$_.Name = $_.Count}
        }
        ByPriority = $problems | Group-Object -Property Priority | ForEach-Object {
            @{$_.Name = $_.Count}
        }
    }
    Write-Host "`n문제 추적 보고서"
    Write-Host "==================="
    Write-Host "총 문제 수: $($summary.Total)"
    Write-Host "`n상태별 분포:"
    $summary.ByStatus | ForEach-Object { $_.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): $($_.Value)" } }
    Write-Host "`n카테고리별 분포:"
    $summary.ByCategory | ForEach-Object { $_.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): $($_.Value)" } }
    Write-Host "`n우선순위별 분포:"
    $summary.ByPriority | ForEach-Object { $_.GetEnumerator() | ForEach-Object { Write-Host "P$($_.Key): $($_.Value)" } }
}
# 명령어 실행
switch ($Command) {
    'list' {
        Get-Problems | Format-Table
    }
    'add' {
        Add-Problem -Title $Title -Description $Description -Category $Category -Priority $Priority -AssignedTo $AssignedTo
    }
    'update' {
        Update-ProblemStatus -Id $Id -Status $Status
    }
    'report' {
        Get-ProblemReport
    }
}
