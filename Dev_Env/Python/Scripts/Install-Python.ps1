# Python 설치 및 환경 설정 스크립트
# DCEC Python Environment Setup Script
# Version: 1.0
# Date: 2025-07-06

[CmdletBinding()]
param(
    [string]$PythonVersion = "3.12.4",
    [string]$InstallPath = "$env:LOCALAPPDATA\Programs\Python",
    [switch]$Force,
    [switch]$IncludePip,
    [switch]$AddToPath,
    [switch]$DetailedOutput
)

# 로깅 설정
$script:LogFile = Join-Path $PSScriptRoot "..\logs\python_install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$script:SessionId = [guid]::NewGuid().ToString().Substring(0,8)

function Write-DCECPythonLog {
    param(
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",
        [string]$Message,
        [string]$Component = "PythonInstaller"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$script:SessionId] [$Level] [$Component] $Message"
    
    # 콘솔 출력
    switch ($Level) {
        "INFO" { Write-Host $logLine -ForegroundColor White }
        "WARNING" { Write-Host $logLine -ForegroundColor Yellow }
        "ERROR" { Write-Host $logLine -ForegroundColor Red }
        "SUCCESS" { Write-Host $logLine -ForegroundColor Green }
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

function Test-DCECAdminPrivileges {
    <#
    .SYNOPSIS
    관리자 권한 확인
    #>
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DCECPythonDownloadUrl {
    param(
        [string]$Version = "3.12.4"
    )
    
    $architecture = if ([Environment]::Is64BitOperatingSystem) { "amd64" } else { "win32" }
    return "https://www.python.org/ftp/python/$Version/python-$Version-$architecture.exe"
}

function Test-DCECPythonInstallation {
    <#
    .SYNOPSIS
    Python 설치 상태 확인
    #>
    try {
        # Python 실행 가능한지 확인
        $pythonExe = Get-Command python -ErrorAction SilentlyContinue
        if ($pythonExe) {
            $version = & python --version 2>&1
            if ($version -match "Python (\d+\.\d+\.\d+)") {
                Write-DCECPythonLog -Level SUCCESS -Message "Python 설치 확인: $version"
                return @{
                    Installed = $true
                    Version = $matches[1]
                    Path = $pythonExe.Source
                }
            }
        }
        
        # py launcher 확인
        $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
        if ($pyLauncher) {
            $version = & py --version 2>&1
            if ($version -match "Python (\d+\.\d+\.\d+)") {
                Write-DCECPythonLog -Level SUCCESS -Message "Python Launcher 확인: $version"
                return @{
                    Installed = $true
                    Version = $matches[1]
                    Path = $pyLauncher.Source
                    UseLauncher = $true
                }
            }
        }
        
        Write-DCECPythonLog -Level WARNING -Message "Python 설치가 감지되지 않음"
        return @{
            Installed = $false
            Version = $null
            Path = $null
        }
    }
    catch {
        Write-DCECPythonLog -Level ERROR -Message "Python 설치 확인 실패: $($_.Exception.Message)"
        return @{
            Installed = $false
            Version = $null
            Path = $null
            Error = $_.Exception.Message
        }
    }
}

function Install-DCECPython {
    <#
    .SYNOPSIS
    Python 설치 실행
    #>
    param(
        [string]$Version = "3.12.4",
        [string]$InstallPath = "$env:LOCALAPPDATA\Programs\Python",
        [switch]$Force
    )
    
    try {
        Write-DCECPythonLog -Level INFO -Message "Python $Version 설치 시작"
        
        # 기존 설치 확인
        $currentInstall = Test-DCECPythonInstallation
        if ($currentInstall.Installed -and !$Force) {
            Write-DCECPythonLog -Level WARNING -Message "Python이 이미 설치되어 있습니다: $($currentInstall.Version)"
            Write-DCECPythonLog -Level INFO -Message "강제 설치하려면 -Force 매개변수를 사용하세요"
            return $currentInstall
        }
        
        # 다운로드 URL 생성
        $downloadUrl = Get-DCECPythonDownloadUrl -Version $Version
        Write-DCECPythonLog -Level INFO -Message "다운로드 URL: $downloadUrl"
        
        # 임시 다운로드 경로
        $tempDir = Join-Path $env:TEMP "DCEC_Python_Install"
        if (!(Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        
        $installerPath = Join-Path $tempDir "python-installer.exe"
        
        # Python 설치 파일 다운로드
        Write-DCECPythonLog -Level INFO -Message "Python 설치 파일 다운로드 중..."
        try {
            $progressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Write-DCECPythonLog -Level SUCCESS -Message "다운로드 완료: $installerPath"
        }
        catch {
            Write-DCECPythonLog -Level ERROR -Message "다운로드 실패: $($_.Exception.Message)"
            throw
        }
        
        # 설치 실행
        Write-DCECPythonLog -Level INFO -Message "Python 설치 실행 중..."
        
        $installArgs = @(
            "/quiet"
            "InstallAllUsers=0"
            "PrependPath=1"
            "Include_test=0"
            "Include_pip=1"
            "Include_tcltk=1"
            "Include_launcher=1"
            "Include_doc=0"
            "Include_dev=0"
        )
        
        if ($InstallPath) {
            $installArgs += "TargetDir=$InstallPath"
        }
        
        $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-DCECPythonLog -Level SUCCESS -Message "Python 설치 완료"
            
            # 환경 변수 새로고침
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            # 설치 확인
            Start-Sleep -Seconds 3
            $verifyInstall = Test-DCECPythonInstallation
            
            if ($verifyInstall.Installed) {
                Write-DCECPythonLog -Level SUCCESS -Message "설치 확인 완료: Python $($verifyInstall.Version)"
                return $verifyInstall
            }
            else {
                Write-DCECPythonLog -Level ERROR -Message "설치 후 확인 실패"
                return $verifyInstall
            }
        }
        else {
            Write-DCECPythonLog -Level ERROR -Message "Python 설치 실패. 종료 코드: $($process.ExitCode)"
            throw "설치 프로세스가 실패했습니다"
        }
    }
    catch {
        Write-DCECPythonLog -Level ERROR -Message "Python 설치 중 오류 발생: $($_.Exception.Message)"
        throw
    }
    finally {
        # 임시 파일 정리
        if (Test-Path $installerPath) {
            try {
                Remove-Item $installerPath -Force
                Write-DCECPythonLog -Level INFO -Message "임시 설치 파일 정리 완료"
            }
            catch {
                Write-DCECPythonLog -Level WARNING -Message "임시 파일 정리 실패: $($_.Exception.Message)"
            }
        }
    }
}

function Test-DCECPipInstallation {
    <#
    .SYNOPSIS
    pip 설치 상태 및 동작 확인
    #>
    try {
        # pip 명령어 확인
        $pipExe = Get-Command pip -ErrorAction SilentlyContinue
        if ($pipExe) {
            $version = & pip --version 2>&1
            if ($version -match "pip (\d+\.\d+\.\d+)") {
                Write-DCECPythonLog -Level SUCCESS -Message "pip 확인: $version"
                return @{
                    Installed = $true
                    Version = $matches[1]
                    Path = $pipExe.Source
                }
            }
        }
        
        # python -m pip 확인
        try {
            $version = & python -m pip --version 2>&1
            if ($version -match "pip (\d+\.\d+\.\d+)") {
                Write-DCECPythonLog -Level SUCCESS -Message "pip (python -m pip) 확인: $version"
                return @{
                    Installed = $true
                    Version = $matches[1]
                    UseModule = $true
                }
            }
        }
        catch {
            # python -m pip 실패 시 py launcher 시도
            try {
                $version = & py -m pip --version 2>&1
                if ($version -match "pip (\d+\.\d+\.\d+)") {
                    Write-DCECPythonLog -Level SUCCESS -Message "pip (py -m pip) 확인: $version"
                    return @{
                        Installed = $true
                        Version = $matches[1]
                        UseLauncher = $true
                    }
                }
            }
            catch {
                Write-DCECPythonLog -Level ERROR -Message "pip 접근 실패"
            }
        }
        
        Write-DCECPythonLog -Level WARNING -Message "pip가 설치되지 않았거나 접근할 수 없습니다"
        return @{
            Installed = $false
            Version = $null
            Path = $null
        }
    }
    catch {
        Write-DCECPythonLog -Level ERROR -Message "pip 확인 실패: $($_.Exception.Message)"
        return @{
            Installed = $false
            Version = $null
            Path = $null
            Error = $_.Exception.Message
        }
    }
}

function Update-DCECPip {
    <#
    .SYNOPSIS
    pip 업그레이드
    #>
    try {
        Write-DCECPythonLog -Level INFO -Message "pip 업그레이드 시작"
        
        $pipStatus = Test-DCECPipInstallation
        if (!$pipStatus.Installed) {
            Write-DCECPythonLog -Level ERROR -Message "pip가 설치되지 않음"
            return $false
        }
        
        # pip 업그레이드 명령 실행
        if ($pipStatus.UseLauncher) {
            $result = & py -m pip install --upgrade pip 2>&1
        }
        elseif ($pipStatus.UseModule) {
            $result = & python -m pip install --upgrade pip 2>&1
        }
        else {
            $result = & pip install --upgrade pip 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-DCECPythonLog -Level SUCCESS -Message "pip 업그레이드 완료"
            Write-DCECPythonLog -Level INFO -Message "결과: $result"
            return $true
        }
        else {
            Write-DCECPythonLog -Level ERROR -Message "pip 업그레이드 실패: $result"
            return $false
        }
    }
    catch {
        Write-DCECPythonLog -Level ERROR -Message "pip 업그레이드 중 오류: $($_.Exception.Message)"
        return $false
    }
}

function Install-DCECPythonPackages {
    <#
    .SYNOPSIS
    기본 Python 패키지 설치
    #>
    param(
        [string[]]$Packages = @(
            "requests",
            "setuptools",
            "wheel",
            "virtualenv",
            "pip-tools"
        )
    )
    
    try {
        Write-DCECPythonLog -Level INFO -Message "기본 Python 패키지 설치 시작"
        
        $pipStatus = Test-DCECPipInstallation
        if (!$pipStatus.Installed) {
            Write-DCECPythonLog -Level ERROR -Message "pip가 설치되지 않음"
            return $false
        }
        
        $successCount = 0
        $failedPackages = @()
        
        foreach ($package in $Packages) {
            try {
                Write-DCECPythonLog -Level INFO -Message "패키지 설치 중: $package"
                
                if ($pipStatus.UseLauncher) {
                    $result = & py -m pip install $package 2>&1
                }
                elseif ($pipStatus.UseModule) {
                    $result = & python -m pip install $package 2>&1
                }
                else {
                    $result = & pip install $package 2>&1
                }
                
                if ($LASTEXITCODE -eq 0) {
                    Write-DCECPythonLog -Level SUCCESS -Message "$package 설치 완료"
                    $successCount++
                }
                else {
                    Write-DCECPythonLog -Level ERROR -Message "$package 설치 실패: $result"
                    $failedPackages += $package
                }
            }
            catch {
                Write-DCECPythonLog -Level ERROR -Message "$package 설치 중 오류: $($_.Exception.Message)"
                $failedPackages += $package
            }
        }
        
        Write-DCECPythonLog -Level INFO -Message "패키지 설치 완료: 성공 $successCount/$($Packages.Count)"
        if ($failedPackages.Count -gt 0) {
            Write-DCECPythonLog -Level WARNING -Message "실패한 패키지: $($failedPackages -join ', ')"
        }
        
        return ($failedPackages.Count -eq 0)
    }
    catch {
        Write-DCECPythonLog -Level ERROR -Message "패키지 설치 중 오류: $($_.Exception.Message)"
        return $false
    }
}

function New-DCECPythonEnvironmentReport {
    <#
    .SYNOPSIS
    Python 환경 보고서 생성
    #>
    try {
        Write-DCECPythonLog -Level INFO -Message "Python 환경 보고서 생성 중"
        
        $report = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            SessionId = $script:SessionId
            Python = Test-DCECPythonInstallation
            Pip = Test-DCECPipInstallation
            Environment = @{
                OS = "$([Environment]::OSVersion.VersionString)"
                Architecture = if ([Environment]::Is64BitOperatingSystem) { "x64" } else { "x86" }
                PowerShell = $PSVersionTable.PSVersion.ToString()
                User = [Environment]::UserName
                ComputerName = [Environment]::MachineName
            }
        }
        
        # 설치된 패키지 목록 (pip가 있는 경우)
        if ($report.Pip.Installed) {
            try {
                if ($report.Pip.UseLauncher) {
                    $packages = & py -m pip list --format=json 2>&1 | ConvertFrom-Json
                }
                elseif ($report.Pip.UseModule) {
                    $packages = & python -m pip list --format=json 2>&1 | ConvertFrom-Json
                }
                else {
                    $packages = & pip list --format=json 2>&1 | ConvertFrom-Json
                }
                $report.Packages = $packages
            }
            catch {
                Write-DCECPythonLog -Level WARNING -Message "패키지 목록 조회 실패: $($_.Exception.Message)"
                $report.Packages = @()
            }
        }
        
        # JSON 보고서 저장
        $reportPath = Join-Path $PSScriptRoot "..\docs\python_environment_report.json"
        $reportDir = Split-Path $reportPath -Parent
        if (!(Test-Path $reportDir)) {
            New-Item -Path $reportDir -ItemType Directory -Force | Out-Null
        }
        
        $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
        Write-DCECPythonLog -Level SUCCESS -Message "환경 보고서 저장: $reportPath"
        
        return $report
    }
    catch {
        Write-DCECPythonLog -Level ERROR -Message "환경 보고서 생성 실패: $($_.Exception.Message)"
        throw
    }
}

# 메인 실행 로직
try {
    Write-DCECPythonLog -Level INFO -Message "=== DCEC Python 환경 설정 시작 ==="
    Write-DCECPythonLog -Level INFO -Message "세션 ID: $script:SessionId"
    Write-DCECPythonLog -Level INFO -Message "로그 파일: $script:LogFile"
    
    # 관리자 권한 확인
    if (!(Test-DCECAdminPrivileges)) {
        Write-DCECPythonLog -Level WARNING -Message "관리자 권한이 없습니다. 일부 기능이 제한될 수 있습니다."
    }
    
    # 현재 Python 설치 상태 확인
    Write-DCECPythonLog -Level INFO -Message "현재 Python 설치 상태 확인 중..."
    $currentPython = Test-DCECPythonInstallation
    
    if ($currentPython.Installed -and !$Force) {
        Write-DCECPythonLog -Level SUCCESS -Message "Python이 이미 설치되어 있습니다: $($currentPython.Version)"
        Write-DCECPythonLog -Level INFO -Message "설치 경로: $($currentPython.Path)"
    }
    else {
        # Python 설치 실행
        $installResult = Install-DCECPython -Version $PythonVersion -InstallPath $InstallPath -Force:$Force
        if (!$installResult.Installed) {
            throw "Python 설치에 실패했습니다"
        }
    }
    
    # pip 확인 및 업그레이드
    Write-DCECPythonLog -Level INFO -Message "pip 상태 확인 중..."
    $pipStatus = Test-DCECPipInstallation
    
    if ($pipStatus.Installed) {
        if ($IncludePip) {
            Update-DCECPip
        }
        
        # 기본 패키지 설치
        Install-DCECPythonPackages
    }
    else {
        Write-DCECPythonLog -Level ERROR -Message "pip가 제대로 설치되지 않았습니다"
    }
    
    # 환경 보고서 생성
    $report = New-DCECPythonEnvironmentReport
    
    Write-DCECPythonLog -Level SUCCESS -Message "=== DCEC Python 환경 설정 완료 ==="
    Write-DCECPythonLog -Level INFO -Message "Python 버전: $($report.Python.Version)"
    Write-DCECPythonLog -Level INFO -Message "pip 버전: $($report.Pip.Version)"
    Write-DCECPythonLog -Level INFO -Message "설치된 패키지 수: $($report.Packages.Count)"
    
    # 결과 반환
    return @{
        Success = $true
        Python = $report.Python
        Pip = $report.Pip
        Report = $report
        LogFile = $script:LogFile
    }
}
catch {
    Write-DCECPythonLog -Level ERROR -Message "Python 환경 설정 실패: $($_.Exception.Message)"
    Write-DCECPythonLog -Level ERROR -Message "스택 추적: $($_.ScriptStackTrace)"
    
    return @{
        Success = $false
        Error = $_.Exception.Message
        LogFile = $script:LogFile
    }
}
