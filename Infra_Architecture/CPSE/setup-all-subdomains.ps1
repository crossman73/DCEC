# 시놀로지 NAS 모든 서비스 서브도메인 설정 가이드 (PowerShell)
# DSM 리버스 프록시를 통한 crossman.synology.me 서브도메인 생성

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "setup", "ssl", "firewall", "verify", "list", "help")]
    [string]$Action = "help",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("n8n", "mcp", "uptime", "code", "gitea", "dsm")]
    [string]$Service
)

# 서비스 정보 해시테이블
$Services = @{
    "n8n" = @{
        "subdomain" = "n8n.crossman.synology.me"
        "external_port" = "31001"
        "internal_port" = "5678"
        "description" = "워크플로우 자동화"
    }
    "mcp" = @{
        "subdomain" = "mcp.crossman.synology.me"
        "external_port" = "31002"
        "internal_port" = "31002"
        "description" = "모델 컨텍스트 프로토콜"
    }
    "uptime" = @{
        "subdomain" = "uptime.crossman.synology.me"
        "external_port" = "31003"
        "internal_port" = "31003"
        "description" = "모니터링 시스템"
    }
    "code" = @{
        "subdomain" = "code.crossman.synology.me"
        "external_port" = "8484"
        "internal_port" = "8484"
        "description" = "VSCode 웹 환경"
    }
    "gitea" = @{
        "subdomain" = "git.crossman.synology.me"
        "external_port" = "3000"
        "internal_port" = "3000"
        "description" = "Git 저장소"
    }
    "dsm" = @{
        "subdomain" = "dsm.crossman.synology.me"
        "external_port" = "5001"
        "internal_port" = "5001"
        "description" = "DSM 관리 인터페이스"
    }
}

# 색상 로그 함수
function Write-ColorLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Step", "Header")]
        [string]$Type = "Info"
    )
    
    $colors = @{
        "Info" = "Cyan"
        "Success" = "Green"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Step" = "Blue"
        "Header" = "Magenta"
    }
    
    $prefix = @{
        "Info" = "[INFO]"
        "Success" = "[SUCCESS]"
        "Warning" = "[WARNING]"
        "Error" = "[ERROR]"
        "Step" = "[STEP]"
        "Header" = "[HEADER]"
    }
    
    Write-Host "$($prefix[$Type]) $Message" -ForegroundColor $colors[$Type]
}

# 네트워크 연결 확인
function Test-NetworkConnection {
    Write-ColorLog "네트워크 연결 확인 중..." "Step"
    
    # NAS 연결 테스트
    $pingResult = Test-Connection -ComputerName "192.168.0.5" -Count 1 -Quiet -ErrorAction SilentlyContinue
    
    if ($pingResult) {
        Write-ColorLog "NAS 연결 성공: 192.168.0.5" "Success"
        return $true
    } else {
        Write-ColorLog "NAS 연결 실패. 네트워크 설정을 확인하세요." "Error"
        return $false
    }
}

# 단일 서비스 설정 가이드
function Set-SingleServiceSubdomain {
    param([string]$ServiceName)
    
    if (-not $Services.ContainsKey($ServiceName)) {
        Write-ColorLog "알 수 없는 서비스: $ServiceName" "Error"
        return
    }
    
    $serviceInfo = $Services[$ServiceName]
    
    Write-ColorLog "🌐 $ServiceName 서브도메인 설정" "Header"
    Write-Host "=======================================" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 서비스 정보:" -ForegroundColor White
    Write-Host "   서브도메인: $($serviceInfo.subdomain)" -ForegroundColor White
    Write-Host "   설명: $($serviceInfo.description)" -ForegroundColor White
    Write-Host "   외부 포트: $($serviceInfo.external_port)" -ForegroundColor White
    Write-Host "   내부 포트: $($serviceInfo.internal_port)" -ForegroundColor White
    Write-Host ""
    
    Write-ColorLog "DSM 리버스 프록시 설정 단계:" "Step"
    Write-Host ""
    Write-Host "1️⃣  DSM 웹 인터페이스 접속" -ForegroundColor Yellow
    Write-Host "   URL: http://192.168.0.5:5000 또는 https://192.168.0.5:5001" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2️⃣  제어판 > 응용 프로그램 포털 이동" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "3️⃣  '리버스 프록시' 탭 클릭" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4️⃣  '만들기' 버튼 클릭" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "5️⃣  리버스 프록시 규칙 입력:" -ForegroundColor Yellow
    Write-Host "   ┌─ 소스 설정 ─────────────────────┐" -ForegroundColor Cyan
    Write-Host "   │ 프로토콜: HTTPS                  │" -ForegroundColor Cyan
    Write-Host "   │ 호스트 이름: $($serviceInfo.subdomain)   │" -ForegroundColor Cyan
    Write-Host "   │ 포트: 443                        │" -ForegroundColor Cyan
    Write-Host "   └─────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   ┌─ 대상 설정 ─────────────────────┐" -ForegroundColor Green
    Write-Host "   │ 프로토콜: HTTP                   │" -ForegroundColor Green
    Write-Host "   │ 호스트 이름: localhost           │" -ForegroundColor Green
    Write-Host "   │ 포트: $($serviceInfo.internal_port)                  │" -ForegroundColor Green
    Write-Host "   └─────────────────────────────────┘" -ForegroundColor Green
    Write-Host ""
    Write-Host "6️⃣  고급 설정 (선택사항):" -ForegroundColor Yellow
    Write-Host "   - WebSocket 지원 활성화 (필요한 경우)" -ForegroundColor Gray
    Write-Host "   - 사용자 정의 헤더 추가 (필요한 경우)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "7️⃣  '저장' 클릭" -ForegroundColor Yellow
    Write-Host ""
    
    Write-ColorLog "설정 완료 후 접속 테스트:" "Success"
    Write-Host "   URL: https://$($serviceInfo.subdomain)" -ForegroundColor Green
    Write-Host "   내부 테스트: http://192.168.0.5:$($serviceInfo.internal_port)" -ForegroundColor Green
    Write-Host ""
    
    # 포트 확인
    Write-ColorLog "현재 포트 상태 확인 중..." "Step"
    $portTest = Test-NetConnection -ComputerName "192.168.0.5" -Port $serviceInfo.internal_port -WarningAction SilentlyContinue
    
    if ($portTest.TcpTestSucceeded) {
        Write-ColorLog "포트 $($serviceInfo.internal_port): 활성화됨" "Success"
    } else {
        Write-ColorLog "포트 $($serviceInfo.internal_port): 비활성화됨 (서비스가 실행되지 않음)" "Warning"
        Write-Host "         서비스를 먼저 시작해주세요." -ForegroundColor Yellow
    }
    
    Write-Host ""
    Read-Host "다음 서비스 설정으로 계속하시겠습니까? (Enter 키를 눌러주세요)"
}

# 모든 서비스 설정 가이드
function Set-AllServicesSubdomain {
    Write-ColorLog "🚀 모든 서비스 서브도메인 설정" "Header"
    Write-Host "=========================================" -ForegroundColor White
    Write-Host ""
    
    Write-ColorLog "설정할 서비스 목록:" "Info"
    foreach ($service in $Services.Keys) {
        $serviceInfo = $Services[$service]
        Write-Host "   $($service.PadRight(8)) $($serviceInfo.subdomain) ($($serviceInfo.description))" -ForegroundColor White
    }
    Write-Host ""
    
    $response = Read-Host "모든 서비스 설정을 시작하시겠습니까? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-ColorLog "설정이 취소되었습니다." "Warning"
        return
    }
    
    # 각 서비스별 설정
    foreach ($service in $Services.Keys) {
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
        Set-SingleServiceSubdomain -ServiceName $service
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    }
    
    Write-ColorLog "🎉 모든 서비스 설정 완료!" "Header"
    Write-Host ""
    Write-ColorLog "설정된 서브도메인 목록:" "Info"
    foreach ($service in $Services.Keys) {
        $serviceInfo = $Services[$service]
        Write-Host "   ✅ https://$($serviceInfo.subdomain) ($($serviceInfo.description))" -ForegroundColor Green
    }
}

# SSL 인증서 설정 가이드
function Set-SSLCertificates {
    Write-ColorLog "🔐 SSL 인증서 설정" "Header"
    Write-Host "=========================" -ForegroundColor White
    Write-Host ""
    
    Write-ColorLog "Let's Encrypt 인증서 설정:" "Step"
    Write-Host ""
    Write-Host "1️⃣  DSM > 제어판 > 보안 > 인증서" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "2️⃣  '추가' 버튼 클릭" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "3️⃣  'Let's Encrypt에서 인증서 받기' 선택" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "4️⃣  도메인 정보 입력:" -ForegroundColor Yellow
    Write-Host "   ┌─ 주 도메인 ─────────────────────┐" -ForegroundColor Cyan
    Write-Host "   │ crossman.synology.me             │" -ForegroundColor Cyan
    Write-Host "   └─────────────────────────────────┘" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   ┌─ 주제 대체 이름 (SAN) ──────────┐" -ForegroundColor Green
    foreach ($service in $Services.Keys) {
        $serviceInfo = $Services[$service]
        Write-Host "   │ $($serviceInfo.subdomain.PadRight(32)) │" -ForegroundColor Green
    }
    Write-Host "   └─────────────────────────────────┘" -ForegroundColor Green
    Write-Host ""
    Write-Host "5️⃣  이메일 주소 입력" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "6️⃣  '완료' 클릭" -ForegroundColor Yellow
    Write-Host ""
    
    Write-ColorLog "인증서가 생성되면 자동으로 서브도메인에 적용됩니다." "Success"
    Write-Host ""
}

# 방화벽 설정 가이드
function Set-FirewallRules {
    Write-ColorLog "🛡️ 방화벽 설정 확인" "Header"
    Write-Host "========================" -ForegroundColor White
    Write-Host ""
    
    Write-ColorLog "DSM 방화벽 규칙 확인:" "Step"
    Write-Host ""
    Write-Host "1️⃣  DSM > 제어판 > 보안 > 방화벽" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "2️⃣  다음 포트가 허용되어 있는지 확인:" -ForegroundColor Yellow
    Write-Host ""
    foreach ($service in $Services.Keys) {
        $serviceInfo = $Services[$service]
        Write-Host "   $($service.PadRight(8)) $($serviceInfo.external_port) → $($serviceInfo.internal_port) ($($serviceInfo.description))" -ForegroundColor White
    }
    Write-Host "   HTTP     80  (리다이렉션용)" -ForegroundColor White
    Write-Host "   HTTPS    443 (SSL 접속용)" -ForegroundColor White
    Write-Host ""
    
    Write-ColorLog "라우터 포트 포워딩 확인:" "Step"
    Write-Host ""
    Write-Host "3️⃣  ASUS RT-AX88U 라우터 설정 확인" -ForegroundColor Yellow
    Write-Host "   URL: http://192.168.0.1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "4️⃣  고급 설정 > WAN > 가상 서버 / 포트 포워딩" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "5️⃣  다음 규칙이 설정되어 있는지 확인:" -ForegroundColor Yellow
    foreach ($service in $Services.Keys) {
        $serviceInfo = $Services[$service]
        Write-Host "   외부 포트 $($serviceInfo.external_port) → 192.168.0.5:$($serviceInfo.internal_port) ($service)" -ForegroundColor White
    }
    Write-Host ""
}

# 설정 검증
function Test-SubdomainSetup {
    Write-ColorLog "🔍 서브도메인 설정 검증" "Header"
    Write-Host "==========================" -ForegroundColor White
    Write-Host ""
    
    foreach ($service in $Services.Keys) {
        $serviceInfo = $Services[$service]
        
        Write-Host "🔗 $service ($($serviceInfo.description))" -ForegroundColor Cyan
        Write-Host "   서브도메인: https://$($serviceInfo.subdomain)" -ForegroundColor White
        Write-Host "   내부 테스트: http://192.168.0.5:$($serviceInfo.internal_port)" -ForegroundColor White
        
        # 포트 연결 테스트
        $portTest = Test-NetConnection -ComputerName "192.168.0.5" -Port $serviceInfo.internal_port -WarningAction SilentlyContinue
        
        if ($portTest.TcpTestSucceeded) {
            Write-Host "   상태: ✅ 포트 활성화" -ForegroundColor Green
        } else {
            Write-Host "   상태: ❌ 포트 비활성화" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    Write-ColorLog "외부 접속 테스트:" "Info"
    Write-Host "   1. 모바일 데이터 또는 외부 네트워크에서 접속" -ForegroundColor Gray
    Write-Host "   2. 각 서브도메인 URL로 접속 확인" -ForegroundColor Gray
    Write-Host "   3. SSL 인증서 정상 작동 확인" -ForegroundColor Gray
    Write-Host ""
}

# 서비스 목록 표시
function Show-ServiceList {
    Write-ColorLog "🌐 지원 서비스 목록" "Header"
    Write-Host "===================" -ForegroundColor White
    Write-Host ""
    Write-Host $("{0,-8} {1,-35} {2,-15} {3}" -f "서비스", "서브도메인", "포트", "설명") -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    
    foreach ($service in $Services.Keys) {
        $serviceInfo = $Services[$service]
        $portMapping = "$($serviceInfo.external_port)→$($serviceInfo.internal_port)"
        Write-Host $("{0,-8} {1,-35} {2,-15} {3}" -f $service, $serviceInfo.subdomain, $portMapping, $serviceInfo.description) -ForegroundColor White
    }
    Write-Host ""
}

# 도움말 표시
function Show-Help {
    Write-Host @"
🌐 시놀로지 NAS 서브도메인 설정 도구 (PowerShell)
==================================================

사용법: .\setup-all-subdomains.ps1 -Action <명령어> [-Service <서비스명>]

명령어:
  all                     모든 서비스 서브도메인 설정 가이드
  setup                   특정 서비스 설정 가이드 (-Service 필수)
  ssl                     SSL 인증서 설정 가이드  
  firewall                방화벽 설정 확인 가이드
  verify                  설정 검증 및 테스트
  list                    지원 서비스 목록 표시
  help                    이 도움말 표시

지원 서비스:
  n8n      n8n.crossman.synology.me (워크플로우 자동화)
  mcp      mcp.crossman.synology.me (모델 컨텍스트 프로토콜)
  uptime   uptime.crossman.synology.me (모니터링 시스템)
  code     code.crossman.synology.me (VSCode 웹 환경)
  gitea    git.crossman.synology.me (Git 저장소)
  dsm      dsm.crossman.synology.me (DSM 관리 인터페이스)

예시:
  .\setup-all-subdomains.ps1 -Action all
  .\setup-all-subdomains.ps1 -Action setup -Service n8n
  .\setup-all-subdomains.ps1 -Action ssl
  .\setup-all-subdomains.ps1 -Action verify

"@ -ForegroundColor White
}

# 메인 실행 로직
switch ($Action) {
    "all" {
        if (Test-NetworkConnection) {
            Set-AllServicesSubdomain
        }
    }
    "setup" {
        if ($Service) {
            if (Test-NetworkConnection) {
                Set-SingleServiceSubdomain -ServiceName $Service
            }
        } else {
            Write-ColorLog "서비스명을 지정하세요. 예: -Action setup -Service n8n" "Error"
            Show-Help
        }
    }
    "ssl" {
        Set-SSLCertificates
    }
    "firewall" {
        Set-FirewallRules
    }
    "verify" {
        if (Test-NetworkConnection) {
            Test-SubdomainSetup
        }
    }
    "list" {
        Show-ServiceList
    }
    "help" {
        Show-Help
    }
    default {
        Write-ColorLog "알 수 없는 명령어: $Action" "Error"
        Show-Help
    }
}
