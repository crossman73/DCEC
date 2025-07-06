# NAS Docker Services Deployment Script (PowerShell)
# Description: Deploy all subdomain services to Synology NAS Docker
# Version: 1.0.0

param(
    [string]$NasHost = "192.168.0.5",
    [string]$NasUser = "crossman",
    [switch]$SkipVerify = $false,
    [switch]$DryRun = $false
)

# ===========================================
# Configuration
# ===========================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogFile = "$env:TEMP\nas-docker-deploy.log"
$ComposeFile = "$ScriptDir\docker-compose.yml"
$EnvFile = "$ScriptDir\.env"

# NAS 설정
$NasDockerPath = "/volume1/dev/docker"
$NasDataPath = "/volume1/dev/data"

# ===========================================
# Logging Functions
# ===========================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        default { Write-Host $logEntry -ForegroundColor Cyan }
    }
    
    Add-Content -Path $LogFile -Value $logEntry
}

function Write-Info { param([string]$Message) Write-Log $Message "INFO" }
function Write-Success { param([string]$Message) Write-Log $Message "SUCCESS" }
function Write-Warning { param([string]$Message) Write-Log $Message "WARNING" }
function Write-Error { param([string]$Message) Write-Log $Message "ERROR" }

# ===========================================
# Network Detection
# ===========================================
function Test-NetworkConnection {
    Write-Info "네트워크 환경 감지 중..."
    
    # Ping test to NAS
    if (Test-Connection -ComputerName $NasHost -Count 1 -Quiet) {
        Write-Success "NAS 접속 가능: $NasHost"
        return $true
    } else {
        Write-Warning "NAS 직접 접속 불가, OpenVPN 연결 확인 중..."
        
        # Check VPN connection (Windows)
        $vpnRoutes = Get-NetRoute | Where-Object { $_.DestinationPrefix -like "192.168.0.0/24" }
        if ($vpnRoutes) {
            Write-Success "OpenVPN 연결됨"
            return $true
        } else {
            Write-Error "NAS 접속 및 OpenVPN 연결 실패"
            return $false
        }
    }
}

# ===========================================
# Prerequisites Check
# ===========================================
function Test-Prerequisites {
    Write-Info "사전 요구사항 확인 중..."
    
    # Check if Docker Compose file exists
    if (-not (Test-Path $ComposeFile)) {
        Write-Error "Docker Compose 파일을 찾을 수 없습니다: $ComposeFile"
        return $false
    }
    
    # Check if .env file exists
    if (-not (Test-Path $EnvFile)) {
        Write-Error "환경 설정 파일을 찾을 수 없습니다: $EnvFile"
        return $false
    }
    
    # Check if SSH is available
    if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
        Write-Error "SSH 클라이언트를 찾을 수 없습니다. OpenSSH 또는 WSL을 설치하세요."
        return $false
    }
    
    # Check if SCP is available
    if (-not (Get-Command scp -ErrorAction SilentlyContinue)) {
        Write-Error "SCP 클라이언트를 찾을 수 없습니다. OpenSSH 또는 WSL을 설치하세요."
        return $false
    }
    
    Write-Success "모든 사전 요구사항 확인 완료"
    return $true
}

# ===========================================
# Copy Files to NAS
# ===========================================
function Copy-FilesToNas {
    Write-Info "NAS로 파일 복사 중..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] 파일 복사 시뮬레이션"
        return
    }
    
    try {
        # Create directories on NAS
        $createDirCmd = @"
sudo mkdir -p $NasDockerPath
sudo mkdir -p $NasDataPath
sudo chown -R $NasUser:users $NasDockerPath
sudo chown -R $NasUser:users $NasDataPath
"@
        
        ssh -p 22022 "$NasUser@$NasHost" $createDirCmd
        
        # Copy Docker Compose file
        scp -P 22022 $ComposeFile "$NasUser@$NasHost`:$NasDockerPath/"
        
        # Copy environment file
        scp -P 22022 $EnvFile "$NasUser@$NasHost`:$NasDockerPath/.env"
        
        Write-Success "파일 복사 완료"
    }
    catch {
        Write-Error "파일 복사 중 오류 발생: $($_.Exception.Message)"
        throw
    }
}

# ===========================================
# Deploy Services
# ===========================================
function Deploy-Services {
    Write-Info "Docker 서비스 배포 중..."
    
    if ($DryRun) {
        Write-Info "[DRY RUN] 서비스 배포 시뮬레이션"
        return
    }
    
    try {
        $deployCmd = @"
cd $NasDockerPath

# Stop existing services
docker-compose down --remove-orphans || true

# Pull latest images
docker-compose pull

# Start services
docker-compose up -d

# Wait for services to start
sleep 30

# Show status
docker-compose ps
"@
        
        ssh -p 22022 "$NasUser@$NasHost" $deployCmd
        
        Write-Success "Docker 서비스 배포 완료"
    }
    catch {
        Write-Error "서비스 배포 중 오류 발생: $($_.Exception.Message)"
        throw
    }
}

# ===========================================
# Verify Services
# ===========================================
function Test-Services {
    Write-Info "서비스 상태 확인 중..."
    
    if ($SkipVerify) {
        Write-Info "서비스 확인 건너뛰기"
        return
    }
    
    $services = @{
        "n8n" = "http://$NasHost`:31001"
        "mcp-server" = "http://$NasHost`:31002/health"
        "code-server" = "http://$NasHost`:8484"
        "gitea" = "http://$NasHost`:3000"
        "uptime-kuma" = "http://$NasHost`:31003"
        "portainer" = "http://$NasHost`:9000"
    }
    
    foreach ($service in $services.GetEnumerator()) {
        $name = $service.Key
        $url = $service.Value
        
        Write-Info "확인 중: $name ($url)"
        
        try {
            $response = Invoke-WebRequest -Uri $url -Method GET -TimeoutSec 10 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($response.StatusCode -in @(200, 302, 401)) {
                Write-Success "$name 서비스 정상 동작"
            } else {
                Write-Warning "$name 서비스 응답 코드: $($response.StatusCode)"
            }
        }
        catch {
            Write-Warning "$name 서비스 응답 없음 또는 시작 중"
        }
    }
}

# ===========================================
# Generate Service URLs
# ===========================================
function New-ServiceUrls {
    Write-Info "서비스 접속 URL 생성 중..."
    
    $urlContent = @"
# NAS Docker Services URLs

## 내부 네트워크 접속 (포트 직접 접속)
- **n8n**: http://$NasHost`:31001
- **MCP Server**: http://$NasHost`:31002
- **VS Code**: http://$NasHost`:8484
- **Gitea**: http://$NasHost`:3000
- **Uptime Kuma**: http://$NasHost`:31003
- **Portainer**: http://$NasHost`:9000

## 외부 서브도메인 접속 (DSM 리버스 프록시 설정 후)
- **n8n**: https://n8n.crossman.synology.me
- **MCP Server**: https://mcp.crossman.synology.me
- **VS Code**: https://code.crossman.synology.me
- **Gitea**: https://git.crossman.synology.me
- **Uptime Kuma**: https://uptime.crossman.synology.me
- **Portainer**: https://portainer.crossman.synology.me

## 관리자 정보
- **기본 사용자명**: admin
- **기본 비밀번호**: changeme123
- **Gitea SSH 포트**: 2222

## 다음 단계
1. DSM 리버스 프록시에서 각 서비스 규칙 추가
2. SSL 인증서 설정
3. 방화벽 및 포트포워딩 설정
4. 서비스별 초기 설정 완료

생성 시간: $(Get-Date)
"@
    
    $urlFile = "$ScriptDir\service-urls.md"
    $urlContent | Out-File -FilePath $urlFile -Encoding UTF8
    
    Write-Success "서비스 URL 파일 생성: $urlFile"
}

# ===========================================
# Main Function
# ===========================================
function Main {
    Write-Info "=========================================="
    Write-Info "NAS Docker Services Deployment 시작"
    Write-Info "=========================================="
    
    try {
        if (-not (Test-NetworkConnection)) {
            throw "네트워크 연결 실패"
        }
        
        if (-not (Test-Prerequisites)) {
            throw "사전 요구사항 확인 실패"
        }
        
        Copy-FilesToNas
        Deploy-Services
        
        if (-not $DryRun) {
            Write-Info "서비스 시작 대기 중 (60초)..."
            Start-Sleep -Seconds 60
        }
        
        Test-Services
        New-ServiceUrls
        
        Write-Success "=========================================="
        Write-Success "NAS Docker Services Deployment 완료!"
        Write-Success "=========================================="
        
        Write-Info "서비스 접속 정보는 다음 파일을 확인하세요:"
        Write-Info "- $ScriptDir\service-urls.md"
        Write-Info "- 로그 파일: $LogFile"
        
        # Open service URLs file
        if (Test-Path "$ScriptDir\service-urls.md") {
            Start-Process notepad.exe "$ScriptDir\service-urls.md"
        }
    }
    catch {
        Write-Error "배포 중 오류 발생: $($_.Exception.Message)"
        exit 1
    }
}

# ===========================================
# Script Execution
# ===========================================
if ($MyInvocation.InvocationName -ne '.') {
    Main
}
