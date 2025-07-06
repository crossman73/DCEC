# 시놀로지 NAS 접속 도우미 (PowerShell)
# 사용자: crossman, 포트: 22022

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('ssh', 'test', 'scp', 'rsync', 'dsm')]
    [string]$Action,
    
    [string]$Source,
    [string]$Destination
)

# NAS 연결 정보
$NAS_IP = "192.168.0.5"
$SSH_PORT = "22022"
$SSH_USER = "crossman"

# 색상 출력 함수
function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    $colors = @{
        "Red" = "Red"; "Green" = "Green"; "Yellow" = "Yellow"
        "Blue" = "Blue"; "Magenta" = "Magenta"; "Cyan" = "Cyan"
    }
    Write-Host $Text -ForegroundColor $colors[$Color]
}

function Write-Info { Write-ColorText "[INFO] $args" "Green" }
function Write-Warn { Write-ColorText "[WARN] $args" "Yellow" }
function Write-Error { Write-ColorText "[ERROR] $args" "Red" }
function Write-Step { Write-ColorText "[STEP] $args" "Blue" }

Write-Step "🔌 시놀로지 NAS 접속 도우미 (PowerShell)"
Write-Info "접속 정보: $SSH_USER@${NAS_IP}:$SSH_PORT"
Write-Host ""

switch ($Action) {
    "ssh" {
        Write-Info "SSH 접속 중..."
        if (Get-Command ssh -ErrorAction SilentlyContinue) {
            ssh -p $SSH_PORT "$SSH_USER@$NAS_IP"
        } else {
            Write-Error "SSH 클라이언트가 설치되지 않았습니다."
            Write-Info "Windows 10/11에서 OpenSSH 설치: Settings > Apps > Optional Features > OpenSSH Client"
        }
    }
    "test" {
        Write-Info "NAS 연결 테스트 중..."
        if (Get-Command ssh -ErrorAction SilentlyContinue) {
            ssh -p $SSH_PORT -o ConnectTimeout=5 "$SSH_USER@$NAS_IP" "echo '✅ NAS 연결 성공!' && uname -a"
        } else {
            Write-Warn "SSH 클라이언트가 없어서 ping 테스트만 실행합니다."
            Test-NetConnection -ComputerName $NAS_IP -Port $SSH_PORT
        }
    }
    "scp" {
        if (-not $Source -or -not $Destination) {
            Write-Error "사용법: .\nas-connect.ps1 -Action scp -Source <로컬파일> -Destination <원격경로>"
            Write-Info "예시: .\nas-connect.ps1 -Action scp -Source '.\test.txt' -Destination '/volume1/homes/crossman/'"
            return
        }
        Write-Info "파일 복사 중: $Source -> $Destination"
        if (Get-Command scp -ErrorAction SilentlyContinue) {
            scp -P $SSH_PORT "$Source" "$SSH_USER@${NAS_IP}:$Destination"
        } else {
            Write-Error "SCP 명령이 없습니다. OpenSSH 클라이언트를 설치하세요."
        }
    }
    "rsync" {
        if (-not $Source -or -not $Destination) {
            Write-Error "사용법: .\nas-connect.ps1 -Action rsync -Source <로컬디렉토리> -Destination <원격경로>"
            Write-Info "예시: .\nas-connect.ps1 -Action rsync -Source '.\project\' -Destination '/volume1/docker/'"
            return
        }
        Write-Info "디렉토리 동기화 중: $Source -> $Destination"
        if (Get-Command rsync -ErrorAction SilentlyContinue) {
            rsync -avz -e "ssh -p $SSH_PORT" "$Source" "$SSH_USER@${NAS_IP}:$Destination"
        } else {
            Write-Warn "rsync이 없습니다. robocopy를 사용하여 로컬 동기화만 가능합니다."
            Write-Info "WSL이나 Git Bash를 사용하여 rsync를 실행하는 것을 권장합니다."
        }
    }
    "dsm" {
        Write-Info "DSM API 연결 테스트 중..."
        try {
            $response = Invoke-RestMethod -Uri "http://${NAS_IP}:5000/webapi/entry.cgi" `
                -Method POST `
                -Body @{
                    'api' = 'SYNO.API.Info'
                    'version' = '1'
                    'method' = 'query'
                    'query' = 'all'
                } -ContentType 'application/x-www-form-urlencoded'
            
            Write-Info "✅ DSM API 연결 성공!"
            Write-Info "사용 가능한 API: $($response.data.PSObject.Properties.Name -join ', ')"
        } catch {
            Write-Error "DSM API 연결 실패: $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Info "수동 접속 명령어:"
Write-Host "  ssh -p $SSH_PORT $SSH_USER@$NAS_IP" -ForegroundColor Gray
