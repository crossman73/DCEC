@echo off
:: 먼저 인코딩 설정 (한글 깨짐 방지)
chcp 65001 >nul 2>&1
reg add "HKEY_CURRENT_USER\Console" /v "CodePage" /t REG_DWORD /d 65001 /f >nul 2>&1

:: 관리자 권한 확인
net session >nul 2>&1
if %errorLevel% == 0 (
    echo 관리자 권한으로 실행 중...
) else (
    echo 이 스크립트는 관리자 권한이 필요합니다.
    echo 우클릭하여 "관리자 권한으로 실행"을 선택하세요.
    pause
    exit /b 1
)

:: 인코딩 재설정 및 PowerShell 실행 정책 먼저 설정
powershell -Command "Set-ExecutionPolicy RemoteSigned -Force" >nul 2>&1

echo ===============================================================
echo        PowerShell 최강 환경 구축 스크립트 (2단계)
echo ===============================================================
echo.
echo 🎯 1단계: 기본 환경 설정 및 필수 도구 설치
echo    - 인코딩 설정, PowerShell 7, Windows Terminal
echo    - 패키지 매니저 (Chocolatey, Scoop)
echo    - 개발 도구 (Git, Node.js, Python)
echo    - 기본 폰트 설치
echo.
echo 🚀 2단계: PowerShell 고급 애드온 설치
echo    - 테마 및 프롬프트 (Oh My Posh, Starship)
echo    - 생산성 모듈 (PSReadLine, Terminal-Icons, Z)
echo    - 검색 도구 (Fzf, Ripgrep)
echo    - 커스텀 프로필 설정
echo.
echo ⚠️  주의: 1단계 완료 후 재시작이 필요합니다!
echo.
set /p continue="1단계 기본 환경 설정을 시작하시겠습니까? (Y/N): "
if /i not "%continue%"=="Y" exit /b 0

echo.
echo ===============================================================
echo                    1단계: 기본 환경 설정
echo ===============================================================
echo.

echo [1/10] 시스템 인코딩 완전 설정 중...
:: 시스템 전체 인코딩 설정
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\CodePage" /v "ACP" /t REG_SZ /d "65001" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\CodePage" /v "OEMCP" /t REG_SZ /d "65001" /f >nul 2>&1
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Command Processor" /v "Autorun" /t REG_SZ /d "chcp 65001 >nul" /f >nul 2>&1
:: 현재 세션 인코딩 재설정
chcp 65001 >nul 2>&1
echo 완료!

echo [2/10] Chocolatey 패키지 매니저 설치 중...
powershell -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
if %errorLevel% neq 0 (
    echo ❌ Chocolatey 설치 실패
    pause
    exit /b 1
)
echo 완료!

echo [3/10] 환경 변수 새로고침 중...
call refreshenv >nul 2>&1
echo 완료!

echo [4/10] Scoop 패키지 매니저 설치 중...
powershell -Command "Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; iwr -useb get.scoop.sh | iex"
if %errorLevel% neq 0 (
    echo ❌ Scoop 설치 실패
    pause
    exit /b 1
)
echo 완료!

echo [5/10] PowerShell 7 설치 중...
choco install powershell-core -y
if %errorLevel% neq 0 (
    echo ❌ PowerShell 7 설치 실패
    pause
    exit /b 1
)
echo 완료!

echo [6/10] Windows Terminal 설치 중...
winget install Microsoft.WindowsTerminal --accept-source-agreements --accept-package-agreements --silent
if %errorLevel% neq 0 (
    echo ❌ Windows Terminal 설치 실패 (계속 진행)
)
echo 완료!

echo [7/10] 필수 개발 도구 설치 중...
echo    - Git 설치...
choco install git -y >nul 2>&1
echo    - Node.js 설치...
choco install nodejs -y >nul 2>&1
echo    - Python 설치...
choco install python -y >nul 2>&1
echo 완료!

echo [8/10] D2Coding 폰트 설치 중...
powershell -Command "
try {
    Invoke-WebRequest -Uri 'https://github.com/naver/d2codingfont/releases/download/VER1.3.2/D2Coding-Ver1.3.2-20180524.zip' -OutFile 'D2Coding.zip'
    Expand-Archive -Path 'D2Coding.zip' -DestinationPath 'D2Coding' -Force
    `$fonts = Get-ChildItem -Path 'D2Coding' -Filter '*.ttf'
    foreach (`$font in `$fonts) {
        `$fontPath = `$font.FullName
        `$fontName = `$font.Name
        Copy-Item -Path `$fontPath -Destination 'C:\Windows\Fonts\' -Force
        `$fontReg = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
        `$fontRegName = `$fontName -replace '\.ttf`$', ' (TrueType)'
        New-ItemProperty -Path `$fontReg -Name `$fontRegName -Value `$fontName -PropertyType String -Force | Out-Null
    }
    Remove-Item -Path 'D2Coding.zip', 'D2Coding' -Recurse -Force
    Write-Host '폰트 설치 완료'
} catch {
    Write-Host '폰트 설치 실패 (계속 진행)'
}
"
echo 완료!

echo [9/10] 기본 Windows Terminal 설정 파일 생성 중...
powershell -Command "
`$terminalSettingsPath = \"`$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json\"
if (Test-Path (Split-Path `$terminalSettingsPath)) {
    `$terminalSettings = @'
{
    \"`$help\": \"https://aka.ms/terminal-documentation\",
    \"`$schema\": \"https://aka.ms/terminal-profiles-schema\",
    \"defaultProfile\": \"{574e775e-4f2a-5b96-ac1e-a2962a402336}\",
    \"copyOnSelect\": false,
    \"copyFormatting\": \"none\",
    \"profiles\": {
        \"defaults\": {
            \"fontFace\": \"D2Coding\",
            \"fontSize\": 12,
            \"colorScheme\": \"Campbell Powershell\",
            \"cursorShape\": \"bar\",
            \"snapOnInput\": true
        },
        \"list\": [
            {
                \"commandline\": \"pwsh.exe\",
                \"guid\": \"{574e775e-4f2a-5b96-ac1e-a2962a402336}\",
                \"hidden\": false,
                \"name\": \"PowerShell 7\",
                \"source\": \"Windows.Terminal.PowershellCore\"
            },
            {
                \"commandline\": \"powershell.exe\",
                \"guid\": \"{61c54bbd-c2c6-5271-96e7-009a87ff44bf}\",
                \"hidden\": false,
                \"name\": \"Windows PowerShell\"
            },
            {
                \"commandline\": \"cmd.exe\",
                \"guid\": \"{0caa0dad-35be-5f56-a8ff-afceeeaa6101}\",
                \"hidden\": false,
                \"name\": \"명령 프롬프트\"
            }
        ]
    }
}
'@
    Set-Content -Path `$terminalSettingsPath -Value `$terminalSettings -Encoding UTF8
    Write-Host 'Windows Terminal 설정 완료'
} else {
    Write-Host 'Windows Terminal이 설치되지 않았습니다.'
}
"
echo 완료!

echo [10/10] 환경 변수 최종 새로고침...
call refreshenv >nul 2>&1
echo 완료!

echo.
echo ===============================================================
echo                    1단계 완료! ✅
echo ===============================================================
echo.
echo 설치 완료된 항목:
echo ✅ 시스템 인코딩: UTF-8 (65001)
echo ✅ Chocolatey 패키지 매니저
echo ✅ Scoop 패키지 매니저
echo ✅ PowerShell 7 (최신 버전)
echo ✅ Windows Terminal
echo ✅ Git, Node.js, Python
echo ✅ D2Coding 폰트
echo ✅ 기본 Terminal 설정
echo.
echo ⚠️  중요: 1단계 완료 후 반드시 시스템을 재시작해야 합니다!
echo.
echo 시스템 재시작 후:
echo 1. Windows Terminal 실행
echo 2. PowerShell 7 탭 선택
echo 3. 이 스크립트를 다시 실행하여 2단계 진행
echo.
echo 지금 시스템을 재시작하시겠습니까? (Y/N)
set /p restart="입력: "
if /i "%restart%"=="Y" (
    echo.
    echo 📝 재시작 후 할 일:
    echo 1. Windows Terminal 실행
    echo 2. 이 배치 파일을 다시 실행
    echo 3. 2단계 애드온 설치 진행
    echo.
    echo 10초 후 재시작됩니다...
    timeout /t 10
    shutdown /r /t 0
) else (
    echo.
    echo 📝 수동 재시작 후 할 일:
    echo 1. 시스템 재시작
    echo 2. Windows Terminal 실행
    echo 3. 이 배치 파일을 다시 실행
    echo 4. 2단계 선택하여 애드온 설치
    echo.
    goto :stage2_menu
)

:stage2_menu
echo.
echo 재시작 후 2단계를 진행하시겠습니까? (Y/N)
set /p stage2="입력: "
if /i not "%stage2%"=="Y" (
    echo 나중에 2단계를 진행하려면 이 스크립트를 다시 실행하세요.
    pause
    exit /b 0
)

echo.
echo ===============================================================
echo                    2단계: 고급 애드온 설치
echo ===============================================================
echo.

echo [1/8] Scoop 버킷 추가 및 도구 설치 중...
scoop bucket add extras >nul 2>&1
scoop install fzf ripgrep fd bat delta starship >nul 2>&1
echo 완료!

echo [2/8] Oh My Posh 설치 중...
winget install JanDeDobbeleer.OhMyPosh -s winget --accept-source-agreements --accept-package-agreements --silent >nul 2>&1
echo 완료!

echo [3/8] PowerShell 모듈 설치 중 (시간이 걸릴 수 있습니다)...
pwsh -Command "
Write-Host '  - Terminal-Icons 설치 중...'
Install-Module -Name Terminal-Icons -Repository PSGallery -Force -Scope CurrentUser
Write-Host '  - PSReadLine 설치 중...'
Install-Module -Name PSReadLine -Repository PSGallery -Force -AllowPrerelease -Scope CurrentUser
Write-Host '  - z 설치 중...'
Install-Module -Name z -Repository PSGallery -Force -Scope CurrentUser
Write-Host '  - PSFzf 설치 중...'
Install-Module -Name PSFzf -Repository PSGallery -Force -Scope CurrentUser
Write-Host '  - posh-git 설치 중...'
Install-Module -Name posh-git -Repository PSGallery -Force -Scope CurrentUser
Write-Host '모듈 설치 완료'
"
echo 완료!

echo [4/8] PowerShell 프로필 생성 중...
pwsh -Command "
if (!(Test-Path `$PROFILE)) { New-Item -Path `$PROFILE -Type File -Force | Out-Null }
`$profileContent = @'
# PowerShell 최강 환경 설정

# 인코딩 설정
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
`$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
`$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# 모듈 임포트
Import-Module Terminal-Icons -ErrorAction SilentlyContinue
Import-Module z -ErrorAction SilentlyContinue
Import-Module PSFzf -ErrorAction SilentlyContinue
Import-Module posh-git -ErrorAction SilentlyContinue

# PSReadLine 설정 (자동완성 및 구문 강조)
if (Get-Module PSReadLine) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function ViExit
    Set-PSReadLineKeyHandler -Key Ctrl+l -Function ClearScreen
}

# FZF 설정
if (Get-Module PSFzf) {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# 별칭 설정
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name la -Value Get-ChildItem
Set-Alias -Name grep -Value Select-String
Set-Alias -Name cat -Value Get-Content
Set-Alias -Name which -Value Get-Command

# 유용한 함수들
function Get-Weather([string]`$City='Seoul') { 
    try { (Invoke-RestMethod -Uri \"http://wttr.in/`$City?format=3\") } 
    catch { \"날씨 정보를 가져올 수 없습니다.\" }
}
function Get-PublicIP { 
    try { (Invoke-RestMethod -Uri 'http://ipinfo.io/json').ip } 
    catch { \"IP 정보를 가져올 수 없습니다.\" }
}
function Test-Port([string]`$Host, [int]`$Port) { Test-NetConnection -ComputerName `$Host -Port `$Port }
function Get-ProcessTree { Get-Process | Format-Table -Property Id, Name, CPU, WorkingSet }
function New-Directory([string]`$Name) { New-Item -ItemType Directory -Name `$Name -Force }

# Starship 프롬프트 초기화
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
} else {
    # Oh My Posh 사용 (Starship이 없을 경우)
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        oh-my-posh init pwsh --config \"`$env:POSH_THEMES_PATH\\jandedobbeleer.omp.json\" | Invoke-Expression
    }
}

# 시작 메시지
Write-Host \"PowerShell 최강 환경이 로드되었습니다! 🚀\" -ForegroundColor Green
Write-Host \"유용한 명령어: weather, Get-PublicIP, ll, la, z <directory>, Ctrl+F, Ctrl+R\" -ForegroundColor Yellow
'@
Set-Content -Path `$PROFILE -Value `$profileContent -Encoding UTF8
Write-Host 'PowerShell 프로필 생성 완료'
"
echo 완료!

echo [5/8] Starship 설정 파일 생성 중...
pwsh -Command "
`$starshipConfig = @'
format = \"\"\"
`$username`$hostname`$directory`$git_branch`$git_status`$cmd_duration`$line_break`$character
\"\"\"

[username]
show_always = true
format = \"[`$user](`$style) \"
style_user = \"bold blue\"

[hostname]
ssh_only = false
format = \"@[`$hostname](`$style) \"
style = \"bold green\"

[directory]
truncation_length = 3
format = \"in [`$path](`$style) \"
style = \"bold cyan\"

[git_branch]
format = \"on [`$symbol`$branch](`$style) \"
style = \"bold purple\"

[git_status]
format = \"([`$all_status`$ahead_behind](`$style)) \"
style = \"bold red\"

[cmd_duration]
format = \"took [`$duration](`$style) \"
style = \"bold yellow\"

[character]
success_symbol = \"[➜](`$style) \"
error_symbol = \"[➜](`$style) \"
style_success = \"bold green\"
style_failure = \"bold red\"
'@
`$starshipConfigPath = \"`$env:USERPROFILE\\.config\\starship.toml\"
`$configDir = Split-Path `$starshipConfigPath
if (!(Test-Path `$configDir)) { New-Item -ItemType Directory -Path `$configDir -Force | Out-Null }
Set-Content -Path `$starshipConfigPath -Value `$starshipConfig -Encoding UTF8
Write-Host 'Starship 설정 파일 생성 완료'
"
echo 완료!

echo [6/8] Windows Terminal 고급 설정 업데이트 중...
pwsh -Command "
`$terminalSettingsPath = \"`$env:LOCALAPPDATA\\Packages\\Microsoft.WindowsTerminal_8wekyb3d8bbwe\\LocalState\\settings.json\"
if (Test-Path `$terminalSettingsPath) {
    `$advancedSettings = @'
{
    \"`$help\": \"https://aka.ms/terminal-documentation\",
    \"`$schema\": \"https://aka.ms/terminal-profiles-schema\",
    \"defaultProfile\": \"{574e775e-4f2a-5b96-ac1e-a2962a402336}\",
    \"copyOnSelect\": false,
    \"copyFormatting\": \"none\",
    \"profiles\": {
        \"defaults\": {
            \"fontFace\": \"D2Coding\",
            \"fontSize\": 12,
            \"colorScheme\": \"Campbell Powershell\",
            \"cursorShape\": \"bar\",
            \"snapOnInput\": true,
            \"useAcrylic\": true,
            \"acrylicOpacity\": 0.85,
            \"backgroundImage\": null,
            \"backgroundImageOpacity\": 0.1
        },
        \"list\": [
            {
                \"commandline\": \"pwsh.exe\",
                \"guid\": \"{574e775e-4f2a-5b96-ac1e-a2962a402336}\",
                \"hidden\": false,
                \"name\": \"PowerShell 7 🚀\",
                \"source\": \"Windows.Terminal.PowershellCore\",
                \"icon\": \"ms-appx:///ProfileIcons/{574e775e-4f2a-5b96-ac1e-a2962a402336}.png\"
            },
            {
                \"commandline\": \"powershell.exe\",
                \"guid\": \"{61c54bbd-c2c6-5271-96e7-009a87ff44bf}\",
                \"hidden\": false,
                \"name\": \"Windows PowerShell\",
                \"icon\": \"ms-appx:///ProfileIcons/{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.png\"
            },
            {
                \"commandline\": \"cmd.exe\",
                \"guid\": \"{0caa0dad-35be-5f56-a8ff-afceeeaa6101}\",
                \"hidden\": false,
                \"name\": \"명령 프롬프트\",
                \"icon\": \"ms-appx:///ProfileIcons/{0caa0dad-35be-5f56-a8ff-afceeeaa6101}.png\"
            }
        ]
    },
    \"actions\": [
        { \"command\": \"copy\", \"keys\": \"ctrl+c\" },
        { \"command\": \"paste\", \"keys\": \"ctrl+v\" },
        { \"command\": \"find\", \"keys\": \"ctrl+shift+f\" },
        { \"command\": \"newTab\", \"keys\": \"ctrl+t\" },
        { \"command\": \"closeTab\", \"keys\": \"ctrl+w\" },
        { \"command\": \"duplicateTab\", \"keys\": \"ctrl+shift+d\" }
    ]
}
'@
    Set-Content -Path `$terminalSettingsPath -Value `$advancedSettings -Encoding UTF8
    Write-Host 'Windows Terminal 고급 설정 완료'
}
"
echo 완료!

echo [7/8] 환경 변수 최종 업데이트 중...
call refreshenv >nul 2>&1
echo 완료!

echo [8/8] 설치 검증 중...
pwsh -Command "
Write-Host '=== 설치 검증 ===' -ForegroundColor Cyan
Write-Host '✅ PowerShell 7: ' -NoNewline; `$PSVersionTable.PSVersion
if (Get-Module Terminal-Icons -ListAvailable) { Write-Host '✅ Terminal-Icons: 설치됨' } else { Write-Host '❌ Terminal-Icons: 설치 안됨' }
if (Get-Module PSReadLine -ListAvailable) { Write-Host '✅ PSReadLine: 설치됨' } else { Write-Host '❌ PSReadLine: 설치 안됨' }
if (Get-Module z -ListAvailable) { Write-Host '✅ Z: 설치됨' } else { Write-Host '❌ Z: 설치 안됨' }
if (Get-Module PSFzf -ListAvailable) { Write-Host '✅ PSFzf: 설치됨' } else { Write-Host '❌ PSFzf: 설치 안됨' }
if (Get-Command starship -ErrorAction SilentlyContinue) { Write-Host '✅ Starship: 설치됨' } else { Write-Host '❌ Starship: 설치 안됨' }
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { Write-Host '✅ Oh My Posh: 설치됨' } else { Write-Host '❌ Oh My Posh: 설치 안됨' }
"
echo 완료!

echo.
echo ===============================================================
echo                    모든 설치 완료! 🎉
echo ===============================================================
echo.
echo 📦 설치된 모든 도구:
echo ✅ 시스템 인코딩: UTF-8
echo ✅ PowerShell 7 + Windows Terminal
echo ✅ 패키지 매니저: Chocolatey, Scoop  
echo ✅ 개발 도구: Git, Node.js, Python
echo ✅ 검색 도구: Fzf, Ripgrep, Fd, Bat
echo ✅ 테마: Oh My Posh, Starship
echo ✅ 모듈: Terminal-Icons, PSReadLine, Z, PSFzf
echo ✅ 폰트: D2Coding
echo ✅ 최적화된 프로필 및 설정
echo.
echo 🚀 새로운 기능들:
echo 🔍 Ctrl+F: 파일 퍼지 검색
echo 🔍 Ctrl+R: 명령어 히스토리 검색  
echo 📁 z 폴더명: 빠른 디렉토리 이동
echo 🌤️ weather: 날씨 확인
echo 🌐 Get-PublicIP: 공인 IP 확인
echo 📋 ll, la: 파일 목록 (Linux 스타일)
echo.
echo 💡 사용법:
echo 1. Windows Terminal 실행
echo 2. PowerShell 7 🚀 탭 선택
echo 3. 새로운 환경 즐기기!
echo.
pause