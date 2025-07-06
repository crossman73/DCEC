# Install-Python-User.ps1
# 사용자 수준 Python 설치 (관리자 권한 불필요)

param(
    [string]$Version = "3.13.5",
    [string]$Architecture = "amd64",
    [switch]$Force
)

# 로깅 설정
$LogPath = "$PSScriptRoot\..\logs"
if (-not (Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}
$LogFile = "$LogPath\python-user-install-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

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

function Get-PythonDownloadUrl {
    param(
        [string]$Version,
        [string]$Architecture
    )
    
    $baseUrl = "https://www.python.org/ftp/python"
    $fileName = "python-$Version-$Architecture.exe"
    return "$baseUrl/$Version/$fileName"
}

function Install-PythonForUser {
    param(
        [string]$Version,
        [string]$Architecture
    )
    
    try {
        Write-DCECLog "사용자 수준 Python $Version 설치 시작" "INFO"
        
        # 다운로드 URL 생성
        $downloadUrl = Get-PythonDownloadUrl -Version $Version -Architecture $Architecture
        $installerPath = "$env:TEMP\python-$Version-user-installer.exe"
        
        Write-DCECLog "다운로드 URL: $downloadUrl" "INFO"
        
        # Python 설치 프로그램 다운로드
        Write-DCECLog "Python 설치 프로그램 다운로드 중..." "INFO"
        try {
            $ProgressPreference = 'SilentlyContinue'
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
        
        # 사용자 수준 설치 매개변수
        $installArgs = @(
            "/passive",
            "InstallAllUsers=0",           # 사용자 수준 설치
            "PrependPath=1",               # PATH에 추가
            "Include_test=0",              # 테스트 제외
            "Include_pip=1",               # pip 포함
            "Include_tcltk=1",             # Tkinter 포함
            "Include_launcher=1",          # Python Launcher 포함
            "Include_doc=0",               # 문서 제외
            "Include_debug=0",             # 디버그 기호 제외
            "Include_symbols=0",           # 디버그 제외
            "CompileAll=0",                # 컴파일 제외
            "SimpleInstall=1",             # 간단 설치
            "AssociateFiles=1"             # 파일 연결
        )
        
        Write-DCECLog "설치 매개변수: $($installArgs -join ' ')" "INFO"
        
        # Python 설치 실행
        Write-DCECLog "Python 설치 실행 중... (이 과정은 몇 분이 걸릴 수 있습니다)" "INFO"
        $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
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

function Update-EnvironmentPath {
    Write-DCECLog "환경 변수 업데이트 중..." "INFO"
    
    # 사용자 환경 변수에서 PATH 가져오기
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    # 현재 세션 PATH 업데이트
    $env:Path = $machinePath + ";" + $userPath
    
    Write-DCECLog "환경 변수 업데이트 완료" "SUCCESS"
}

function Test-PythonInstallation {
    Write-DCECLog "Python 설치 확인 중..." "INFO"
    
    # 환경 변수 새로고침
    Update-EnvironmentPath
    
    # 잠시 대기 (설치 완료 대기)
    Start-Sleep -Seconds 3
    
    # Python 버전 확인
    try {
        $result = & py --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-DCECLog "Python 버전: $result" "SUCCESS"
        }
        else {
            Write-DCECLog "Python 실행 실패: $result" "ERROR"
            return $false
        }
    }
    catch {
        Write-DCECLog "Python 실행 실패: $($_.Exception.Message)" "ERROR"
        return $false
    }
    
    # pip 버전 확인
    try {
        $result = & py -m pip --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-DCECLog "pip 버전: $result" "SUCCESS"
        }
        else {
            Write-DCECLog "pip 실행 실패: $result" "ERROR"
            return $false
        }
    }
    catch {
        Write-DCECLog "pip 실행 실패: $($_.Exception.Message)" "ERROR"
        return $false
    }
    
    return $true
}

function Update-PipAndPackages {
    Write-DCECLog "pip 업그레이드 및 기본 패키지 설치 중..." "INFO"
    
    try {
        # pip 업그레이드
        $result = & py -m pip install --upgrade pip 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-DCECLog "pip 업그레이드 완료" "SUCCESS"
        }
        else {
            Write-DCECLog "pip 업그레이드 실패: $result" "WARNING"
        }
        
        # 기본 패키지 설치
        $packages = @("wheel", "setuptools", "requests", "certifi")
        
        foreach ($package in $packages) {
            Write-DCECLog "패키지 설치: $package" "INFO"
            $result = & py -m pip install $package 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-DCECLog "패키지 설치 완료: $package" "SUCCESS"
            }
            else {
                Write-DCECLog "패키지 설치 실패: $package - $result" "WARNING"
            }
        }
        
        return $true
    }
    catch {
        Write-DCECLog "패키지 업데이트 실패: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Remove-BrokenPython {
    Write-DCECLog "손상된 Python 설치 정리 중..." "INFO"
    
    # 손상된 Python 경로들 확인 및 정리
    $brokenPaths = @(
        "C:\Python313",
        "C:\Users\crossman\AppData\Local\Programs\Python\Python313"
    )
    
    foreach ($path in $brokenPaths) {
        if (Test-Path $path) {
            try {
                Write-DCECLog "정리 중: $path" "INFO"
                Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
                Write-DCECLog "정리 완료: $path" "SUCCESS"
            }
            catch {
                Write-DCECLog "정리 실패: $path - $($_.Exception.Message)" "WARNING"
            }
        }
    }
}

# 메인 실행
Write-DCECLog "사용자 수준 Python 설치 스크립트 시작" "INFO"
Write-DCECLog "로그 파일: $LogFile" "INFO"

# 기존 설치 확인
if (-not $Force) {
    Write-DCECLog "기존 Python 설치 확인 중..." "INFO"
    if (Test-PythonInstallation) {
        Write-DCECLog "Python이 이미 정상적으로 설치되어 있습니다." "SUCCESS"
        Write-DCECLog "-Force 매개변수를 사용하여 강제 재설치할 수 있습니다." "INFO"
        exit 0
    }
}

# 손상된 Python 정리 (자동)
Write-DCECLog "손상된 Python 설치 정리 중..." "INFO"
Remove-BrokenPython

# Python 설치
if (Install-PythonForUser -Version $Version -Architecture $Architecture) {
    Write-DCECLog "Python 설치 완료, 확인 중..." "SUCCESS"
    
    # 설치 확인
    if (Test-PythonInstallation) {
        Write-DCECLog "Python 설치 확인 완료" "SUCCESS"
        
        # pip 업그레이드 및 패키지 설치
        if (Update-PipAndPackages) {
            Write-DCECLog "모든 설치 과정이 완료되었습니다!" "SUCCESS"
            Write-DCECLog "새 PowerShell 세션에서 'py --version' 및 'py -m pip --version'으로 확인하세요." "INFO"
        }
        else {
            Write-DCECLog "pip 업데이트에 실패했지만 Python은 정상적으로 설치되었습니다." "WARNING"
        }
    }
    else {
        Write-DCECLog "Python 설치 확인 실패 - 새 PowerShell 세션에서 다시 확인해보세요." "WARNING"
    }
}
else {
    Write-DCECLog "Python 설치 실패" "ERROR"
    exit 1
}

Write-DCECLog "스크립트 완료" "SUCCESS"
