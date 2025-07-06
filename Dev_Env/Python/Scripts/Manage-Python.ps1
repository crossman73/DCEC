# DCEC Python 환경 관리 스크립트
# Main Python Management Script
# Version: 1.0

[CmdletBinding()]
param(
    [ValidateSet("Install", "Validate", "Repair", "Status", "Update", "Report")]
    [string]$Action = "Status",
    [string]$PythonVersion = "3.12.4",
    [switch]$Force,
    [switch]$Detailed,
    [switch]$AutoFix
)

# 스크립트 경로 설정
$ScriptRoot = $PSScriptRoot
$InstallScript = Join-Path $ScriptRoot "Install-Python.ps1"
$ValidateScript = Join-Path $ScriptRoot "Test-PythonEnvironment.ps1"

function Write-DCECPythonManagerLog {
    param(
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    switch ($Level) {
        "INFO" { Write-Host "[$timestamp] [INFO] $Message" -ForegroundColor Cyan }
        "WARNING" { Write-Host "[$timestamp] [WARN] $Message" -ForegroundColor Yellow }
        "ERROR" { Write-Host "[$timestamp] [ERROR] $Message" -ForegroundColor Red }
        "SUCCESS" { Write-Host "[$timestamp] [OK] $Message" -ForegroundColor Green }
    }
}

function Show-DCECPythonStatus {
    <#
    .SYNOPSIS
    Python 환경 현재 상태 표시
    #>
    try {
        Write-DCECPythonManagerLog -Level INFO -Message "Python 환경 상태 확인 중..."
        
        # Python 버전 확인
        try {
            $pythonVersion = & python --version 2>&1
            if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
                Write-DCECPythonManagerLog -Level SUCCESS -Message "Python 설치됨: $pythonVersion"
            }
            else {
                Write-DCECPythonManagerLog -Level ERROR -Message "Python 버전 확인 실패"
            }
        }
        catch {
            Write-DCECPythonManagerLog -Level ERROR -Message "Python이 설치되지 않았거나 PATH에 없습니다"
        }
        
        # pip 상태 확인
        try {
            $pipVersion = & pip --version 2>&1
            if ($pipVersion -match "pip (\d+\.\d+\.\d+)") {
                Write-DCECPythonManagerLog -Level SUCCESS -Message "pip 설치됨: $pipVersion"
            }
            else {
                Write-DCECPythonManagerLog -Level ERROR -Message "pip 버전 확인 실패"
            }
        }
        catch {
            Write-DCECPythonManagerLog -Level ERROR -Message "pip이 설치되지 않았거나 PATH에 없습니다"
        }
        
        # Python Launcher 확인
        try {
            $pyVersion = & py --version 2>&1
            if ($pyVersion -match "Python (\d+\.\d+\.\d+)") {
                Write-DCECPythonManagerLog -Level SUCCESS -Message "Python Launcher 사용 가능: $pyVersion"
            }
        }
        catch {
            Write-DCECPythonManagerLog -Level WARNING -Message "Python Launcher가 설치되지 않음"
        }
        
        # 설치된 패키지 수 확인
        try {
            $packages = & pip list --format=json 2>&1 | ConvertFrom-Json
            Write-DCECPythonManagerLog -Level INFO -Message "설치된 패키지: $($packages.Count)개"
        }
        catch {
            Write-DCECPythonManagerLog -Level WARNING -Message "패키지 목록 조회 실패"
        }
        
        return $true
    }
    catch {
        Write-DCECPythonManagerLog -Level ERROR -Message "상태 확인 실패: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-DCECPythonInstall {
    <#
    .SYNOPSIS
    Python 설치 실행
    #>
    try {
        Write-DCECPythonManagerLog -Level INFO -Message "Python $PythonVersion 설치 시작..."
        
        if (!(Test-Path $InstallScript)) {
            throw "설치 스크립트를 찾을 수 없습니다: $InstallScript"
        }
        
        $params = @{
            PythonVersion = $PythonVersion
            Force = $Force
            IncludePip = $true
            AddToPath = $true
        }
        
        $result = & $InstallScript @params
        
        if ($result.Success) {
            Write-DCECPythonManagerLog -Level SUCCESS -Message "Python 설치 완료"
            Write-DCECPythonManagerLog -Level INFO -Message "Python 버전: $($result.Python.Version)"
            Write-DCECPythonManagerLog -Level INFO -Message "pip 버전: $($result.Pip.Version)"
            return $true
        }
        else {
            Write-DCECPythonManagerLog -Level ERROR -Message "Python 설치 실패: $($result.Error)"
            return $false
        }
    }
    catch {
        Write-DCECPythonManagerLog -Level ERROR -Message "설치 실행 실패: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-DCECPythonValidation {
    <#
    .SYNOPSIS
    Python 환경 검증 실행
    #>
    try {
        Write-DCECPythonManagerLog -Level INFO -Message "Python 환경 검증 시작..."
        
        if (!(Test-Path $ValidateScript)) {
            throw "검증 스크립트를 찾을 수 없습니다: $ValidateScript"
        }
        
        $params = @{
            Detailed = $Detailed
            FixIssues = $AutoFix
            GenerateReport = $true
        }
        
        $result = & $ValidateScript @params
        
        if ($result.Success) {
            Write-DCECPythonManagerLog -Level SUCCESS -Message "Python 환경 검증 완료"
        }
        else {
            Write-DCECPythonManagerLog -Level WARNING -Message "일부 검증 항목에서 문제 발견"
        }
        
        Write-DCECPythonManagerLog -Level INFO -Message "상세 로그: $($result.LogFile)"
        return $result.Success
    }
    catch {
        Write-DCECPythonManagerLog -Level ERROR -Message "검증 실행 실패: $($_.Exception.Message)"
        return $false
    }
}

function Update-DCECPythonPackages {
    <#
    .SYNOPSIS
    Python 패키지 업데이트
    #>
    try {
        Write-DCECPythonManagerLog -Level INFO -Message "Python 패키지 업데이트 시작..."
        
        # pip 업그레이드
        Write-DCECPythonManagerLog -Level INFO -Message "pip 업그레이드 중..."
        $pipResult = & python -m pip install --upgrade pip 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-DCECPythonManagerLog -Level SUCCESS -Message "pip 업그레이드 완료"
        }
        else {
            Write-DCECPythonManagerLog -Level WARNING -Message "pip 업그레이드 실패: $pipResult"
        }
        
        # 주요 패키지 업데이트
        $packages = @("setuptools", "wheel", "requests", "virtualenv")
        foreach ($package in $packages) {
            try {
                Write-DCECPythonManagerLog -Level INFO -Message "$package 업데이트 중..."
                $result = & pip install --upgrade $package 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-DCECPythonManagerLog -Level SUCCESS -Message "$package 업데이트 완료"
                }
                else {
                    Write-DCECPythonManagerLog -Level WARNING -Message "$package 업데이트 실패"
                }
            }
            catch {
                Write-DCECPythonManagerLog -Level WARNING -Message "$package 업데이트 중 오류: $($_.Exception.Message)"
            }
        }
        
        return $true
    }
    catch {
        Write-DCECPythonManagerLog -Level ERROR -Message "패키지 업데이트 실패: $($_.Exception.Message)"
        return $false
    }
}

function Show-DCECPythonReport {
    <#
    .SYNOPSIS
    Python 환경 종합 보고서 표시
    #>
    try {
        Write-DCECPythonManagerLog -Level INFO -Message "Python 환경 종합 보고서 생성 중..."
        
        # 보고서 파일 경로
        $docsPath = Join-Path $ScriptRoot "..\docs"
        $reportFiles = @(
            "python_environment_report.json",
            "python_validation_report.json"
        )
        
        Write-Host "`n=== DCEC Python 환경 보고서 ===" -ForegroundColor Cyan
        Write-Host "생성 시간: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
        
        foreach ($reportFile in $reportFiles) {
            $reportPath = Join-Path $docsPath $reportFile
            if (Test-Path $reportPath) {
                Write-Host "`n📄 $reportFile" -ForegroundColor Yellow
                try {
                    $report = Get-Content $reportPath -Raw | ConvertFrom-Json
                    Write-Host "   타임스탬프: $($report.Timestamp)" -ForegroundColor Gray
                    Write-Host "   파일 위치: $reportPath" -ForegroundColor Gray
                }
                catch {
                    Write-Host "   파일 읽기 실패: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            else {
                Write-Host "`n❌ $reportFile (없음)" -ForegroundColor Red
            }
        }
        
        # 로그 파일 정보
        $logsPath = Join-Path $ScriptRoot "..\logs"
        if (Test-Path $logsPath) {
            $logFiles = Get-ChildItem $logsPath -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
            Write-Host "`n📝 최근 로그 파일:" -ForegroundColor Yellow
            foreach ($logFile in $logFiles) {
                Write-Host "   $($logFile.Name) ($($logFile.LastWriteTime.ToString('MM-dd HH:mm')))" -ForegroundColor Gray
            }
        }
        
        return $true
    }
    catch {
        Write-DCECPythonManagerLog -Level ERROR -Message "보고서 생성 실패: $($_.Exception.Message)"
        return $false
    }
}

# 메인 실행 로직
try {
    Write-Host "=== DCEC Python 환경 관리자 ===" -ForegroundColor Cyan
    Write-Host "작업: $Action" -ForegroundColor Yellow
    
    $success = $false
    
    switch ($Action) {
        "Install" {
            $success = Invoke-DCECPythonInstall
        }
        "Validate" {
            $success = Invoke-DCECPythonValidation
        }
        "Repair" {
            Write-DCECPythonManagerLog -Level INFO -Message "복구 모드로 검증 실행..."
            $script:AutoFix = $true
            $success = Invoke-DCECPythonValidation
        }
        "Status" {
            $success = Show-DCECPythonStatus
        }
        "Update" {
            $success = Update-DCECPythonPackages
        }
        "Report" {
            $success = Show-DCECPythonReport
        }
        default {
            Write-DCECPythonManagerLog -Level ERROR -Message "알 수 없는 작업: $Action"
            $success = $false
        }
    }
    
    if ($success) {
        Write-DCECPythonManagerLog -Level SUCCESS -Message "$Action 작업 완료"
        exit 0
    }
    else {
        Write-DCECPythonManagerLog -Level ERROR -Message "$Action 작업 실패"
        exit 1
    }
}
catch {
    Write-DCECPythonManagerLog -Level ERROR -Message "스크립트 실행 실패: $($_.Exception.Message)"
    exit 1
}

<#
.SYNOPSIS
DCEC Python 환경 관리 스크립트

.DESCRIPTION
Python 설치, 검증, 복구, 업데이트 등을 통합 관리하는 스크립트입니다.

.PARAMETER Action
수행할 작업을 지정합니다:
- Install: Python 설치
- Validate: 환경 검증
- Repair: 문제 자동 수정
- Status: 현재 상태 확인
- Update: 패키지 업데이트
- Report: 종합 보고서

.PARAMETER PythonVersion
설치할 Python 버전 (기본값: 3.12.4)

.PARAMETER Force
강제 설치/업데이트

.PARAMETER Detailed
상세 출력 모드

.PARAMETER AutoFix
자동 문제 수정

.EXAMPLE
.\Manage-Python.ps1 -Action Status
현재 Python 환경 상태 확인

.EXAMPLE
.\Manage-Python.ps1 -Action Install -PythonVersion "3.12.4" -Force
Python 3.12.4 강제 설치

.EXAMPLE
.\Manage-Python.ps1 -Action Validate -Detailed -AutoFix
상세 검증 및 자동 수정

.EXAMPLE
.\Manage-Python.ps1 -Action Report
종합 보고서 생성

.NOTES
DCEC Python 환경 관리 도구
버전: 1.0
#>
