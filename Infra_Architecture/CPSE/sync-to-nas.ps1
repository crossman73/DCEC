# 로컬 ↔ NAS 동기화 스크립트 (PowerShell)
# VSCode 작업 → NAS 배포 자동화

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("sync", "git", "docker", "status", "help")]
    [string]$Action = "help",
    
    [Parameter(Mandatory=$false)]
    [string]$Message = "Auto sync from local to NAS",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# 설정 변수
$LocalPath = "D:\Dev\DCEC\Infra_Architecture\CPSE"
$NasHost = "crossman@192.168.0.5"
$NasPath = "/volume1/dev/CPSE"
$NasPort = "22022"
$GitRepo = "https://github.com/crossman73/DCEC.git"

# 색상 출력 함수
function Write-ColorLog {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    $colors = @{
        "Info" = "Cyan"
        "Success" = "Green" 
        "Warning" = "Yellow"
        "Error" = "Red"
    }
    
    $prefix = @{
        "Info" = "[INFO]"
        "Success" = "[SUCCESS]"
        "Warning" = "[WARNING]"
        "Error" = "[ERROR]"
    }
    
    Write-Host "$($prefix[$Type]) $Message" -ForegroundColor $colors[$Type]
}

# 네트워크 연결 확인
function Test-NasConnection {
    Write-ColorLog "NAS 연결 상태 확인 중..." "Info"
    
    # SSH 연결 테스트
    $testResult = ssh -p $NasPort -o ConnectTimeout=5 $NasHost "echo 'SSH 연결 성공'" 2>$null
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorLog "NAS SSH 연결 성공: $NasHost" "Success"
        return $true
    } else {
        Write-ColorLog "NAS SSH 연결 실패. OpenVPN 연결 또는 인증 정보를 확인하세요." "Error"
        return $false
    }
}

# 로컬 Git 상태 확인
function Get-GitStatus {
    Write-ColorLog "Git 상태 확인 중..." "Info"
    
    Push-Location $LocalPath
    
    # Git 상태 확인
    $gitStatus = git status --porcelain
    $hasChanges = $gitStatus.Count -gt 0
    
    if ($hasChanges) {
        Write-ColorLog "Git 작업 디렉토리에 변경사항이 있습니다:" "Warning"
        git status --short
        return $false
    } else {
        Write-ColorLog "Git 작업 디렉토리가 깨끗합니다." "Success"
        return $true
    }
    
    Pop-Location
}

# Git 커밋 및 푸시
function Sync-GitChanges {
    param([string]$CommitMessage)
    
    Write-ColorLog "Git 동기화 시작..." "Info"
    
    Push-Location $LocalPath
    
    try {
        # 변경사항 스테이징
        git add .
        Write-ColorLog "변경사항 스테이징 완료" "Success"
        
        # 커밋
        git commit -m $CommitMessage
        if ($LASTEXITCODE -eq 0) {
            Write-ColorLog "커밋 완료: $CommitMessage" "Success"
        } else {
            Write-ColorLog "커밋할 변경사항이 없습니다." "Info"
        }
        
        # 푸시
        git push origin master
        if ($LASTEXITCODE -eq 0) {
            Write-ColorLog "GitHub 푸시 완료" "Success"
            return $true
        } else {
            Write-ColorLog "GitHub 푸시 실패" "Error"
            return $false
        }
    }
    catch {
        Write-ColorLog "Git 동기화 중 오류 발생: $_" "Error"
        return $false
    }
    finally {
        Pop-Location
    }
}

# NAS에 직접 동기화 (SCP)
function Sync-ToNasDirectly {
    Write-ColorLog "NAS로 직접 동기화 시작..." "Info"
    
    # NAS에서 디렉토리 생성
    ssh -p $NasPort $NasHost "mkdir -p $NasPath"
    
    # SCP로 파일 복사
    Write-ColorLog "파일 전송 중..." "Info"
    scp -P $NasPort -r "$LocalPath\*" "${NasHost}:${NasPath}/"
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorLog "NAS 동기화 완료" "Success"
        return $true
    } else {
        Write-ColorLog "NAS 동기화 실패" "Error"
        return $false
    }
}

# NAS에서 Git Pull
function Sync-NasFromGit {
    Write-ColorLog "NAS에서 Git Pull 실행..." "Info"
    
    # NAS에서 Git 저장소 확인 및 동기화
    $nasCommands = @"
# Git 저장소 확인
if [ ! -d "$NasPath/.git" ]; then
    echo "Git 저장소 초기화 중..."
    mkdir -p $NasPath
    cd $NasPath
    git clone $GitRepo .
else
    echo "기존 Git 저장소에서 Pull 실행..."
    cd $NasPath
    git pull origin master
fi

# 권한 설정
chmod +x *.sh
echo "NAS Git 동기화 완료"
"@

    ssh -p $NasPort $NasHost $nasCommands
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorLog "NAS Git 동기화 완료" "Success"
        return $true
    } else {
        Write-ColorLog "NAS Git 동기화 실패" "Error"
        return $false
    }
}

# Docker 컨테이너 재시작
function Restart-NasDockerServices {
    Write-ColorLog "NAS Docker 서비스 재시작..." "Info"
    
    $dockerCommands = @"
cd $NasPath

# Docker Compose 실행
if [ -f "docker-compose.yml" ]; then
    echo "Docker Compose 재시작 중..."
    docker-compose down
    docker-compose up -d
    
    echo "컨테이너 상태 확인..."
    docker-compose ps
else
    echo "docker-compose.yml 파일이 없습니다."
fi

# 개별 서비스 상태 확인
echo "서비스 포트 확인..."
ss -tlnp | grep -E "(5678|31002|31003|8484|3000|5001)"
"@

    ssh -p $NasPort $NasHost $dockerCommands
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorLog "Docker 서비스 재시작 완료" "Success"
        return $true
    } else {
        Write-ColorLog "Docker 서비스 재시작 실패" "Error"
        return $false
    }
}

# 동기화 상태 확인
function Get-SyncStatus {
    Write-ColorLog "동기화 상태 확인 중..." "Info"
    
    # 로컬 Git 상태
    Write-ColorLog "=== 로컬 Git 상태 ===" "Info"
    Push-Location $LocalPath
    git status --short
    $localCommit = git rev-parse HEAD
    Write-ColorLog "로컬 커밋: $($localCommit.Substring(0,8))" "Info"
    Pop-Location
    
    # NAS 연결 가능한 경우 NAS 상태 확인
    if (Test-NasConnection) {
        Write-ColorLog "=== NAS 상태 ===" "Info"
        
        $nasStatus = ssh -p $NasPort $NasHost @"
cd $NasPath 2>/dev/null || { echo "NAS 디렉토리가 존재하지 않습니다."; exit 1; }

echo "NAS 디렉토리 내용:"
ls -la

if [ -d ".git" ]; then
    echo "NAS Git 커밋: \$(git rev-parse HEAD | cut -c1-8)"
    echo "NAS Git 상태:"
    git status --short
else
    echo "NAS에 Git 저장소가 없습니다."
fi

echo "Docker 컨테이너 상태:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
"@
        
        Write-Output $nasStatus
    }
}

# 완전 동기화 워크플로우
function Start-FullSync {
    param([string]$CommitMessage, [bool]$ForceSync = $false)
    
    Write-ColorLog "🔄 전체 동기화 워크플로우 시작" "Info"
    Write-ColorLog "=================================" "Info"
    
    # 1. 네트워크 연결 확인
    if (-not (Test-NasConnection)) {
        Write-ColorLog "NAS 연결 실패. 동기화를 중단합니다." "Error"
        return $false
    }
    
    # 2. Git 상태 확인
    if (-not $ForceSync -and -not (Get-GitStatus)) {
        $response = Read-Host "변경사항이 있습니다. 계속하시겠습니까? (y/N)"
        if ($response -ne "y" -and $response -ne "Y") {
            Write-ColorLog "동기화가 취소되었습니다." "Warning"
            return $false
        }
    }
    
    # 3. Git 커밋 및 푸시
    if (Sync-GitChanges -CommitMessage $CommitMessage) {
        Write-ColorLog "✅ 1단계: Git 동기화 완료" "Success"
    } else {
        Write-ColorLog "❌ 1단계: Git 동기화 실패" "Error"
        return $false
    }
    
    # 4. NAS에서 Git Pull
    if (Sync-NasFromGit) {
        Write-ColorLog "✅ 2단계: NAS Git 동기화 완료" "Success"
    } else {
        Write-ColorLog "❌ 2단계: NAS Git 동기화 실패" "Error"
        Write-ColorLog "직접 동기화로 전환합니다..." "Warning"
        
        if (Sync-ToNasDirectly) {
            Write-ColorLog "✅ 2단계(대체): 직접 동기화 완료" "Success"
        } else {
            Write-ColorLog "❌ 2단계(대체): 직접 동기화 실패" "Error"
            return $false
        }
    }
    
    # 5. Docker 서비스 재시작
    if (Restart-NasDockerServices) {
        Write-ColorLog "✅ 3단계: Docker 서비스 재시작 완료" "Success"
    } else {
        Write-ColorLog "❌ 3단계: Docker 서비스 재시작 실패" "Error"
    }
    
    Write-ColorLog "🎉 전체 동기화 완료!" "Success"
    return $true
}

# 도움말 표시
function Show-Help {
    Write-Host @"
🔄 로컬 ↔ NAS 동기화 스크립트
==============================

사용법: .\sync-to-nas.ps1 -Action <명령어> [옵션]

명령어:
  sync     전체 동기화 워크플로우 실행 (Git → NAS → Docker)
  git      Git 커밋 및 푸시만 실행
  docker   NAS Docker 서비스 재시작만 실행
  status   로컬 및 NAS 동기화 상태 확인
  help     이 도움말 표시

옵션:
  -Message "커밋 메시지"    Git 커밋 메시지 지정
  -Force                   확인 없이 강제 실행

예시:
  .\sync-to-nas.ps1 -Action sync
  .\sync-to-nas.ps1 -Action sync -Message "서브도메인 설정 업데이트"
  .\sync-to-nas.ps1 -Action git -Message "스크립트 수정"
  .\sync-to-nas.ps1 -Action status
  .\sync-to-nas.ps1 -Action docker

작업 흐름:
  [VSCode 로컬] → [Git Push] → [NAS Git Pull] → [Docker 재시작]
  D:\Dev\DCEC\CPSE  →  GitHub  →  /volume1/dev/CPSE  →  서비스 갱신

"@ -ForegroundColor White
}

# 메인 실행 로직
switch ($Action) {
    "sync" {
        Start-FullSync -CommitMessage $Message -ForceSync $Force
    }
    "git" {
        if (Test-NasConnection) {
            Sync-GitChanges -CommitMessage $Message
        }
    }
    "docker" {
        if (Test-NasConnection) {
            Restart-NasDockerServices
        }
    }
    "status" {
        Get-SyncStatus
    }
    "help" {
        Show-Help
    }
    default {
        Write-ColorLog "알 수 없는 명령어: $Action" "Error"
        Show-Help
    }
}
