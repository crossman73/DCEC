# Python 환경 검증 및 진단 스크립트
# DCEC Python Environment Validator
# Version: 1.0

[CmdletBinding()]
param(
    [switch]$Detailed,
    [switch]$FixIssues,
    [switch]$GenerateReport,
    [string]$ReportPath = ""
)

# 설정 모듈 로드
Import-Module "$PSScriptRoot\..\config\PythonConfig.psm1" -Force

# 로깅 설정
$script:LogFile = Join-Path $PSScriptRoot "..\logs\python_validation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:SessionId = [guid]::NewGuid().ToString().Substring(0,8)

function Write-DCECValidationLog {
    param(
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO",
        [string]$Message,
        [string]$Component = "PythonValidator"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$script:SessionId] [$Level] [$Component] $Message"
    
    # 콘솔 출력
    switch ($Level) {
        "INFO" { Write-Host $logLine -ForegroundColor Cyan }
        "WARNING" { Write-Host $logLine -ForegroundColor Yellow }
        "ERROR" { Write-Host $logLine -ForegroundColor Red }
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
        "DEBUG" { if ($Detailed) { Write-Host $logLine -ForegroundColor Gray } }
    }
    
    # 파일 로깅
    try {
        $logDir = Split-Path $script:LogFile -Parent
        if (!(Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $script:LogFile -Value $logLine -Encoding UTF8
    }
    catch {
        Write-Warning "로그 파일 쓰기 실패: $($_.Exception.Message)"
    }
}

function Test-DCECPythonCommands {
    <#
    .SYNOPSIS
    Python 명령어 실행 테스트
    #>
    
    $results = @()
    
    foreach ($validation in $Global:ValidationConfig.ValidationCommands) {
        $testResult = @{
            Command = $validation.Command
            Args = $validation.Args
            Expected = $validation.ExpectedPattern
            Success = $false
            Output = ""
            Error = ""
        }
        
        try {
            Write-DCECValidationLog -Level DEBUG -Message "명령어 테스트: $($validation.Command) $($validation.Args -join ' ')"
            
            # 명령어 실행
            $process = Start-Process -FilePath $validation.Command -ArgumentList $validation.Args -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\dcec_stdout.txt" -RedirectStandardError "$env:TEMP\dcec_stderr.txt"
            
            $stdout = if (Test-Path "$env:TEMP\dcec_stdout.txt") { Get-Content "$env:TEMP\dcec_stdout.txt" -Raw } else { "" }
            $stderr = if (Test-Path "$env:TEMP\dcec_stderr.txt") { Get-Content "$env:TEMP\dcec_stderr.txt" -Raw } else { "" }
            
            $testResult.Output = $stdout
            $testResult.Error = $stderr
            
            # 패턴 매칭 검증
            if ($process.ExitCode -eq 0 -and $stdout -match $validation.ExpectedPattern) {
                $testResult.Success = $true
                Write-DCECValidationLog -Level SUCCESS -Message "명령어 검증 성공: $($validation.Command)"
                Write-DCECValidationLog -Level DEBUG -Message "출력: $stdout"
            }
            else {
                Write-DCECValidationLog -Level ERROR -Message "명령어 검증 실패: $($validation.Command)"
                Write-DCECValidationLog -Level ERROR -Message "종료코드: $($process.ExitCode), 출력: $stdout, 에러: $stderr"
            }
            
            # 임시 파일 정리
            @("$env:TEMP\dcec_stdout.txt", "$env:TEMP\dcec_stderr.txt") | ForEach-Object {
                if (Test-Path $_) { Remove-Item $_ -Force -ErrorAction SilentlyContinue }
            }
        }
        catch {
            $testResult.Error = $_.Exception.Message
            Write-DCECValidationLog -Level ERROR -Message "명령어 실행 실패: $($validation.Command) - $($_.Exception.Message)"
        }
        
        $results += $testResult
    }
    
    return $results
}

function Test-DCECPythonModules {
    <#
    .SYNOPSIS
    Python 모듈 import 테스트
    #>
    
    $results = @()
    
    foreach ($module in $Global:ValidationConfig.RequiredModules) {
        $testResult = @{
            Module = $module
            Success = $false
            Version = ""
            Error = ""
            ImportTime = 0
        }
        
        try {
            Write-DCECValidationLog -Level DEBUG -Message "모듈 테스트: $module"
            
            # Python 명령어로 모듈 import 테스트
            $importScript = @"
import time
import sys
start_time = time.time()
try:
    import $module
    import_time = time.time() - start_time
    print(f"SUCCESS:{import_time:.3f}")
    if hasattr($module, '__version__'):
        print(f"VERSION:{$module.__version__}")
    elif hasattr($module, 'version'):
        print(f"VERSION:{$module.version}")
    else:
        print("VERSION:unknown")
except Exception as e:
    print(f"ERROR:{str(e)}")
"@
            
            $tempScript = Join-Path $env:TEMP "dcec_module_test.py"
            $importScript | Out-File -FilePath $tempScript -Encoding UTF8
            
            # Python 스크립트 실행
            $result = & python $tempScript 2>&1
            
            if ($result -match "SUCCESS:(\d+\.\d+)") {
                $testResult.Success = $true
                $testResult.ImportTime = [float]$matches[1]
                Write-DCECValidationLog -Level SUCCESS -Message "모듈 import 성공: $module (${matches[1]}초)"
            }
            
            if ($result -match "VERSION:(.+)") {
                $testResult.Version = $matches[1].Trim()
                Write-DCECValidationLog -Level DEBUG -Message "모듈 버전: $module = $($testResult.Version)"
            }
            
            if ($result -match "ERROR:(.+)") {
                $testResult.Error = $matches[1].Trim()
                Write-DCECValidationLog -Level ERROR -Message "모듈 import 실패: $module - $($testResult.Error)"
            }
            
            # 임시 파일 정리
            if (Test-Path $tempScript) {
                Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
            }
        }
        catch {
            $testResult.Error = $_.Exception.Message
            Write-DCECValidationLog -Level ERROR -Message "모듈 테스트 실패: $module - $($_.Exception.Message)"
        }
        
        $results += $testResult
    }
    
    return $results
}

function Test-DCECPythonPerformance {
    <#
    .SYNOPSIS
    Python 성능 테스트
    #>
    
    $results = @{
        StartupTime = 0
        ImportTime = 0
        Success = $false
        Error = ""
    }
    
    try {
        Write-DCECValidationLog -Level DEBUG -Message "Python 성능 테스트 시작"
        
        # 시작 시간 측정
        $startupScript = @"
import time
start_time = time.time()
# 기본 모듈 import 테스트
import sys, os, json
end_time = time.time()
print(f"STARTUP:{end_time - start_time:.3f}")
"@
        
        $tempScript = Join-Path $env:TEMP "dcec_performance_test.py"
        $startupScript | Out-File -FilePath $tempScript -Encoding UTF8
        
        $result = & python $tempScript 2>&1
        
        if ($result -match "STARTUP:(\d+\.\d+)") {
            $results.StartupTime = [float]$matches[1]
            Write-DCECValidationLog -Level DEBUG -Message "Python 시작 시간: $($results.StartupTime)초"
            
            # 성능 기준 확인
            if ($results.StartupTime -le $Global:ValidationConfig.PerformanceTests.StartupTime) {
                $results.Success = $true
                Write-DCECValidationLog -Level SUCCESS -Message "성능 테스트 통과: 시작 시간 $($results.StartupTime)초"
            }
            else {
                Write-DCECValidationLog -Level WARNING -Message "성능 테스트 주의: 시작 시간이 느림 ($($results.StartupTime)초)"
            }
        }
        
        # 임시 파일 정리
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        }
    }
    catch {
        $results.Error = $_.Exception.Message
        Write-DCECValidationLog -Level ERROR -Message "성능 테스트 실패: $($_.Exception.Message)"
    }
    
    return $results
}

function Test-DCECPythonEnvironment {
    <#
    .SYNOPSIS
    Python 환경 변수 및 경로 테스트
    #>
    
    $results = @{
        EnvironmentVariables = @{}
        PathEntries = @()
        PythonPaths = @()
        Success = $false
    }
    
    try {
        Write-DCECValidationLog -Level DEBUG -Message "Python 환경 테스트 시작"
        
        # 환경 변수 확인
        foreach ($varName in $Global:EnvironmentConfig.Variables.Keys) {
            $value = [Environment]::GetEnvironmentVariable($varName)
            $results.EnvironmentVariables[$varName] = $value
            Write-DCECValidationLog -Level DEBUG -Message "환경 변수: $varName = $value"
        }
        
        # PATH 확인
        $pathEntries = $env:PATH -split ';' | Where-Object { $_ -like "*python*" -or $_ -like "*Python*" }
        $results.PathEntries = $pathEntries
        Write-DCECValidationLog -Level DEBUG -Message "Python 관련 PATH 항목: $($pathEntries.Count)개"
        
        # Python 실행파일 경로 확인
        $pythonCommands = @('python', 'py', 'pip')
        foreach ($cmd in $pythonCommands) {
            try {
                $path = Get-Command $cmd -ErrorAction SilentlyContinue
                if ($path) {
                    $results.PythonPaths += @{
                        Command = $cmd
                        Path = $path.Source
                        Version = $path.Version
                    }
                    Write-DCECValidationLog -Level DEBUG -Message "$cmd 경로: $($path.Source)"
                }
            }
            catch {
                Write-DCECValidationLog -Level DEBUG -Message "$cmd 명령어를 찾을 수 없음"
            }
        }
        
        $results.Success = $results.PythonPaths.Count -gt 0
        
        if ($results.Success) {
            Write-DCECValidationLog -Level SUCCESS -Message "Python 환경 확인 완료"
        }
        else {
            Write-DCECValidationLog -Level ERROR -Message "Python 환경 설정 문제 발견"
        }
    }
    catch {
        Write-DCECValidationLog -Level ERROR -Message "환경 테스트 실패: $($_.Exception.Message)"
    }
    
    return $results
}

function Repair-DCECPythonEnvironment {
    <#
    .SYNOPSIS
    Python 환경 문제 자동 수정
    #>
    param(
        [object]$ValidationResults
    )
    
    $repairResults = @{
        ActionsPerformed = @()
        Success = $false
        Errors = @()
    }
    
    try {
        Write-DCECValidationLog -Level INFO -Message "Python 환경 자동 수정 시작"
        
        # 명령어 문제 수정
        $commandIssues = $ValidationResults.Commands | Where-Object { !$_.Success }
        foreach ($issue in $commandIssues) {
            Write-DCECValidationLog -Level INFO -Message "명령어 문제 수정 시도: $($issue.Command)"
            
            # 일반적인 해결책 적용
            switch ($issue.Command) {
                "python" {
                    # Python 경로를 PATH에 추가
                    $pythonPath = "$env:LOCALAPPDATA\Programs\Python\Python312"
                    if (Test-Path $pythonPath) {
                        $env:PATH = "$pythonPath;$env:PATH"
                        $repairResults.ActionsPerformed += "Python 경로를 PATH에 추가: $pythonPath"
                        Write-DCECValidationLog -Level INFO -Message "Python 경로 추가: $pythonPath"
                    }
                }
                "pip" {
                    # pip 경로를 PATH에 추가
                    $pipPath = "$env:LOCALAPPDATA\Programs\Python\Python312\Scripts"
                    if (Test-Path $pipPath) {
                        $env:PATH = "$pipPath;$env:PATH"
                        $repairResults.ActionsPerformed += "pip 경로를 PATH에 추가: $pipPath"
                        Write-DCECValidationLog -Level INFO -Message "pip 경로 추가: $pipPath"
                    }
                }
            }
        }
        
        # 모듈 문제 수정
        $moduleIssues = $ValidationResults.Modules | Where-Object { !$_.Success }
        foreach ($issue in $moduleIssues) {
            try {
                Write-DCECValidationLog -Level INFO -Message "모듈 설치 시도: $($issue.Module)"
                
                # pip로 모듈 설치 시도
                $installResult = & pip install $issue.Module 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    $repairResults.ActionsPerformed += "모듈 설치 완료: $($issue.Module)"
                    Write-DCECValidationLog -Level SUCCESS -Message "모듈 설치 성공: $($issue.Module)"
                }
                else {
                    $repairResults.Errors += "모듈 설치 실패: $($issue.Module) - $installResult"
                    Write-DCECValidationLog -Level ERROR -Message "모듈 설치 실패: $($issue.Module)"
                }
            }
            catch {
                $repairResults.Errors += "모듈 설치 중 오류: $($issue.Module) - $($_.Exception.Message)"
                Write-DCECValidationLog -Level ERROR -Message "모듈 설치 오류: $($issue.Module)"
            }
        }
        
        $repairResults.Success = $repairResults.Errors.Count -eq 0
        
        if ($repairResults.Success) {
            Write-DCECValidationLog -Level SUCCESS -Message "환경 수정 완료"
        }
        else {
            Write-DCECValidationLog -Level WARNING -Message "일부 문제가 수정되지 않음: $($repairResults.Errors.Count)개"
        }
    }
    catch {
        $repairResults.Errors += $_.Exception.Message
        Write-DCECValidationLog -Level ERROR -Message "환경 수정 실패: $($_.Exception.Message)"
    }
    
    return $repairResults
}

function New-DCECPythonValidationReport {
    <#
    .SYNOPSIS
    Python 검증 결과 보고서 생성
    #>
    param(
        [object]$ValidationResults,
        [string]$OutputPath = ""
    )
    
    try {
        if (!$OutputPath) {
            $OutputPath = Join-Path $PSScriptRoot "..\docs\python_validation_report.json"
        }
        
        $report = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            SessionId = $script:SessionId
            Summary = @{
                CommandTests = @{
                    Total = $ValidationResults.Commands.Count
                    Passed = ($ValidationResults.Commands | Where-Object { $_.Success }).Count
                    Failed = ($ValidationResults.Commands | Where-Object { !$_.Success }).Count
                }
                ModuleTests = @{
                    Total = $ValidationResults.Modules.Count
                    Passed = ($ValidationResults.Modules | Where-Object { $_.Success }).Count
                    Failed = ($ValidationResults.Modules | Where-Object { !$_.Success }).Count
                }
                PerformanceTests = @{
                    StartupTime = $ValidationResults.Performance.StartupTime
                    Passed = $ValidationResults.Performance.Success
                }
                Environment = @{
                    PathEntries = $ValidationResults.Environment.PathEntries.Count
                    PythonPaths = $ValidationResults.Environment.PythonPaths.Count
                    Success = $ValidationResults.Environment.Success
                }
            }
            Details = $ValidationResults
            LogFile = $script:LogFile
        }
        
        # 보고서 저장
        $reportDir = Split-Path $OutputPath -Parent
        if (!(Test-Path $reportDir)) {
            New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
        }
        
        $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
        Write-DCECValidationLog -Level SUCCESS -Message "검증 보고서 저장: $OutputPath"
        
        # 요약 출력
        Write-Host "`n=== Python 환경 검증 요약 ===" -ForegroundColor Cyan
        Write-Host "명령어 테스트: $($report.Summary.CommandTests.Passed)/$($report.Summary.CommandTests.Total) 통과" -ForegroundColor $(if ($report.Summary.CommandTests.Failed -eq 0) { "Green" } else { "Yellow" })
        Write-Host "모듈 테스트: $($report.Summary.ModuleTests.Passed)/$($report.Summary.ModuleTests.Total) 통과" -ForegroundColor $(if ($report.Summary.ModuleTests.Failed -eq 0) { "Green" } else { "Yellow" })
        Write-Host "성능 테스트: $(if ($report.Summary.PerformanceTests.Passed) { "통과" } else { "실패" }) (시작시간: $($report.Summary.PerformanceTests.StartupTime)초)" -ForegroundColor $(if ($report.Summary.PerformanceTests.Passed) { "Green" } else { "Yellow" })
        Write-Host "환경 테스트: $(if ($report.Summary.Environment.Success) { "통과" } else { "실패" })" -ForegroundColor $(if ($report.Summary.Environment.Success) { "Green" } else { "Red" })
        Write-Host "보고서 위치: $OutputPath" -ForegroundColor Gray
        Write-Host "로그 파일: $script:LogFile" -ForegroundColor Gray
        
        return $report
    }
    catch {
        Write-DCECValidationLog -Level ERROR -Message "보고서 생성 실패: $($_.Exception.Message)"
        throw
    }
}

# 메인 실행 로직
try {
    Write-DCECValidationLog -Level INFO -Message "=== DCEC Python 환경 검증 시작 ==="
    Write-DCECValidationLog -Level INFO -Message "세션 ID: $script:SessionId"
    
    # 검증 결과 수집
    $validationResults = @{
        Commands = Test-DCECPythonCommands
        Modules = Test-DCECPythonModules
        Performance = Test-DCECPythonPerformance
        Environment = Test-DCECPythonEnvironment
    }
    
    # 문제 자동 수정 (요청된 경우)
    if ($FixIssues) {
        Write-DCECValidationLog -Level INFO -Message "문제 자동 수정 시작"
        $repairResults = Repair-DCECPythonEnvironment -ValidationResults $validationResults
        $validationResults.RepairResults = $repairResults
        
        # 수정 후 재검증
        Write-DCECValidationLog -Level INFO -Message "수정 후 재검증 시작"
        $validationResults.PostRepairCommands = Test-DCECPythonCommands
        $validationResults.PostRepairModules = Test-DCECPythonModules
    }
    
    # 보고서 생성
    if ($GenerateReport -or $ReportPath) {
        $reportPath = if ($ReportPath) { $ReportPath } else { "" }
        $report = New-DCECPythonValidationReport -ValidationResults $validationResults -OutputPath $reportPath
        $validationResults.Report = $report
    }
    
    Write-DCECValidationLog -Level SUCCESS -Message "=== DCEC Python 환경 검증 완료 ==="
    
    # 전체 성공 여부 판단
    $overallSuccess = (
        ($validationResults.Commands | Where-Object { !$_.Success }).Count -eq 0 -and
        ($validationResults.Modules | Where-Object { !$_.Success }).Count -eq 0 -and
        $validationResults.Performance.Success -and
        $validationResults.Environment.Success
    )
    
    return @{
        Success = $overallSuccess
        Results = $validationResults
        LogFile = $script:LogFile
    }
}
catch {
    Write-DCECValidationLog -Level ERROR -Message "Python 환경 검증 실패: $($_.Exception.Message)"
    Write-DCECValidationLog -Level ERROR -Message "스택 추적: $($_.ScriptStackTrace)"
    
    return @{
        Success = $false
        Error = $_.Exception.Message
        LogFile = $script:LogFile
    }
}
