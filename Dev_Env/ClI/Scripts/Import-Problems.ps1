# Import-Problems.ps1
# 문제 데이터 가져오기 및 등록 스크립트
$ErrorActionPreference = 'Stop'
# 문제 추적 함수 로드
. "$PSScriptRoot\modules\core\problem_tracking.ps1"
try {
    # 문제 추적 시스템 초기화
    Initialize-ProblemTracking
    Write-Host "문제 데이터 로드 중..." -ForegroundColor Yellow
    # CSV 파일에서 문제 목록 읽기
    $problems = Import-Csv -Path "D:\Dev\DCEC\Dev_Env\ClI\config\problems\problem_list.csv"
    # 각 문제 등록
    foreach ($problem in $problems) {
        try {
            $params = @{
                Title = $problem.Title
                Description = $problem.Description
                Category = $problem.Category
                Priority = [int]$problem.Priority
                AssignedTo = $problem.AssignedTo
                Status = $problem.Status
            }
            Add-Problem @params
            Write-Host "문제 등록 완료: [$($problem.Id)] $($problem.Title)" -ForegroundColor Green
        }
        catch {
            Write-Host "문제 등록 실패: [$($problem.Id)] $($problem.Title) - $_" -ForegroundColor Red
        }
    }
    # 요약 보고서 생성
    Write-Host "`n문제 추적 요약 생성 중..." -ForegroundColor Yellow
    $summary = Get-ProblemSummary -GenerateReport
    # 상태별 통계
    Write-Host "`n=== 문제 상태 통계 ===" -ForegroundColor Cyan
    $summary | Group-Object Status | ForEach-Object {
        Write-Host "$($_.Name): $($_.Count)건" -ForegroundColor White
    }
    # 카테고리별 통계
    Write-Host "`n=== 카테고리별 통계 ===" -ForegroundColor Cyan
    $summary | Group-Object Category | ForEach-Object {
        Write-Host "$($_.Name): $($_.Count)건" -ForegroundColor White
    }
    Write-Host "`n문제 추적 시스템 초기화가 완료되었습니다." -ForegroundColor Green
    Write-Host "자세한 보고서는 'docs/problem_tracking_report.md'에서 확인할 수 있습니다." -ForegroundColor Yellow
}
catch {
    Write-Host "오류 발생: $_" -ForegroundColor Red
    exit 1
}
