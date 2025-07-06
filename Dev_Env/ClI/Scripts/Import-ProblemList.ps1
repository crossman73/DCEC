# Import-ProblemList.ps1
# 문제 목록을 CSV 파일에서 가져와서 등록하는 스크립트
$ErrorActionPreference = 'Stop'
try {
    # 모듈 경로 설정 및 임포트
    $ModulePath = Join-Path $PSScriptRoot "..\Modules"
    if ($env:PSModulePath -notlike "*$ModulePath*") {
        $env:PSModulePath = "$ModulePath;$env:PSModulePath"
    }
    Import-Module DCECCore -Force
    # 문제 추적 시스템 초기화
    Initialize-ProblemTracking
    # CSV 파일 읽기
    $ProblemListPath = Join-Path $PSScriptRoot "..\config\problem_list.csv"
    $Problems = Import-Csv -Path $ProblemListPath
    # 각 문제 등록
    foreach ($Problem in $Problems) {
        try {
            $Params = @{
                Title = $Problem.Title
                Description = $Problem.Description
                Category = $Problem.Category
                Priority = [int]$Problem.Priority
                AssignedTo = $Problem.AssignedTo
            }
            $Result = New-Problem @Params
            Write-Host "문제 등록 완료: [$($Result.id)] $($Result.title)"
        }
        catch {
            Write-Warning "문제 등록 실패 - $($Problem.Title): $_"
        }
    }
    # 등록된 문제 요약 보고서 생성
    $Report = Get-ProblemReport
    $Summary = $Report | Group-Object -Property Category | Select-Object @{
        Name = 'Category'
        Expression = {$_.Name}
    }, @{
        Name = 'Count'
        Expression = {$_.Count}
    }
    Write-Host "`n문제 등록 완료 요약:"
    $Summary | Format-Table -AutoSize
    Write-Host "`n총 등록된 문제: $($Report.Count)"
}
catch {
    Write-Error "문제 목록 가져오기 실패: $_"
    exit 1
}
