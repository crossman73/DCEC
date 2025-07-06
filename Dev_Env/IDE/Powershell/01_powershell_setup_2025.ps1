# PowerShell 개발 환경 통합 초기화 스크립트
# 버전: 2025.07.02
# 최종 작성자: GPT for 무무님

# 관리자 권한 확인
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "[!] 관리자 권한으로 실행해주세요."
    Pause
    exit 1
}

# 날짜 기반 로그파일
$TODAY = Get-Date -Format yyyyMMdd_HHmmss
$LOG_FILE = "$env:USERPROFILE\powershell_setup_log_$TODAY.log"
function Log ($msg) {
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    Add-Content -Path $LOG_FILE -Value "[$timestamp] $msg"
    Write-Host "[$timestamp] $msg"
}

Log "[START] 개발 환경 설정 시작"

# 인터넷 연결 확인
Write-Host "[STEP 1/10] 인터넷 연결 확인 중..."
if (-not (Test-Connection -ComputerName www.google.com -Count 1 -Quiet)) {
    Log "[ERROR] 인터넷 연결 실패"
    exit 1
}
Log "[INFO] 인터넷 연결 확인 완료"

# 최신 PowerShell 설치 (7.5.2)
function Install-LatestPowerShell {
    $pwshVersion = "7.5.2"
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        Log "[INFO] 최신 PowerShell 이미 설치됨"
        return
    }

    $url = "https://github.com/PowerShell/PowerShell/releases/download/v$pwshVersion/PowerShell-$pwshVersion-win-x64.msi"
    $msi = "$env:TEMP\pwsh-$pwshVersion.msi"

    Log "[INFO] PowerShell MSI 다운로드 중..."
    Invoke-WebRequest -Uri $url -OutFile $msi
    Log "[INFO] PowerShell 설치 실행 중..."
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /quiet /norestart"
    Log "[INFO] PowerShell $pwshVersion 설치 완료"
}
Install-LatestPowerShell

# Chocolatey 설치
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Log "[INFO] Chocolatey 설치 중..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:PATH += ";$env:ProgramData\chocolatey\bin"
    Log "[INFO] Chocolatey 설치 완료"
}

# 공통 설치 함수 (winget/choco fallback + 중복방지)
function Install-DevTool {
    param(
        [string]$wingetId,
        [string]$displayName,
        [string]$chocoId = $null
    )

    if (-not $chocoId) { $chocoId = $displayName }

    $exists = winget list | Select-String -Pattern $displayName
    if ($exists) {
        Log "[SKIP] $displayName 이미 설치됨"
        return
    }

    Write-Host "[STEP] $displayName 설치 시도 중..."
    winget install --id $wingetId --accept-package-agreements --accept-source-agreements --silent --scope user
    if ($LASTEXITCODE -eq 0) {
        Log "[SUCCESS] $displayName 설치 완료 (winget)"
        return
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Log "[WARN] $displayName 설치 실패 (winget). choco 대체 시도: $chocoId"
        choco install $chocoId -y
        if ($LASTEXITCODE -eq 0) {
            Log "[SUCCESS] $displayName 설치 완료 (choco)"
        } else {
            Log "[ERROR] $displayName 설치 실패 (choco)"
        }
    } else {
        Log "[ERROR] $displayName 설치 실패 (winget/choco 불가)"
    }
}

# 필수 도구 설치
$tools = @(
    @("Microsoft.WindowsTerminal", "Windows Terminal"),
    @("Git.Git", "Git"),
    @("Starship.Starship", "Starship"),
    @("Microsoft.PowerToys", "PowerToys"),
    @("Python.Python.3.13", "Python")
)
foreach ($t in $tools) {
    Install-DevTool $t[0] $t[1]
}

# Scoop 설치 및 Nerd Fonts
$scoopInstalled = Get-Command scoop -ErrorAction SilentlyContinue
if (-not $scoopInstalled) {
    Log "[WARN] Scoop은 관리자 PowerShell에서 설치할 수 없습니다."
    Log "[SKIP] Nerd Fonts 설치 생략됨. 일반 PowerShell에서 아래 실행:"
    Write-Host "`n   iwr -useb get.scoop.sh | iex`n"
} else {
    try {
        scoop bucket add nerd-fonts https://github.com/matthewjberger/scoop-nerd-fonts -Force
        scoop install FiraCode-NF JetBrainsMono-NF
        Log "[INFO] Nerd Fonts 설치 완료 (scoop)"
    } catch {
        Log "[ERROR] Nerd Fonts 설치 중 오류: $_"
    }
}

# Microsoft Graph 설치
Install-Module Microsoft.Graph -Scope CurrentUser -Force
Log "[INFO] Microsoft.Graph 모듈 설치 완료"

# PowerShell 프로필 구성
$profilePath = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
$profileContent = @'
# 기본 환경 설정
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# 인코딩 설정
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[System.Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
[System.Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# 실행 정책 설정
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# 환경 변수 설정
$env:DCEC_ROOT = "D:\Dev\DCEC"
$env:DCEC_ENV = "D:\Dev\DCEC\Dev_Env"
$env:DCEC_CLI = "D:\Dev\DCEC\Dev_Env\CLI"
$env:PATH = "$env:DCEC_CLI\bin;$env:PATH"

# 모듈 임포트 (오류 무시)
$modules = @(
    'Terminal-Icons',
    'PSReadLine',
    'posh-git',
    'Microsoft.Graph'
)

foreach ($module in $modules) {
    try {
        Import-Module $module -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "모듈 로드 실패: $module"
    }
}

# Starship 초기화
try {
    Invoke-Expression (&starship init powershell)
} catch {
    Write-Warning "Starship 초기화 실패"
}

# PSReadLine 설정
if (Get-Module PSReadLine) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
}

# 작업 디렉토리 이동
if (Test-Path $env:DCEC_ROOT) {
    Set-Location $env:DCEC_ROOT
}
'@
$profileContent | Set-Content -Path $profilePath -Encoding utf8
Log "[INFO] PowerShell 프로필 작성 완료"

# 완료
Log "[COMPLETE] PowerShell 개발 환경 구성 완료"
Write-Host "`n[DONE] PowerShell 개발 환경이 성공적으로 설정되었습니다."


# ───────────────────────────────
# 설치 후 확인 명령어
# ───────────────────────────────
#pwsh -v
#code
#starship --version
#python --version