#requires -Version 7.0
<#
.SYNOPSIS
    DCEC SSH Key Manager - SSH 키 및 접속 관리 시스템
.DESCRIPTION
    DCEC 프로젝트 내에서 SSH 키와 접속 설정을 중앙 집중식으로 관리
    - NAS 접속 키 관리
    - SSH 설정 자동화
    - 다양한 환경에서의 키 재사용
    - DSM 7.x 이상 정책(보안/권한/포트/rsync-only) 안내 및 예외처리
.EXAMPLE
    .\DCEC-SSH-Manager.ps1 -Action ConnectNAS
    .\DCEC-SSH-Manager.ps1 -Action SetupKeys
    .\DCEC-SSH-Manager.ps1 -Action TestConnection
#>

<#
[감사 안내]
- 시놀로지 DSM 7.x 이상에서는 scp 명령이 지원되지 않으므로, 모든 파일 전송/동기화는 rsync(ssh 옵션) 또는 SFTP만 사용해야 합니다.
- SSH는 사용자 계정+sudo 권한 필요, root 직접 로그인 불가
- 컨테이너 내부 데이터(.storage 등)는 NAS에서 chown/chmod 불가, 오류 무시
- 주요 포트(80/443 등) 충돌 주의, DSM File Station/Container Manager로 수동 복사/관리 가능
- 자동화 실패 시 상세 원인과 수동 대체 방법(DSM GUI 등) 안내 필수
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('ConnectNAS', 'SetupKeys', 'TestConnection', 'ShowConfig', 'UpdateConfig')]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$HostAlias = "dcec-nas"
)

# DCEC 키 관리 경로
$Script:DCECRoot = "c:\dev\DCEC"
$Script:KeysPath = Join-Path $DCECRoot "keys"
$Script:SSHPath = Join-Path $KeysPath "ssh"
$Script:ConfigPath = Join-Path $KeysPath "config"
$Script:SSHConfig = Join-Path $ConfigPath "ssh_config"
$Script:PrivateKey = Join-Path $SSHPath "dcec_nas_id_rsa"
$Script:PublicKey = Join-Path $SSHPath "dcec_nas_id_rsa.pub"

function Write-DCECLog {
    param([string]$Message, [string]$Type = "Info")
    $colors = @{
        'Info' = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error' = 'Red'
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [DCEC-SSH] $Message" -ForegroundColor $colors[$Type]
}

function Test-DCECSSHConnection {
    param([string]$HostAlias = "dcec-nas")
    Write-DCECLog "SSH 접속 테스트: $HostAlias" "Info"
    try {
        $result = ssh -F $SSHConfig $HostAlias "echo 'DCEC SSH 연결 성공: $(date)'; pwd"
        if ($LASTEXITCODE -eq 0) {
            Write-DCECLog "SSH 접속 성공!" "Success"
            Write-DCECLog $result "Info"
            return $true
        } else {
            Write-DCECLog "SSH 접속 실패" "Error"
            Write-DCECLog "DSM 7.x 이상에서는 사용자 계정+sudo 권한 필요, root 직접 로그인 불가" "Warning"
            return $false
        }
    } catch {
        Write-DCECLog "SSH 접속 중 오류: $_" "Error"
        Write-DCECLog "방화벽, 포트, SSH 키, DSM 정책(권한/포트) 확인 필요" "Warning"
        return $false
    }
}

function Connect-DCECNAS {
    param([string]$HostAlias = "dcec-nas")
    Write-DCECLog "NAS에 접속합니다: $HostAlias" "Info"
    if (-not (Test-Path $SSHConfig)) {
        Write-DCECLog "SSH 설정 파일이 없습니다: $SSHConfig" "Error"
        return
    }
    if (-not (Test-Path $PrivateKey)) {
        Write-DCECLog "SSH 키 파일이 없습니다: $PrivateKey" "Error"
        return
    }
    ssh -F $SSHConfig $HostAlias
}

function Setup-DCECKeys {
    Write-DCECLog "DCEC SSH 키 설정을 시작합니다" "Info"
    # 사용자 SSH 키가 있는지 확인
    $userPrivateKey = Join-Path $env:USERPROFILE ".ssh\id_rsa"
    $userPublicKey = Join-Path $env:USERPROFILE ".ssh\id_rsa.pub"
    if (Test-Path $userPrivateKey) {
        Write-DCECLog "기존 SSH 키를 DCEC로 복사합니다" "Info"
        Copy-Item $userPrivateKey $PrivateKey -Force
        Copy-Item $userPublicKey $PublicKey -Force
        Write-DCECLog "키 복사 완료" "Success"
    } else {
        Write-DCECLog "사용자 SSH 키가 없습니다. 먼저 키를 생성하세요." "Warning"
        return
    }
    # 키 권한 설정 (Windows에서는 제한적)
    Write-DCECLog "키 파일 권한 설정(Windows 환경은 제한적, DSM에서는 600/700 권장)" "Info"
    # SSH 설정 테스트
    if (Test-DCECSSHConnection) {
        Write-DCECLog "DCEC SSH 설정이 완료되었습니다" "Success"
    } else {
        Write-DCECLog "SSH 설정에 문제가 있습니다" "Warning"
    }
}

function Show-DCECConfig {
    Write-DCECLog "=== DCEC SSH 설정 정보 ===" "Info"
    Write-DCECLog "키 경로: $KeysPath" "Info"
    Write-DCECLog "SSH 설정: $SSHConfig" "Info"
    Write-DCECLog "Private Key: $PrivateKey" "Info"
    Write-DCECLog "Public Key: $PublicKey" "Info"
    if (Test-Path $SSHConfig) {
        Write-DCECLog "SSH 설정 파일 내용:" "Info"
        Get-Content $SSHConfig | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    }
    if (Test-Path $PublicKey) {
        Write-DCECLog "Public Key 내용:" "Info"
        $pubKeyContent = Get-Content $PublicKey
        Write-Host "  $pubKeyContent" -ForegroundColor Gray
    }
}

function Update-DCECConfig {
    Write-DCECLog "DCEC SSH 설정을 업데이트합니다" "Info"
    # 현재 설정 백업
    if (Test-Path $SSHConfig) {
        $backupFile = "$SSHConfig.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $SSHConfig $backupFile
        Write-DCECLog "기존 설정 백업: $backupFile" "Info"
    }
    # 새 설정 적용
    Setup-DCECKeys
}

# === 감사 기준 안내 및 주요 정책 출력 ===
Write-DCECLog "==== 시놀로지 DSM 7.x 이상 SSH/권한/포트/rsync-only 정책 ====" "Warning"
Write-Host @"
- scp 명령은 지원되지 않으므로, 모든 파일 전송/동기화는 rsync(ssh 옵션) 또는 SFTP만 사용해야 합니다.
- SSH는 사용자 계정+sudo 권한 필요, root 직접 로그인 불가
- 컨테이너 내부 데이터(.storage 등)는 NAS에서 chown/chmod 불가, 오류 무시
- 주요 포트(80/443 등) 충돌 주의, DSM File Station/Container Manager로 수동 복사/관리 가능
- 자동화 실패 시 상세 원인과 수동 대체 방법(DSM GUI 등) 안내 필수
"@ -ForegroundColor Yellow

# 메인 로직
switch ($Action) {
    'ConnectNAS' {
        Connect-DCECNAS -HostAlias $HostAlias
    }
    'SetupKeys' {
        Setup-DCECKeys
    }
    'TestConnection' {
        $result = Test-DCECSSHConnection -HostAlias $HostAlias
        if ($result) {
            Write-DCECLog "연결 테스트 성공" "Success"
        } else {
            Write-DCECLog "연결 테스트 실패" "Error"
            Write-DCECLog "실패 시 DSM File Station(웹), WinSCP, SFTP 등으로 직접 파일을 복사/접속하세요." "Warning"
        }
    }
    'ShowConfig' {
        Show-DCECConfig
    }
    'UpdateConfig' {
        Update-DCECConfig
    }
}
