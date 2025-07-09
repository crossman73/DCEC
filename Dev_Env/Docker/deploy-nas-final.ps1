# NAS Docker Environment Deployment Script
# Windows 11 + Synology DSM 7.2 + Cygwin rsync 환경
# scp 완전 제거, rsync-only, 경로 변환, 퍼미션 오류 무시, 환경 안내, 체크리스트 포함
# 반드시 Windows PC(PowerShell, Cygwin, Git Bash 등)에서 실행! NAS에서 실행 금지!

# Define default values for parameters
$NasIP = "192.168.0.5"
$NasPort = "22022"
$NasUser = "crossman"
$LocalDir = "d:\Dev\DCEC\Dev_Env\Docker"
$RemoteDir = "/volume1/docker/"
$Command = "deploy"
$SshKeyPath = ""
$NoPause = $false

# Parse command-line arguments to override defaults
for ($i = 0; $i -lt $args.Length; $i++) {
    switch ($args[$i]) {
        "-NasIP" { $NasIP = $args[++$i] }
        "-NasPort" { $NasPort = $args[++$i] }
        "-NasUser" { $NasUser = $args[++$i] }
        "-LocalDir" { $LocalDir = $args[++$i] }
        "-RemoteDir" { $RemoteDir = $args[++$i] }
        "-Command" { $Command = $args[++$i] }
        "-SshKeyPath" { $SshKeyPath = $args[++$i] }
        "-NoPause" { $NoPause = $true }
    }
}

# 자동으로 최적의 SSH 키를 찾기 위한 헬퍼 함수
function Find-DefaultSshKey {
    $defaultSshPath = "$env:USERPROFILE\.ssh"
    # SSH 키 우선순위 정의 (최신/보안 권장 순)
    $keyPrecedence = @(
        "id_ed25519",
        "id_ecdsa",
        "id_rsa"
    )

    foreach ($keyFile in $keyPrecedence) {
        $keyPath = Join-Path -Path $defaultSshPath -ChildPath $keyFile
        if (Test-Path $keyPath) {
            # 가장 먼저 찾아낸 키를 기본값으로 반환
            return $keyPath
        }
    }

    # 어떤 키도 찾지 못하면, 기존의 기본값(id_rsa)을 반환
    # 이후 스크립트의 키 존재 여부 체크 로직에서 오류를 처리함
    return Join-Path -Path $defaultSshPath -ChildPath "id_rsa"
}

if (-not $SshKeyPath) {
    $SshKeyPath = Find-DefaultSshKey
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Pause-IfNeeded {
    param([string]$Message)
    Write-Host $Message
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Git Bash usr\bin을 PATH에 임시 추가
$gitUsrBin = 'C:\Program Files\Git\usr\bin'
if (Test-Path $gitUsrBin) {
    $env:PATH = "$gitUsrBin;$env:PATH"
    Write-ColorOutput "임시로 PATH에 Git Bash usr\\bin 추가: $gitUsrBin" "Cyan"
}

function Check-RsyncInstalled {
    $rsyncCheck = Get-Command rsync -ErrorAction SilentlyContinue
    if (-not $rsyncCheck) {
        Write-ColorOutput "@
rsync가 설치되어 있지 않습니다.

- Windows용 Git for Windows에는 rsync가 포함되어 있지 않습니다.
- Windows에서 rsync를 사용하려면 아래 중 하나를 설치하세요:

  1. cwRsync (https://itefix.net/cwrsync) 설치 후, bin 폴더를 환경변수 PATH에 추가
  2. MSYS2 (https://www.msys2.org/) 설치 후, pacman -S rsync 명령으로 설치
  3. Cygwin 설치 시 rsync, openssh 패키지 포함 설치

설치 후 PowerShell을 재시작하거나, 환경변수 PATH를 확인하세요.
@" "Red"
        Pause-IfNeeded "Press any key to exit..."
        exit 1
    }
}
Check-RsyncInstalled

# SSH 키 파일 존재 여부 사전 체크
if (!(Test-Path $SshKeyPath)) {
    Write-ColorOutput "SSH 키 파일이 존재하지 않습니다: $SshKeyPath" "Red"
    Write-ColorOutput "Windows에서 해당 경로에 키 파일이 있는지 확인하세요." "Yellow"
    Pause-IfNeeded "Press any key to exit..."
    exit 1
}

function Convert-ToCygwinPath {
    param([string]$winPath)
    $cygPath = $winPath -replace '\\', '/'
    if ($cygPath -match '^([a-zA-Z]):') {
        $drive = $Matches[1].ToLower()
        $cygPath = "/cygdrive/$drive" + $cygPath.Substring(2)
    }
    return $cygPath
}

function Sync-FilesToNAS {
    Write-ColorOutput "동기화: rsync로 파일 전송..." "Yellow"
    $localDirCyg = Convert-ToCygwinPath $LocalDir
    $sshKeyCyg = Convert-ToCygwinPath $SshKeyPath
    $rsyncCmd = "rsync --timeout=30 -a --info=progress2 --append-verify -e `"ssh -i $sshKeyCyg -p $NasPort`" $localDirCyg/ $NasUser@${NasIP}:${RemoteDir}"
    Write-Host $rsyncCmd
    Invoke-Expression $rsyncCmd
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "✓ rsync 파일 동기화 완료" "Green"
        return $true
    }
    else {
        Write-ColorOutput "✗ rsync 파일 동기화 실패" "Red"
        Write-ColorOutput "실패 시 Cygwin 터미널에서 직접 실행하거나, DSM File Station 등으로 수동 복사하세요." "Yellow"
        return $false
    }
}

function Test-LocalFiles {
    try {
        Write-ColorOutput "Verifying local files..." "Yellow"
        $requiredFiles = @(
            (Join-Path $LocalDir ".env"),
            (Join-Path $LocalDir "docker-compose.yml"),
            (Join-Path $LocalDir "nas-setup-complete.sh")
        )
        $optionalFiles = @(
            (Join-Path $LocalDir "n8n\\20250626_n8n_API_KEY.txt")
        )
        $allGood = $true
        foreach ($file in $requiredFiles) {
            if (Test-Path $file) {
                Write-ColorOutput "✓ Found: $file" "Green"
            }
            else {
                Write-ColorOutput "✗ Missing: $file" "Red"
                $allGood = $false
            }
        }
        foreach ($file in $optionalFiles) {
            if (Test-Path $file) {
                Write-ColorOutput "✓ Found: $file" "Green"
            }
            else {
                Write-ColorOutput "! Optional: $file (will create placeholder)" "Yellow"
            }
        }
        return $allGood
    }
    catch {
        Write-ColorOutput "오류: $($_.Exception.Message)" "Red"
        return $false
    }
}

function New-RemoteDirectoryStructure {
    try {
        Write-ColorOutput "Checking if directory structure already exists on NAS..." "Yellow"
        $checkCmd = "test -d '${RemoteDir}data' && test -d '${RemoteDir}config' && test -d '${RemoteDir}logs' && echo 'exists' || echo 'missing'"
        $exists = ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" $checkCmd
        if ($exists -eq "exists") {
            Write-ColorOutput "디렉토리 구조가 이미 존재합니다. (생성 생략)" "Green"
            return $true
        }

        Write-ColorOutput "Creating directory structure on NAS..." "Yellow"
        $directories = @(
            "${RemoteDir}data",
            "${RemoteDir}config",
            "${RemoteDir}logs",
            "${RemoteDir}data/postgres",
            "${RemoteDir}data/n8n",
            "${RemoteDir}data/gitea",
            "${RemoteDir}data/code-server",
            "${RemoteDir}data/uptime-kuma",
            "${RemoteDir}data/portainer",
            "${RemoteDir}config/n8n",
            "${RemoteDir}config/gitea",
            "${RemoteDir}config/code-server",
            "${RemoteDir}config/uptime-kuma",
            "${RemoteDir}config/portainer",
            "${RemoteDir}postgresql",
            "${RemoteDir}pgadmin",
            "${RemoteDir}memos/db",
            "${RemoteDir}memos/data"
        )
        foreach ($dir in $directories) {
            ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "mkdir -p '$dir'"
            Write-ColorOutput "디렉토리 생성: $dir" "Cyan"
        }
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "sudo chown -R ${NasUser}:users ${RemoteDir} 2>/dev/null || true"
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "sudo chmod -R 755 ${RemoteDir} 2>/dev/null || true"
        Write-ColorOutput "Directory structure and permissions set successfully" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "디렉토리 구조 생성 실패: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Copy-FileWithRetry {
    param([string]$LocalFile, [string]$RemoteFile, [int]$MaxRetries = 3)
    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-ColorOutput "Transferring $LocalFile (attempt $i/$MaxRetries)..." "Cyan"
        try {
            scp -P $NasPort "$LocalFile" "${NasUser}@${NasIP}:$RemoteFile"
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✓ Successfully transferred: $(Split-Path $LocalFile -Leaf)" "Green"
                return $true
            }
        }
        catch {
            Write-ColorOutput "Transfer attempt $i failed: $($_.Exception.Message)" "Yellow"
        }
        if ($i -lt $MaxRetries) { Start-Sleep -Seconds 2 }
    }
    Write-ColorOutput "✗ Failed to transfer after $MaxRetries attempts: $(Split-Path $LocalFile -Leaf)" "Red"
    return $false
}

function Test-RemoteFiles {
    try {
        Write-ColorOutput "Verifying files on NAS..." "Yellow"
        $remoteFiles = ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "find ${RemoteDir} -type f -ls 2>/dev/null || ls -la ${RemoteDir} 2>/dev/null"
        Write-ColorOutput "Files found on NAS:" "White"
        Write-Host $remoteFiles
        $requiredFiles = @(
            "${RemoteDir}.env",
            "${RemoteDir}docker-compose.yml",
            "${RemoteDir}nas-setup-complete.sh"
        )
        $allGood = $true
        foreach ($file in $requiredFiles) {
            $exists = ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "test -f '$file' && echo 'exists' || echo 'missing'"
            if ($exists -eq "exists") {
                Write-ColorOutput "✓ Remote file exists: $file" "Green"
            }
            else {
                Write-ColorOutput "✗ Remote file missing: $file" "Red"
                $allGood = $false
            }
        }
        return $allGood
    }
    catch {
        Write-ColorOutput "원격 파일 검증 실패: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Test-SSHConnection {
    try {
        Write-ColorOutput "Checking SSH connection to NAS..." "Yellow"
        $result = ssh -i $SshKeyPath -p $NasPort -o ConnectTimeout=10 "${NasUser}@${NasIP}" "echo 'SSH connection successful'"
        if ($result -eq "SSH connection successful") {
            Write-ColorOutput "SSH connection to NAS established" "Green"
            return $true
        }
        Write-ColorOutput "SSH connection failed (no response)" "Red"
        return $false
    }
    catch {
        Write-ColorOutput "Cannot connect to NAS via SSH: $($_.Exception.Message)" "Red"
        Write-ColorOutput "1. NAS IP/포트/계정/키 확인" "White"
        return $false
    }
}

# 1. Git Bash usr\bin을 PATH에 임시 추가
$gitUsrBin = 'C:\Program Files\Git\usr\bin'
if (Test-Path $gitUsrBin) {
    $env:PATH = "$gitUsrBin;$env:PATH"
    Write-ColorOutput "임시로 PATH에 Git Bash usr\\bin 추가: $gitUsrBin" "Cyan"
}

# 2. rsync가 없으면 Git Bash로 직접 호출
function Invoke-Rsync {
    param(
        [string]$LocalDir,
        [string]$NasUser,
        [string]$NasIP,
        [string]$NasPort,
        [string]$SshKeyPath,
        [string]$RemoteDir
    )
    $rsyncCheck = Get-Command rsync -ErrorAction SilentlyContinue
    if ($rsyncCheck) {
        $localDirCyg = Convert-ToCygwinPath $LocalDir
        $sshKeyCyg = Convert-ToCygwinPath $SshKeyPath
        $rsyncCmd = 'rsync --timeout=30 -a --info=progress2 --append-verify -e "ssh -i ' + $sshKeyCyg + ' -p ' + $NasPort + '" "' + $localDirCyg + '/" "' + $NasUser + '@' + $NasIP + ':' + $RemoteDir + '"'
        Write-ColorOutput $rsyncCmd "Cyan"
        Invoke-Expression $rsyncCmd
        return $LASTEXITCODE
    }
    Write-ColorOutput "로컬에 rsync가 설치되어 있지 않습니다. Cygwin/MSYS2 환경에서 실행하세요." "Red"
    return 1
}
# 3. Copy-FilesToNAS에서 rsync 호출 부분만 아래처럼 교체
function Copy-FilesToNAS {
    try {
        Write-ColorOutput "Transferring files to NAS (rsync)..." "Yellow"
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "mkdir -p ${RemoteDir}data ${RemoteDir}config ${RemoteDir}config/n8n ${RemoteDir}logs"
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "chown -R ${NasUser}:users ${RemoteDir}"
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "chmod -R 755 ${RemoteDir}"
        Write-ColorOutput "Directory structure created successfully" "Green"

        $rsyncResult = Invoke-Rsync -LocalDir $LocalDir -NasUser $NasUser -NasIP $NasIP -NasPort $NasPort -SshKeyPath $SshKeyPath -RemoteDir $RemoteDir
        if ($rsyncResult -ne 0) {
            Write-ColorOutput "✗ rsync 파일 동기화 실패 (10초 이상 응답 없음 또는 네트워크 문제)" "Red"
            Write-ColorOutput "네트워크, 방화벽, NAS SSH 설정, NAS의 rsync/SSH 포트 오픈 상태를 점검하세요." "Yellow"
            return $false
        }

        # n8n API Key가 없으면 placeholder 생성
        $n8nApiKey = Join-Path $LocalDir "n8n\\20250626_n8n_API_KEY.txt"
        if (!(Test-Path $n8nApiKey)) {
            Write-ColorOutput "Warning: n8n API key not found at $n8nApiKey" "Yellow"
            ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "echo 'n8n_api_key_placeholder' > ${RemoteDir}config/n8n/api-keys.txt"
        }

        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "chmod +x ${RemoteDir}nas-setup-complete.sh 2>/dev/null || true"
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "chmod 644 ${RemoteDir}.env ${RemoteDir}docker-compose.yml 2>/dev/null || true"
        Write-ColorOutput "Files transferred successfully (rsync)" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "파일 전송 실패: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Invoke-SetupScript {
    try {
        Write-ColorOutput "Running setup script on NAS..." "Yellow"
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && ./nas-setup-complete.sh"
        Write-ColorOutput "Setup script execution completed" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "셋업 스크립트 실행 실패: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Select-ServicesToDeploy {
    $services = @("n8n", "gitea", "code-server", "uptime-kuma", "portainer")
    $enabled = @()
    foreach ($svc in $services) {
        try {
            $exists = ssh -i $SshKeyPath -p $NasPort "$NasUser@$NasIP" "docker images --format '{{.Repository}}' | grep -w $svc || true"
            if ($exists) {
                $answer = Read-Host "$svc 이미지가 이미 존재합니다. 재설치(업데이트) 하시겠습니까? (y/n)"
                if ($answer -match "^[Yy]") { $enabled += $svc }
            }
            else {
                $answer = Read-Host "$svc 서비스를 새로 설치하시겠습니까? (y/n)"
                if ($answer -match "^[Yy]") { $enabled += $svc }
            }
        }
        catch {
            Write-ColorOutput "서비스 확인 오류($svc): $($_.Exception.Message)" "Red"
        }
    }
    return $enabled
}

function Deploy-DockerServices {
    Write-ColorOutput "Deploying Docker services on NAS..." "Yellow"
    $enabled = Select-ServicesToDeploy
    if ($enabled.Count -eq 0) {
        Write-ColorOutput "선택된 서비스가 없습니다. 배포를 중단합니다." "Yellow"
        return $false
    }
    $svcArgs = $enabled -join " "
    try {
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker compose pull $svcArgs"
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker compose down $svcArgs --remove-orphans"
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker compose up -d $svcArgs"
        Write-ColorOutput "Docker services deployed: $svcArgs" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Failed to deploy services: $_" "Red"
        return $false
    }
}

function Test-ServicesHealth {
    Write-ColorOutput "Performing health check..." "Yellow"
    Start-Sleep -Seconds 30
    try {
        ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker compose ps"
        Write-ColorOutput "Health check completed" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Health check failed: $_" "Red"
        return $false
    }
}

function Show-ServiceInfo {
    Write-ColorOutput "Service Information:" "Cyan"
    Write-Host ""
    Write-Host "=== Service URLs ===" -ForegroundColor Yellow
    Write-Host "n8n:              http://192.168.0.5:31001" -ForegroundColor White
    Write-Host "Gitea:            http://192.168.0.5:8484" -ForegroundColor White
    Write-Host "Code Server:      http://192.168.0.5:3000" -ForegroundColor White
    Write-Host "Uptime Kuma:      http://192.168.0.5:31003" -ForegroundColor White
    Write-Host "Portainer:        http://192.168.0.5:9000" -ForegroundColor White
    Write-Host "PostgreSQL:       http://192.168.0.5:5432" -ForegroundColor White
    Write-Host "pgAdmin:          http://192.168.0.5:5050" -ForegroundColor White
    Write-Host "Memos:            http://192.168.0.5:5235" -ForegroundColor White
    Write-Host ""
    Write-Host "=== Sub-domain URLs (if configured) ===" -ForegroundColor Yellow
    Write-Host "n8n:              https://n8n.crossman.synology.me" -ForegroundColor White
    Write-Host "Gitea:            https://git.crossman.synology.me" -ForegroundColor White
    Write-Host "Code Server:      https://code.crossman.synology.me" -ForegroundColor White
    Write-Host "Uptime Kuma:      https://uptime.crossman.synology.me" -ForegroundColor White
    Write-Host "Memos:            https://memos.crossman.synology.me" -ForegroundColor White
    Write-Host ""
    Write-Host "=== Default Credentials ===" -ForegroundColor Yellow
    Write-Host "n8n:              admin / changeme123" -ForegroundColor White
    Write-Host "Code Server:      changeme123" -ForegroundColor White
    Write-Host "Database:         nasuser / changeme123" -ForegroundColor White
    Write-Host "pgAdmin:          you@example.com / AdminPass123" -ForegroundColor White
    Write-Host "Memos:            admin / memospass" -ForegroundColor White
    Write-Host ""
}

function Rollback-Deployment {
    Write-ColorOutput "롤백 시작: 로그 기반으로 생성된 리소스 삭제 시도..." "Red"
    if (Test-Path $LogFile) {
        $lines = Get-Content $LogFile | Where-Object { $_ -match "생성|전송|배포|동기화" }
        foreach ($line in $lines) {
            if ($line -match "디렉토리 생성: (.+)") {
                $dir = $Matches[1]
                ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "rm -rf '$dir'"
                Write-ColorOutput "롤백: 디렉토리 삭제 $dir" "Red"
            }
            if ($line -match "파일 전송: (.+)") {
                $file = $Matches[1]
                ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "rm -f '$file'"
                Write-ColorOutput "롤백: 파일 삭제 $file" "Red"
            }
            if ($line -match "Docker services deployed: (.+)") {
                $svc = $Matches[1]
                ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker compose down $svc --remove-orphans"
                Write-ColorOutput "롤백: 서비스 중지 및 삭제 $svc" "Red"
            }
        }
        Write-ColorOutput "롤백 완료" "Red"
    }
    else {
        Write-ColorOutput "롤백 로그 파일이 없습니다." "Yellow"
    }
}

# =========================
# 메인 실행부
# =========================

Write-ColorOutput "==========================================" "Cyan"
Write-ColorOutput "NAS Docker Environment Deployment" "Cyan"
Write-ColorOutput "==========================================" "Cyan"

Write-ColorOutput "==== Synology NAS Docker 감사 체크리스트 ====" "Cyan"
Write-Host "1. SSH 활성화 및 NAS_USER sudo 권한"
Write-Host "2. /volume1/docker/data, /config, /logs 및 서비스별 하위 디렉토리 생성"
Write-Host "3. .env, docker-compose.yml, nas-setup-complete.sh 등 주요 파일 전송"
Write-Host "4. docker-compose.yml의 볼륨 경로가 실제 NAS 경로인지 확인"
Write-Host "5. external 네트워크(nas-services-network) DSM에서 사전 생성 필요"
Write-Host "6. healthcheck는 curl 기반, 포트 충돌 없음 확인"
Write-Host "7. 배포 후 서비스별 URL/계정/상태 확인"
Write-Host ""

# Step 1: Verify local files
Write-ColorOutput "Step 1: Verifying local files..." "Yellow"
if (!(Test-LocalFiles)) {
    Write-ColorOutput "Some required local files are missing. Please check the file paths." "Red"
    Pause-IfNeeded "Press any key to continue anyway or Ctrl+C to abort..."
}

# Step 2: Test SSH connection
Write-ColorOutput "Step 2: Testing SSH connection..." "Yellow"
if (!(Test-SSHConnection)) {
    Write-ColorOutput "SSH connection failed. Cannot proceed with deployment." "Red"
    Pause-IfNeeded "Press any key to exit..."
    exit 1
}

# Step 3: Create directory structure
Write-ColorOutput "Step 3: Creating directory structure..." "Yellow"
if (!(New-RemoteDirectoryStructure)) {
    Write-ColorOutput "Failed to create directory structure. Continuing anyway..." "Yellow"
}

# Step 4: Transfer files
Write-ColorOutput "Step 4: Transferring files..." "Yellow"
if (!(Copy-FilesToNAS)) {
    Write-ColorOutput "File transfer failed. Cannot proceed with deployment." "Red"
    Pause-IfNeeded "Press any key to exit..."
    exit 1
}

# Step 5: Verify remote files
Write-ColorOutput "Step 5: Verifying remote files..." "Yellow"
if (!(Test-RemoteFiles)) {
    Write-ColorOutput "Some files are missing on NAS. Continuing anyway..." "Yellow"
}

# Step 6: Run setup script
Write-ColorOutput "Step 6: Running setup script..." "Yellow"
if (!(Invoke-SetupScript)) {
    Write-ColorOutput "Setup script failed. Continuing anyway..." "Yellow"
}

# Step 7: Sync files with rsync
Write-ColorOutput "Step 7: Syncing files with rsync..." "Yellow"
if (!(Sync-FilesToNAS)) {
    Write-ColorOutput "rsync 파일 동기화 실패. 계속 진행합니다." "Yellow"
}

# Step 8: Deploy Docker services (선택적 재설치)
Write-ColorOutput "Step 8: Deploying Docker services..." "Yellow"
Write-ColorOutput "※ DSM에서 'nas-services-network' 네트워크가 사전 생성되어 있어야 합니다." "Yellow"
if (!(Deploy-DockerServices)) {
    Write-ColorOutput "Docker deployment failed. Check the logs above." "Red"
    Write-ColorOutput "Press any key to continue to health check..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Step 9: Health check
Write-ColorOutput "Step 9: Performing health check..." "Yellow"
if (!(Test-ServicesHealth)) {
    Write-ColorOutput "Health check failed. Services may not be running properly." "Yellow"
}

# Step 10: Show service information
Write-ColorOutput "Step 10: Displaying service information..." "Yellow"
Show-ServiceInfo

Write-ColorOutput "==========================================" "Cyan"
Write-ColorOutput "Deployment process completed!" "Green"
Write-ColorOutput "==========================================" "Cyan"
Write-ColorOutput "Check the service URLs above to verify everything is working." "Cyan"
Write-ColorOutput "If services are not accessible, try running docker compose manually on NAS." "Yellow"

Write-ColorOutput "Press any key to continue..." "Yellow"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

cd C:\Dev\DCEC\Dev_Env\Docker
powershell -ExecutionPolicy Bypass -File .\deploy-nas-env.ps1

function Set-RemotePermissions {
    $excludePatterns = @(".storage", "/db", "/lost+found")
    $dirs = @(
        "${RemoteDir}data",
        "${RemoteDir}config",
        "${RemoteDir}logs"
    )
    foreach ($dir in $dirs) {
        $skip = $false
        foreach ($pattern in $excludePatterns) {
            if ($dir -like "*$pattern*") { $skip = $true; break }
        }
        if ($skip) {
            Write-ColorOutput "권한 변경 제외: $dir" "Yellow"
            continue
        }
        try {
            ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "chown -R ${NasUser}:users '$dir' 2>/dev/null || true"
            ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "chmod -R 755 '$dir' 2>/dev/null || true"
        }
        catch {
            Write-ColorOutput "권한 변경 실패(무시): $dir" "Yellow"
        }
    }
}