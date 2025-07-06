# WSL2 및 AI 도구 설치 자동화 스크립트
# 작업 디렉토리: d:/Dev/DCEC
# 로그 파일: setup.log, ai-tools-usage.log
# 로그 파일 네이밍 규칙 적용
$now = Get-Date -Format "yyyyMMdd_HHmmss"
$LogType = "INSTALL"
$LogDir = "D:\Dev\DCEC\Dev_Env\ClI\logs"
if (!(Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory }
$LogFile = Join-Path $LogDir ("${LogType}_$now.log")
function Write-Log {
    param(
        [string]$Type,
        [string]$Message,
        [string]$Result = ""
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "$timestamp [$Type] $Message"
    if ($Result -ne "") { $logLine += " [$Result]" }
    $logLine | Out-File -FilePath $LogFile -Append
}
Write-Log $LogType "WSL2 및 AI 도구 설치 자동화 시작"
# 1. WSL2 설치 및 상태 확인
Write-Log $LogType "WSL2 설치 및 상태 확인 중..."
wsl --status 2>&1 | Out-File -FilePath $LogFile -Append
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR" "WSL2가 설치되어 있지 않음. 설치를 진행하세요." "FAIL"
    Write-Host "WSL2가 설치되어 있지 않습니다. 관리자 권한 PowerShell에서 'wsl --install'을 실행하세요."
    exit 1
} else {
    Write-Log $LogType "WSL2가 정상적으로 설치되어 있음." "SUCCESS"
}
# 2. WSL2 Ubuntu 최신 패키지 업데이트 및 Node.js, npm 설치
Write-Log $LogType "WSL2 Ubuntu 패키지 업데이트 및 Node.js, npm 설치"
wsl bash -c "sudo apt update && sudo apt upgrade -y && curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt install -y nodejs" 2>&1 | Out-File -FilePath $LogFile -Append
# 3. Claude Code 최신 버전 확인 및 설치
Write-Log $LogType "Claude Code 최신 버전 확인 및 설치"
wsl bash -c "npm view @anthropic-ai/claude-code version" 2>&1 | Out-File -FilePath $LogFile -Append
wsl bash -c "sudo npm install -g @anthropic-ai/claude-code" 2>&1 | Out-File -FilePath $LogFile -Append
# 4. Gemini CLI 최신 버전 확인 및 설치
Write-Log $LogType "Gemini CLI 최신 버전 확인 및 설치"
wsl bash -c "curl -fsSL https://github.com/google-gemini/gemini-cli/releases/latest/download/install.sh -o install.sh && bash install.sh" 2>&1 | Out-File -FilePath $LogFile -Append
Write-Log $LogType "설치 자동화 완료" "END"
Write-Host "설치 및 로그 기록이 완료되었습니다. 자세한 내용은 $LogFile를 확인하세요."
