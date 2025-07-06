# DSM 자동 설정 도우미 (PowerShell)
# 시놀로지 DSM에 자동으로 접속하여 서브도메인 설정 진행

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("open", "setup", "ssl", "status", "help")]
    [string]$Action = "help"
)

# 설정 변수
$NasIP = "192.168.0.5"
$DsmHttpPort = "5000"
$DsmHttpsPort = "5001"
$DefaultBrowser = "chrome"

# 색상 출력 함수
function Write-ColorLog {
    param([string]$Message, [string]$Type = "Info")
    $colors = @{ "Info" = "Cyan"; "Success" = "Green"; "Warning" = "Yellow"; "Error" = "Red"; "Step" = "Blue" }
    $prefix = @{ "Info" = "[INFO]"; "Success" = "[SUCCESS]"; "Warning" = "[WARNING]"; "Error" = "[ERROR]"; "Step" = "[STEP]" }
    Write-Host "$($prefix[$Type]) $Message" -ForegroundColor $colors[$Type]
}

# DSM 웹 인터페이스 열기
function Open-DSMInterface {
    Write-ColorLog "DSM 웹 인터페이스 열기..." "Step"
    
    # 네트워크 연결 확인
    $pingResult = Test-Connection -ComputerName $NasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
    if (-not $pingResult) {
        Write-ColorLog "NAS 연결 실패: $NasIP" "Error"
        return
    }
    
    Write-ColorLog "NAS 연결 확인됨: $NasIP" "Success"
    
    # DSM URL들
    $httpUrl = "http://${NasIP}:${DsmHttpPort}"
    $httpsUrl = "https://${NasIP}:${DsmHttpsPort}"
    
    Write-ColorLog "DSM 웹 인터페이스를 여는 중..." "Info"
    Write-Host "HTTP URL: $httpUrl" -ForegroundColor Gray
    Write-Host "HTTPS URL: $httpsUrl" -ForegroundColor Gray
    
    # 브라우저에서 DSM 열기
    try {
        Start-Process $httpsUrl
        Write-ColorLog "HTTPS DSM 인터페이스를 기본 브라우저에서 열었습니다." "Success"
        
        # 잠시 후 HTTP도 열기 (백업용)
        Start-Sleep -Seconds 2
        Start-Process $httpUrl
        Write-ColorLog "HTTP DSM 인터페이스도 열었습니다 (백업용)." "Info"
    } catch {
        Write-ColorLog "브라우저 열기 실패: $_" "Error"
    }
    
    Write-Host ""
    Write-ColorLog "다음 단계:" "Step"
    Write-Host "1. 브라우저에서 DSM에 로그인" -ForegroundColor White
    Write-Host "2. 계정: crossman" -ForegroundColor White
    Write-Host "3. 제어판 > 응용 프로그램 포털 > 리버스 프록시로 이동" -ForegroundColor White
    Write-Host ""
}

# 서브도메인 설정 진행
function Start-SubdomainSetup {
    Write-ColorLog "🌐 서브도메인 설정 시작" "Step"
    
    # DSM 인터페이스 열기
    Open-DSMInterface
    
    Write-Host ""
    Write-ColorLog "설정할 서브도메인 목록:" "Info"
    
    $services = @(
        @{ Name = "dsm"; Domain = "dsm.crossman.synology.me"; Port = "5001"; Status = "✅ 활성화"; Description = "DSM 관리" }
        @{ Name = "n8n"; Domain = "n8n.crossman.synology.me"; Port = "5678"; Status = "❌ 대기"; Description = "워크플로우 자동화" }
        @{ Name = "mcp"; Domain = "mcp.crossman.synology.me"; Port = "31002"; Status = "❌ 대기"; Description = "MCP 서버" }
        @{ Name = "uptime"; Domain = "uptime.crossman.synology.me"; Port = "31003"; Status = "❌ 대기"; Description = "모니터링" }
        @{ Name = "code"; Domain = "code.crossman.synology.me"; Port = "8484"; Status = "❌ 대기"; Description = "VSCode 웹" }
        @{ Name = "git"; Domain = "git.crossman.synology.me"; Port = "3000"; Status = "❌ 대기"; Description = "Git 저장소" }
    )
    
    foreach ($service in $services) {
        Write-Host "$($service.Status) $($service.Domain) → :$($service.Port) ($($service.Description))" -ForegroundColor White
    }
    
    Write-Host ""
    Write-ColorLog "리버스 프록시 설정 방법:" "Step"
    Write-Host "1. DSM > 제어판 > 응용 프로그램 포털 > 리버스 프록시" -ForegroundColor Yellow
    Write-Host "2. '만들기' 버튼 클릭" -ForegroundColor Yellow
    Write-Host "3. 각 서비스별로 다음 형식으로 설정:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   소스 (Source):" -ForegroundColor Cyan
    Write-Host "   - 프로토콜: HTTPS" -ForegroundColor White
    Write-Host "   - 호스트 이름: [서브도메인]" -ForegroundColor White
    Write-Host "   - 포트: 443" -ForegroundColor White
    Write-Host ""
    Write-Host "   대상 (Destination):" -ForegroundColor Green
    Write-Host "   - 프로토콜: HTTP (DSM은 HTTPS)" -ForegroundColor White
    Write-Host "   - 호스트 이름: localhost" -ForegroundColor White
    Write-Host "   - 포트: [내부 포트]" -ForegroundColor White
    Write-Host ""
    
    # 상세 설정 가이드 열기
    $guidePrompt = Read-Host "상세 설정 가이드를 보시겠습니까? (y/N)"
    if ($guidePrompt -eq "y" -or $guidePrompt -eq "Y") {
        Show-DetailedSetupGuide
    }
}

# 상세 설정 가이드 표시
function Show-DetailedSetupGuide {
    Write-Host ""
    Write-ColorLog "📋 상세 서브도메인 설정 가이드" "Step"
    Write-Host "=====================================" -ForegroundColor White
    
    $services = @(
        @{ Name = "dsm"; Domain = "dsm.crossman.synology.me"; Port = "5001"; Protocol = "HTTPS" }
        @{ Name = "n8n"; Domain = "n8n.crossman.synology.me"; Port = "5678"; Protocol = "HTTP" }
        @{ Name = "mcp"; Domain = "mcp.crossman.synology.me"; Port = "31002"; Protocol = "HTTP" }
        @{ Name = "uptime"; Domain = "uptime.crossman.synology.me"; Port = "31003"; Protocol = "HTTP" }
        @{ Name = "code"; Domain = "code.crossman.synology.me"; Port = "8484"; Protocol = "HTTP" }
        @{ Name = "git"; Domain = "git.crossman.synology.me"; Port = "3000"; Protocol = "HTTP" }
    )
    
    foreach ($service in $services) {
        Write-Host ""
        Write-Host "🔧 $($service.Name.ToUpper()) 설정:" -ForegroundColor Cyan
        Write-Host "  소스:" -ForegroundColor Yellow
        Write-Host "    프로토콜: HTTPS" -ForegroundColor White
        Write-Host "    호스트 이름: $($service.Domain)" -ForegroundColor White
        Write-Host "    포트: 443" -ForegroundColor White
        Write-Host "  대상:" -ForegroundColor Green
        Write-Host "    프로토콜: $($service.Protocol)" -ForegroundColor White
        Write-Host "    호스트 이름: localhost" -ForegroundColor White
        Write-Host "    포트: $($service.Port)" -ForegroundColor White
        
        if ($service.Name -ne "dsm") {
            Write-Host "  고급 설정:" -ForegroundColor Magenta
            Write-Host "    WebSocket 지원: ✅ 활성화" -ForegroundColor White
        }
    }
}

# SSL 인증서 설정 가이드
function Setup-SSLCertificate {
    Write-ColorLog "🔐 SSL 인증서 설정 가이드" "Step"
    
    # 인증서 설정 URL 열기
    $certUrl = "https://${NasIP}:${DsmHttpsPort}"
    Start-Process $certUrl
    
    Write-Host ""
    Write-ColorLog "Let's Encrypt 인증서 설정 단계:" "Info"
    Write-Host "1. DSM > 제어판 > 보안 > 인증서" -ForegroundColor Yellow
    Write-Host "2. '추가' 버튼 클릭" -ForegroundColor Yellow
    Write-Host "3. 'Let's Encrypt에서 인증서 받기' 선택" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4. 도메인 설정:" -ForegroundColor Yellow
    Write-Host "   주 도메인: crossman.synology.me" -ForegroundColor White
    Write-Host ""
    Write-Host "   주제 대체 이름 (SAN):" -ForegroundColor Cyan
    Write-Host "   - dsm.crossman.synology.me" -ForegroundColor White
    Write-Host "   - n8n.crossman.synology.me" -ForegroundColor White
    Write-Host "   - mcp.crossman.synology.me" -ForegroundColor White
    Write-Host "   - uptime.crossman.synology.me" -ForegroundColor White
    Write-Host "   - code.crossman.synology.me" -ForegroundColor White
    Write-Host "   - git.crossman.synology.me" -ForegroundColor White
    Write-Host ""
    Write-Host "5. 이메일 주소 입력" -ForegroundColor Yellow
    Write-Host "6. '완료' 클릭" -ForegroundColor Yellow
    Write-Host ""
    Write-ColorLog "인증서 생성에는 몇 분이 소요될 수 있습니다." "Info"
}

# 설정 상태 확인
function Check-SetupStatus {
    Write-ColorLog "🔍 서브도메인 설정 상태 확인" "Step"
    
    # 네트워크 연결 확인
    if (Test-Connection -ComputerName $NasIP -Count 1 -Quiet -ErrorAction SilentlyContinue) {
        Write-ColorLog "NAS 연결: ✅ 성공" "Success"
    } else {
        Write-ColorLog "NAS 연결: ❌ 실패" "Error"
        return
    }
    
    # 포트 상태 확인
    $services = @(
        @{ Name = "DSM"; Port = "5001" }
        @{ Name = "n8n"; Port = "5678" }
        @{ Name = "MCP"; Port = "31002" }
        @{ Name = "Uptime"; Port = "31003" }
        @{ Name = "Code"; Port = "8484" }
        @{ Name = "Gitea"; Port = "3000" }
    )
    
    Write-Host ""
    Write-ColorLog "서비스 포트 상태:" "Info"
    foreach ($service in $services) {
        $portTest = Test-NetConnection -ComputerName $NasIP -Port $service.Port -WarningAction SilentlyContinue
        if ($portTest.TcpTestSucceeded) {
            Write-Host "  $($service.Name.PadRight(8)): ✅ 포트 $($service.Port) 활성화" -ForegroundColor Green
        } else {
            Write-Host "  $($service.Name.PadRight(8)): ❌ 포트 $($service.Port) 비활성화" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-ColorLog "다음 단계:" "Step"
    Write-Host "1. 활성화된 서비스는 리버스 프록시 설정 후 바로 테스트 가능" -ForegroundColor White
    Write-Host "2. 비활성화된 서비스는 서비스 시작 후 설정" -ForegroundColor White
    Write-Host "3. 모든 설정 완료 후 SSL 인증서 생성" -ForegroundColor White
}

# 도움말 표시
function Show-Help {
    Write-Host @"
🌐 DSM 서브도메인 설정 도우미
==============================

사용법: .\dsm-helper.ps1 -Action <명령어>

명령어:
  open     DSM 웹 인터페이스 열기
  setup    서브도메인 설정 진행
  ssl      SSL 인증서 설정 가이드
  status   설정 상태 확인
  help     이 도움말 표시

예시:
  .\dsm-helper.ps1 -Action open
  .\dsm-helper.ps1 -Action setup
  .\dsm-helper.ps1 -Action ssl
  .\dsm-helper.ps1 -Action status

설정할 서브도메인:
  dsm.crossman.synology.me (DSM 관리)
  n8n.crossman.synology.me (워크플로우 자동화)
  mcp.crossman.synology.me (MCP 서버)
  uptime.crossman.synology.me (모니터링)
  code.crossman.synology.me (VSCode 웹)
  git.crossman.synology.me (Git 저장소)

"@ -ForegroundColor White
}

# 메인 실행 로직
switch ($Action) {
    "open" {
        Open-DSMInterface
    }
    "setup" {
        Start-SubdomainSetup
    }
    "ssl" {
        Setup-SSLCertificate
    }
    "status" {
        Check-SetupStatus
    }
    "help" {
        Show-Help
    }
    default {
        Write-ColorLog "알 수 없는 명령어: $Action" "Error"
        Show-Help
    }
}
