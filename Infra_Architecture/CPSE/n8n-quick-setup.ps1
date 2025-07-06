# n8n 서브도메인 빠른 설정 도우미

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("setup-docker", "check-status", "open-dsm", "test-subdomain")]
    [string]$Action = "help"
)

$NAS_IP = "192.168.0.5"
$NAS_USER = "crossman"
$NAS_PORT = "22022"
$N8N_SUBDOMAIN = "n8n.crossman.synology.me"

function Write-ColorLog {
    param([string]$Message, [string]$Type = "Info")
    $colors = @{"Info" = "Cyan"; "Success" = "Green"; "Warning" = "Yellow"; "Error" = "Red"}
    $prefix = @{"Info" = "[INFO]"; "Success" = "[✅]"; "Warning" = "[⚠️]"; "Error" = "[❌]"}
    Write-Host "$($prefix[$Type]) $Message" -ForegroundColor $colors[$Type]
}

function Setup-N8nDocker {
    Write-ColorLog "n8n Docker 컨테이너 설정 중..." "Info"
    
    $dockerCommands = @'
# n8n 데이터 디렉토리 생성
sudo mkdir -p /volume1/docker/n8n
sudo chown -R crossman:users /volume1/docker/n8n

# 기존 컨테이너 정리
sudo docker stop n8n 2>/dev/null || true
sudo docker rm n8n 2>/dev/null || true

# n8n 컨테이너 실행
sudo docker run -d \
  --name n8n \
  --restart unless-stopped \
  -p 5678:5678 \
  -v /volume1/docker/n8n:/home/node/.n8n \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=crossman \
  -e N8N_BASIC_AUTH_PASSWORD=changeme123 \
  -e N8N_HOST=n8n.crossman.synology.me \
  -e N8N_PORT=5678 \
  -e N8N_PROTOCOL=https \
  -e WEBHOOK_URL=https://n8n.crossman.synology.me \
  n8nio/n8n:latest

echo "잠시 대기 중... (30초)"
sleep 30

# 상태 확인
echo "=== Docker 컨테이너 상태 ==="
sudo docker ps | grep n8n

echo "=== 포트 바인딩 확인 ==="
sudo netstat -tulpn | grep :5678

echo "=== n8n 로그 (마지막 10줄) ==="
sudo docker logs --tail 10 n8n
'@

    Write-Host "SSH 비밀번호를 입력하세요..." -ForegroundColor Yellow
    ssh -p $NAS_PORT "${NAS_USER}@${NAS_IP}" $dockerCommands
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorLog "n8n Docker 설정 완료!" "Success"
    } else {
        Write-ColorLog "n8n Docker 설정 실패" "Error"
    }
}

function Check-Status {
    Write-ColorLog "n8n 서비스 상태 확인 중..." "Info"
    
    $statusCommands = @'
echo "=== n8n Docker 컨테이너 ==="
sudo docker ps | head -1
sudo docker ps | grep n8n || echo "n8n 컨테이너가 실행되지 않음"

echo ""
echo "=== 포트 5678 상태 ==="
sudo netstat -tulpn | grep :5678 || echo "포트 5678이 바인딩되지 않음"

echo ""
echo "=== n8n 컨테이너 로그 (최근 5줄) ==="
sudo docker logs --tail 5 n8n 2>/dev/null || echo "n8n 컨테이너 로그 없음"

echo ""
echo "=== 내부 접속 테스트 ==="
curl -I http://localhost:5678 2>/dev/null || echo "내부 포트 접속 실패"
'@

    ssh -p $NAS_PORT "${NAS_USER}@${NAS_IP}" $statusCommands
}

function Open-DSM {
    Write-ColorLog "DSM 웹 인터페이스 열기..." "Info"
    Write-Host ""
    Write-Host "📋 DSM 리버스 프록시 설정 단계:" -ForegroundColor Yellow
    Write-Host "1. DSM > 제어판 > 응용 프로그램 포털" -ForegroundColor White
    Write-Host "2. 리버스 프록시 탭 > 만들기" -ForegroundColor White
    Write-Host ""
    Write-Host "📝 설정 정보:" -ForegroundColor Cyan
    Write-Host "소스: HTTPS | n8n.crossman.synology.me | 443" -ForegroundColor Green
    Write-Host "대상: HTTP  | localhost                | 5678" -ForegroundColor Blue
    Write-Host ""
    
    Start-Process "http://${NAS_IP}:5000"
    Write-ColorLog "DSM 웹 인터페이스가 브라우저에서 열렸습니다." "Success"
}

function Test-Subdomain {
    Write-ColorLog "n8n 서브도메인 테스트 중..." "Info"
    
    Write-Host ""
    Write-Host "🔍 테스트 방법:" -ForegroundColor Yellow
    Write-Host "1. 브라우저 테스트: https://$N8N_SUBDOMAIN" -ForegroundColor Cyan
    Write-Host "2. 명령어 테스트: curl -I https://$N8N_SUBDOMAIN" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "💡 n8n 로그인 정보:" -ForegroundColor Yellow
    Write-Host "사용자: crossman" -ForegroundColor Green
    Write-Host "비밀번호: changeme123" -ForegroundColor Green
    Write-Host ""
    
    try {
        Write-ColorLog "DNS 확인 중..." "Info"
        $dnsResult = nslookup $N8N_SUBDOMAIN 2>$null
        if ($dnsResult) {
            Write-ColorLog "DNS 해석 성공" "Success"
        }
    }
    catch {
        Write-ColorLog "DNS 확인 실패" "Warning"
    }
    
    Write-Host "브라우저에서 서브도메인을 테스트하시겠습니까? (y/n): " -NoNewline -ForegroundColor Yellow
    $response = Read-Host
    if ($response -eq "y" -or $response -eq "Y") {
        Start-Process "https://$N8N_SUBDOMAIN"
        Write-ColorLog "브라우저에서 n8n 서브도메인이 열렸습니다." "Success"
    }
}

function Show-Help {
    Write-Host "🚀 n8n 서브도메인 빠른 설정 도우미" -ForegroundColor Yellow
    Write-Host "=================================" -ForegroundColor White
    Write-Host ""
    Write-Host "사용법: .\n8n-quick-setup.ps1 -Action <명령어>" -ForegroundColor White
    Write-Host ""
    Write-Host "명령어:" -ForegroundColor Cyan
    Write-Host "  setup-docker    NAS에 n8n Docker 컨테이너 설정" -ForegroundColor White
    Write-Host "  check-status    n8n 서비스 상태 확인" -ForegroundColor White
    Write-Host "  open-dsm        DSM 웹 인터페이스 열고 설정 가이드 표시" -ForegroundColor White
    Write-Host "  test-subdomain  n8n 서브도메인 접속 테스트" -ForegroundColor White
    Write-Host ""
    Write-Host "설정 순서:" -ForegroundColor Yellow
    Write-Host "1. .\n8n-quick-setup.ps1 -Action setup-docker" -ForegroundColor Gray
    Write-Host "2. .\n8n-quick-setup.ps1 -Action open-dsm" -ForegroundColor Gray
    Write-Host "3. DSM에서 리버스 프록시 수동 설정" -ForegroundColor Gray
    Write-Host "4. .\n8n-quick-setup.ps1 -Action test-subdomain" -ForegroundColor Gray
    Write-Host ""
}

switch ($Action) {
    "setup-docker" { Setup-N8nDocker }
    "check-status" { Check-Status }
    "open-dsm" { Open-DSM }
    "test-subdomain" { Test-Subdomain }
    default { Show-Help }
}
