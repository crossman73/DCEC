# NAS Docker 파일 전송 및 배포 스크립트
# PowerShell 7+ 권장

param(
    [string]$NasHost = "192.168.0.5",
    [string]$NasUser = "crossman",
    [int]$SshPort = 22022,
    [switch]$SetupOnly = $false,
    [switch]$DeployOnly = $false
)

# 색상 정의
$Colors = @{
    Info = "Cyan"
    Success = "Green" 
    Warning = "Yellow"
    Error = "Red"
}

function Write-ColorLog {
    param([string]$Message, [string]$Level = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] " -NoNewline
    Write-Host $Message -ForegroundColor $Colors[$Level]
}

function Test-SshConnection {
    Write-ColorLog "NAS SSH 연결 테스트 중..." "Info"
    
    try {
        $result = ssh -p $SshPort -o ConnectTimeout=10 "$NasUser@$NasHost" "echo 'SSH 연결 성공'"
        if ($result -eq "SSH 연결 성공") {
            Write-ColorLog "✅ SSH 연결 성공" "Success"
            return $true
        }
    }
    catch {
        Write-ColorLog "❌ SSH 연결 실패: $($_.Exception.Message)" "Error"
        return $false
    }
    
    return $false
}

function Copy-FilesToNas {
    Write-ColorLog "NAS로 파일 복사 중..." "Info"
    
    $filesToCopy = @(
        @{Local="docker-compose.yml"; Remote="/tmp/docker-compose.yml"}
        @{Local=".env"; Remote="/tmp/nas-docker.env"}
        @{Local="setup-nas-docker-env.sh"; Remote="/tmp/setup-nas-docker-env.sh"}
    )
    
    foreach ($file in $filesToCopy) {
        if (Test-Path $file.Local) {
            Write-ColorLog "복사 중: $($file.Local) → $($file.Remote)" "Info"
            scp -P $SshPort $file.Local "$NasUser@${NasHost}:$($file.Remote)"
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColorLog "✅ $($file.Local) 복사 완료" "Success"
            } else {
                Write-ColorLog "❌ $($file.Local) 복사 실패" "Error"
                return $false
            }
        } else {
            Write-ColorLog "⚠️ 파일을 찾을 수 없음: $($file.Local)" "Warning"
        }
    }
    
    return $true
}

function Invoke-NasSetup {
    Write-ColorLog "NAS Docker 환경 설정 중..." "Info"
    
    $setupCommands = @"
# 스크립트 실행 권한 부여
chmod +x /tmp/setup-nas-docker-env.sh

# 환경 설정 스크립트 실행
/tmp/setup-nas-docker-env.sh

# 파일 이동
sudo mv /tmp/docker-compose.yml /volume1/dev/docker/docker-compose.yml
sudo mv /tmp/nas-docker.env /volume1/dev/docker/.env

# 권한 설정
sudo chown crossman:users /volume1/dev/docker/docker-compose.yml
sudo chown crossman:users /volume1/dev/docker/.env

echo "✅ NAS 환경 설정 완료"
"@
    
    try {
        ssh -p $SshPort "$NasUser@$NasHost" $setupCommands
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorLog "✅ NAS 환경 설정 완료" "Success"
            return $true
        } else {
            Write-ColorLog "❌ NAS 환경 설정 실패" "Error"
            return $false
        }
    }
    catch {
        Write-ColorLog "❌ NAS 환경 설정 중 오류: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Start-DockerServices {
    Write-ColorLog "Docker 서비스 배포 중..." "Info"
    
    $deployCommands = @"
cd /volume1/dev/docker

# Docker 네트워크 생성 (이미 있으면 무시)
docker network create nas-services-network 2>/dev/null || true

# 서비스 배포 (단계별)
echo "1단계: PostgreSQL 시작"
docker-compose up -d postgres

echo "PostgreSQL 시작 대기 중..."
sleep 30

echo "2단계: 핵심 서비스 시작 (n8n, Gitea)"
docker-compose up -d n8n gitea

echo "핵심 서비스 시작 대기 중..."
sleep 30

echo "3단계: 관리 도구 시작 (Portainer, Uptime Kuma)"
docker-compose up -d portainer uptime-kuma

echo "4단계: 개발 도구 시작 (Code-Server, MCP-Server)"
docker-compose up -d code-server mcp-server

echo "5단계: 유지보수 도구 시작 (Watchtower)"
docker-compose up -d watchtower

echo "✅ 모든 서비스 배포 완료"

# 상태 확인
echo ""
echo "📋 서비스 상태:"
docker-compose ps

echo ""
echo "🌐 네트워크 정보:"
docker network ls | grep nas-services

echo ""
echo "💾 볼륨 정보:"
docker volume ls | grep nas-services
"@
    
    try {
        ssh -p $SshPort "$NasUser@$NasHost" $deployCommands
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorLog "✅ Docker 서비스 배포 완료" "Success"
            return $true
        } else {
            Write-ColorLog "❌ Docker 서비스 배포 실패" "Error"
            return $false
        }
    }
    catch {
        Write-ColorLog "❌ Docker 서비스 배포 중 오류: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-Services {
    Write-ColorLog "서비스 상태 확인 중..." "Info"
    
    $checkCommands = @"
cd /volume1/dev/docker

echo "🏥 서비스 헬스체크"
echo "==================="

# 헬스체크 스크립트 실행
if [ -f scripts/health-check.sh ]; then
    ./scripts/health-check.sh
else
    echo "헬스체크 스크립트를 찾을 수 없습니다. 기본 확인을 실행합니다."
    docker-compose ps
fi
"@
    
    try {
        ssh -p $SshPort "$NasUser@$NasHost" $checkCommands
        Write-ColorLog "✅ 서비스 상태 확인 완료" "Success"
    }
    catch {
        Write-ColorLog "❌ 서비스 상태 확인 실패: $($_.Exception.Message)" "Error"
    }
}

function Show-ServiceUrls {
    Write-ColorLog "서비스 접속 정보" "Info"
    
    $urls = @"

🌐 NAS Docker 서비스 접속 정보
=====================================

## 내부 네트워크 접속 (직접 포트)
- 🔄 n8n:           http://$NasHost`:31001
- 🔧 MCP Server:    http://$NasHost`:31002  
- 📊 Uptime Kuma:   http://$NasHost`:31003
- 💻 VS Code:       http://$NasHost`:8484
- 🐙 Gitea:         http://$NasHost`:3000
- 🐳 Portainer:     http://$NasHost`:9000

## 외부 서브도메인 접속 (DSM 리버스 프록시 설정 후)
- 🔄 n8n:           https://n8n.crossman.synology.me
- 🔧 MCP Server:    https://mcp.crossman.synology.me
- 📊 Uptime Kuma:   https://uptime.crossman.synology.me  
- 💻 VS Code:       https://code.crossman.synology.me
- 🐙 Gitea:         https://git.crossman.synology.me
- 🐳 Portainer:     https://portainer.crossman.synology.me

## 기본 로그인 정보
- 사용자명: admin
- 비밀번호: .env 파일에서 확인

## 다음 단계
1. DSM 리버스 프록시 설정
2. SSL 인증서 적용
3. 방화벽 및 포트포워딩 설정
4. 서비스별 초기 설정 완료

"@
    
    Write-Host $urls -ForegroundColor Green
    
    # 서비스 URL 파일로 저장
    $urls | Out-File -FilePath "nas-service-urls.txt" -Encoding UTF8
    Write-ColorLog "✅ 서비스 정보를 'nas-service-urls.txt' 파일로 저장했습니다." "Success"
}

function Main {
    Write-ColorLog "=========================================" "Info"
    Write-ColorLog "NAS Docker 서비스 자동 배포 시작" "Info"
    Write-ColorLog "=========================================" "Info"
    
    # SSH 연결 테스트
    if (-not (Test-SshConnection)) {
        Write-ColorLog "SSH 연결 실패. 다음을 확인하세요:" "Error"
        Write-ColorLog "1. NAS IP 주소: $NasHost" "Error"
        Write-ColorLog "2. SSH 포트: $SshPort" "Error"
        Write-ColorLog "3. 사용자명: $NasUser" "Error"
        Write-ColorLog "4. SSH 키 또는 비밀번호 설정" "Error"
        exit 1
    }
    
    # 파일 복사
    if (-not $DeployOnly) {
        if (-not (Copy-FilesToNas)) {
            Write-ColorLog "파일 복사 실패" "Error"
            exit 1
        }
        
        # NAS 환경 설정
        if (-not (Invoke-NasSetup)) {
            Write-ColorLog "NAS 환경 설정 실패" "Error"
            exit 1
        }
    }
    
    # Docker 서비스 배포
    if (-not $SetupOnly) {
        Write-ColorLog "Docker 서비스 시작 대기 중..." "Info"
        Start-Sleep -Seconds 10
        
        if (-not (Start-DockerServices)) {
            Write-ColorLog "Docker 서비스 배포 실패" "Error"
            exit 1
        }
        
        # 서비스 시작 대기
        Write-ColorLog "서비스 완전 시작 대기 중 (60초)..." "Info"
        Start-Sleep -Seconds 60
        
        # 서비스 상태 확인
        Test-Services
    }
    
    Write-ColorLog "=========================================" "Success"
    Write-ColorLog "NAS Docker 서비스 배포 완료!" "Success"
    Write-ColorLog "=========================================" "Success"
    
    Show-ServiceUrls
    
    Write-ColorLog "추가 관리 명령어:" "Info"
    Write-ColorLog "- 서비스 상태: ssh -p $SshPort $NasUser@$NasHost '/volume1/dev/docker/scripts/health-check.sh'" "Info"
    Write-ColorLog "- 서비스 재시작: ssh -p $SshPort $NasUser@$NasHost '/volume1/dev/docker/scripts/restart-services.sh'" "Info"
    Write-ColorLog "- 백업 생성: ssh -p $SshPort $NasUser@$NasHost '/volume1/dev/docker/scripts/backup-services.sh'" "Info"
}

# 스크립트 실행
try {
    Main
}
catch {
    Write-ColorLog "스크립트 실행 중 예상치 못한 오류: $($_.Exception.Message)" "Error"
    exit 1
}
