# Install-Python.ps1
# Python 설치 및 pip 설정 자동화 스크립트

param(
    [string]$Version = "3.13.5",
    [string]$Architecture = "amd64",
    [string]$InstallPath = "C:\Python313",
    [switch]$Force,
    [switch]$AddToPath
)

# 로깅 설정
$LogPath = "$PSScriptRoot\..\logs"
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}
$LogFile = "$LogPath\python-install-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-DCECLog {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )
    
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}

function Test-AdminPrivileges {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PythonDownloadUrl {
    param(
        [string]$Version,
        [string]$Architecture
    )
    
    $baseUrl = "https://www.python.org/ftp/python"
    $fileName = "python-$Version-$Architecture.exe"
    return "$baseUrl/$Version/$fileName"
}

function Install-PythonFromWeb {
    param(
        [string]$Version,
        [string]$Architecture,
        [string]$InstallPath,
        [bool]$AddToPath
    )
    
    try {
        Write-DCECLog "Python $Version 설치 시작" "INFO"
        
        # 다운로드 URL 생성
        $downloadUrl = Get-PythonDownloadUrl -Version $Version -Architecture $Architecture
        $installerPath = "$env:TEMP\python-$Version-installer.exe"
        
        Write-DCECLog "다운로드 URL: $downloadUrl" "INFO"
        Write-DCECLog "설치 파일 경로: $installerPath" "INFO"
        
        # Python 설치 프로그램 다운로드
        Write-DCECLog "Python 설치 프로그램 다운로드 중..." "INFO"
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath -UseBasicParsing
            Write-DCECLog "다운로드 완료" "SUCCESS"
        }
        catch {
            Write-DCECLog "다운로드 실패: $($_.Exception.Message)" "ERROR"
            return $false
        }
        
        # 설치 파일 존재 확인
        if (-not (Test-Path $installerPath)) {
            Write-DCECLog "설치 파일을 찾을 수 없습니다: $installerPath" "ERROR"
            return $false
        }
        
        # 설치 매개변수 설정
        $installArgs = @(
            "/quiet",
            "InstallAllUsers=1",
            "PrependPath=1",
            "Include_test=0",
            "Include_pip=1",
            "Include_tcltk=1",
            "Include_launcher=1",
            "Include_doc=0",
            "Include_debug=0",
            "Include_symbols=0",
            "CompileAll=0",
            "SimpleInstall=1"
        )
        
        if ($InstallPath -ne "C:\Python313") {
            $installArgs += "TargetDir=$InstallPath"
        }
        
        Write-DCECLog "설치 매개변수: $($installArgs -join ' ')" "INFO"
        
        # Python 설치 실행
        Write-DCECLog "Python 설치 실행 중..." "INFO"
        $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-DCECLog "Python 설치 완료" "SUCCESS"
        }
        else {
            Write-DCECLog "Python 설치 실패 (Exit Code: $($process.ExitCode))" "ERROR"
            return $false
        }
        
        # 설치 파일 정리
        Remove-Item $installerPath -ErrorAction SilentlyContinue
        
        return $true
    }
    catch {
        Write-DCECLog "Python 설치 중 오류 발생: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-PythonInstallation {
    Write-DCECLog "Python 설치 확인 중..." "INFO"
    
    # 환경 변수 새로고침
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Python 버전 확인
    try {
        $pythonVersion = & py --version 2>&1
        Write-DCECLog "Python 버전: $pythonVersion" "SUCCESS"
    }
    catch {
        Write-DCECLog "Python 실행 실패" "ERROR"
        return $false
    }
    
    # pip 버전 확인
    try {
        $pipVersion = & py -m pip --version 2>&1
        Write-DCECLog "pip 버전: $pipVersion" "SUCCESS"
    }
    catch {
        Write-DCECLog "pip 실행 실패" "ERROR"
        return $false
    }
    
    return $true
}

function Update-PipAndPackages {
    Write-DCECLog "pip 업데이트 중..." "INFO"
    
    try {
        # pip 업데이트
        & py -m pip install --upgrade pip
        Write-DCECLog "pip 업데이트 완료" "SUCCESS"
        
        # 기본 패키지 설치
        $packages = @(
            "wheel",
            "setuptools",
            "requests",
            "certifi"
        )
        
        foreach ($package in $packages) {
            Write-DCECLog "패키지 설치: $package" "INFO"
            & py -m pip install $package
        }
        
        Write-DCECLog "기본 패키지 설치 완료" "SUCCESS"
        return $true
    }
    catch {
        Write-DCECLog "pip 업데이트 실패: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# 메인 실행
Write-DCECLog "Python 설치 스크립트 시작" "INFO"
Write-DCECLog "로그 파일: $LogFile" "INFO"

# 관리자 권한 확인
if (-not (Test-AdminPrivileges)) {
    Write-DCECLog "관리자 권한이 필요합니다. PowerShell을 관리자 권한으로 실행하세요." "ERROR"
    exit 1
}

# 기존 설치 확인
if (-not $Force) {
    Write-DCECLog "기존 Python 설치 확인 중..." "INFO"
    if (Test-PythonInstallation) {
        Write-DCECLog "Python이 이미 정상적으로 설치되어 있습니다." "SUCCESS"
        Write-DCECLog "-Force 매개변수를 사용하여 강제 재설치할 수 있습니다." "INFO"
        exit 0
    }
}

# Python 설치
if (Install-PythonFromWeb -Version $Version -Architecture $Architecture -InstallPath $InstallPath -AddToPath $AddToPath) {
    Write-DCECLog "Python 설치 단계 완료" "SUCCESS"
    
    # 설치 확인
    Start-Sleep -Seconds 5
    if (Test-PythonInstallation) {
        Write-DCECLog "Python 설치 확인 완료" "SUCCESS"
        
        # pip 업데이트
        if (Update-PipAndPackages) {
            Write-DCECLog "모든 설치 과정이 완료되었습니다." "SUCCESS"
        }
        else {
            Write-DCECLog "pip 업데이트에 실패했지만 Python은 정상적으로 설치되었습니다." "WARNING"
        }
    }
    else {
        Write-DCECLog "Python 설치 확인 실패" "ERROR"
        exit 1
    }
}
else {
    Write-DCECLog "Python 설치 실패" "ERROR"
    exit 1
}

Write-DCECLog "Python 설치 스크립트 완료" "SUCCESS"
