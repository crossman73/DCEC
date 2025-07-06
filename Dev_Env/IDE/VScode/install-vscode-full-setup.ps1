# install-vscode-full-setup.ps1
# PowerShell 스크립트 - VSCode + 환경 자동 설정 + 로그 및 상태 표시

# ==================== 초기 설정 ====================
$ErrorActionPreference = "Stop"
$logDir = "$PSScriptRoot\logs"
if (!(Test-Path $logDir)) {
  New-Item -ItemType Directory -Path $logDir | Out-Null
}

# 로그 파일명을 yyMMddHHmmss 형식으로 생성
$timestamp = Get-Date -Format "yyMMddHHmmss"
$logPath = "$logDir\${timestamp}_vscode.log"
Start-Transcript -Path $logPath -Append

function ShowProgress($activity, $percent) {
  Write-Progress -Activity $activity -PercentComplete $percent
  Write-Output "[PROGRESS] $activity ($percent%)"
}

function Check-Installed($command) {
  Get-Command $command -ErrorAction SilentlyContinue | Where-Object { $_.CommandType -eq 'Application' }
}

try {
  # ==================== VSCode 설치 ====================
  ShowProgress "VSCode 설치 확인 중..." 10
  if (!(Check-Installed "code")) {
    Write-Output "[INFO] VSCode 설치됨: 없음. 설치 진행 중..."
    choco install vscode -y
  } else {
    Write-Output "[INFO] VSCode가 이미 설치되어 있습니다."
  }

  # ==================== Fira Code 폰트 설치 ====================
  ShowProgress "Fira Code 폰트 설치 중..." 20
  $fontDir = "$env:SystemRoot\Fonts"
  $firaCodeUrl = "https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip"
  $fontZip = "$env:TEMP\FiraCode.zip"
  Invoke-WebRequest -Uri $firaCodeUrl -OutFile $fontZip
  Expand-Archive -Path $fontZip -DestinationPath "$env:TEMP\FiraCode" -Force

  $ttfFiles = Get-ChildItem "$env:TEMP\FiraCode\ttf" -Filter *.ttf
  foreach ($file in $ttfFiles) {
    Copy-Item $file.FullName -Destination $fontDir
    $fontReg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    New-ItemProperty -Path $fontReg -Name $file.BaseName -PropertyType String -Value $file.Name -Force | Out-Null
  }

  # ==================== VSCode 설정 복사 ====================
  ShowProgress "VSCode 설정 복사 중..." 40
  $vsCodeUserPath = "$env:APPDATA\Code\User"
  $projectSource = "$PSScriptRoot\.vscode"

  if (!(Test-Path $vsCodeUserPath)) {
    New-Item -ItemType Directory -Path $vsCodeUserPath | Out-Null
  }

  if (Test-Path "$projectSource\settings.json") {
    Copy-Item -Path "$projectSource\settings.json" -Destination "$vsCodeUserPath\settings.json" -Force
    Write-Output "[INFO] settings.json 복사 완료"
  } else {
    Write-Output "[WARN] settings.json 파일이 없습니다. 복사 생략"
  }

  if (Test-Path "$projectSource\extensions.json") {
    Copy-Item -Path "$projectSource\extensions.json" -Destination "$vsCodeUserPath\extensions.json" -Force
    Write-Output "[INFO] extensions.json 복사 완료"
  } else {
    Write-Output "[WARN] extensions.json 파일이 없습니다. 복사 생략"
  }

  # ==================== 확장 프로그램 설치 ====================
  ShowProgress "VSCode 확장 설치 중..." 60
  $extensions = @(
    "esbenp.prettier-vscode",
    "github.copilot",
    "formulahendry.auto-rename-tag",
    "oderwat.indent-rainbow",
    "ms-python.python",
    "ms-python.black-formatter",
    "VisualStudioExptTeam.vscodeintellicode",
    "usernamehw.errorlens",
    "humao.rest-client",
    "eamodio.gitlens"
  )

  foreach ($ext in $extensions) {
    Write-Output "[INFO] 설치 중: $ext"
    code --install-extension $ext --force
  }

  # ==================== 프로젝트 템플릿 복사 ====================
  ShowProgress "프로젝트 템플릿 복사 중..." 80
  $templateSource = "$PSScriptRoot\project-template"
  $templateTarget = "$PSScriptRoot\my-project"
  if (!(Test-Path $templateTarget)) {
    Copy-Item -Path $templateSource -Destination $templateTarget -Recurse -Force
    Write-Output "[INFO] 템플릿 프로젝트가 생성되었습니다: $templateTarget"
  } else {
    Write-Output "[INFO] 이미 템플릿 프로젝트가 존재합니다: $templateTarget"
  }

  # ==================== 완료 처리 ====================
  ShowProgress "설치 완료 및 정리 중..." 90
  Write-Output "[SUCCESS] 모든 작업이 완료되었습니다. VSCode를 실행하여 설정을 확인하세요."
  ShowProgress "설정 완료" 100
} catch {
  Write-Output "[ERROR] $($_.Exception.Message)"
} finally {
  Stop-Transcript
}
