# 시놀로지 NAS 리버스 프록시 서브도메인 자동 관리 스크립트 (PowerShell)
# DSM API를 활용한 서브도메인 설정 자동화

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("list", "add", "delete", "setup-all", "status", "help")]
    [string]$Command = "help",
    
    [Parameter(Mandatory=$false)]
    [string]$Parameter = ""
)

# 컬러 로깅 함수
function Write-LogInfo { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-LogWarn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-LogError { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-LogStep { param($Message) Write-Host "[STEP] $Message" -ForegroundColor Blue }
function Write-LogSuccess { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Magenta }

# 서브도메인 서비스 설정 (README.md 기반)
$SubdomainConfig = @{
    "n8n" = @{
        subdomain = "n8n.crossman.synology.me"
        external_port = 31001
        internal_port = 5678
        description = "워크플로우 자동화"
    }
    "mcp" = @{
        subdomain = "mcp.crossman.synology.me"
        external_port = 31002
        internal_port = 31002
        description = "모델 컨텍스트 프로토콜"
    }
    "uptime" = @{
        subdomain = "uptime.crossman.synology.me"
        external_port = 31003
        internal_port = 31003
        description = "모니터링"
    }
    "code" = @{
        subdomain = "code.crossman.synology.me"
        external_port = 8484
        internal_port = 8484
        description = "VSCode 웹 환경"
    }
    "gitea" = @{
        subdomain = "git.crossman.synology.me"
        external_port = 3000
        internal_port = 3000
        description = "Git 저장소"
    }
    "dsm" = @{
        subdomain = "dsm.crossman.synology.me"
        external_port = 5001
        internal_port = 5001
        description = "NAS 관리"
    }
}

# DSM 연결 설정
$DSM_HOST = $env:DSM_HOST ?? "192.168.0.5"
$DSM_PORT = $env:DSM_PORT ?? "5001"
$DSM_USER = $env:DSM_USER ?? "crossman"
$DSM_PASS = $env:DSM_PASS

# DSM 세션 변수
$script:DSM_SID = $null

# SSL 인증서 검증 비활성화 (자체 서명 인증서용)
if (-not ([System.Management.Automation.PSTypeName]'TrustAllCertsPolicy').Type) {
    Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
}

# DSM API 로그인
function Connect-DSM {
    Write-LogStep "DSM API 로그인 중..."
    
    if (-not $DSM_PASS) {
        $securePass = Read-Host "DSM 비밀번호를 입력하세요" -AsSecureString
        $DSM_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass))
    }
    
    $loginUrl = "https://${DSM_HOST}:${DSM_PORT}/webapi/auth.cgi"
    $loginData = @{
        api = "SYNO.API.Auth"
        version = 3
        method = "login"
        account = $DSM_USER
        passwd = $DSM_PASS
        session = "PortalManager"
        format = "cookie"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $loginUrl -Method Post -Body $loginData -ContentType "application/x-www-form-urlencoded"
        
        if ($response.success -eq $true) {
            $script:DSM_SID = $response.data.sid
            Write-LogSuccess "DSM 로그인 성공 (SID: $($script:DSM_SID.Substring(0,10))...)"
            return $true
        } else {
            Write-LogError "DSM 로그인 실패: $($response.error.code)"
            return $false
        }
    } catch {
        Write-LogError "DSM 연결 실패: $($_.Exception.Message)"
        return $false
    }
}

# DSM API 로그아웃
function Disconnect-DSM {
    if ($script:DSM_SID) {
        $logoutUrl = "https://${DSM_HOST}:${DSM_PORT}/webapi/auth.cgi"
        $logoutData = @{
            api = "SYNO.API.Auth"
            version = 1
            method = "logout"
            session = "PortalManager"
        }
        
        try {
            $headers = @{ Cookie = "_sid_=$($script:DSM_SID)" }
            Invoke-RestMethod -Uri $logoutUrl -Method Post -Body $logoutData -Headers $headers -ContentType "application/x-www-form-urlencoded" | Out-Null
            Write-LogInfo "DSM 로그아웃 완료"
        } catch {
            Write-LogWarn "로그아웃 중 오류 발생: $($_.Exception.Message)"
        }
    }
}

# 리버스 프록시 규칙 조회
function Get-ReverseProxyRules {
    Write-LogStep "기존 리버스 프록시 규칙 조회 중..."
    
    $apiUrl = "https://${DSM_HOST}:${DSM_PORT}/webapi/entry.cgi"
    $headers = @{ Cookie = "_sid_=$($script:DSM_SID)" }
    $params = @{
        api = "SYNO.Core.Portal.ReverseProxy"
        version = 1
        method = "list"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers -Body $params
        
        if ($response.success -eq $true) {
            foreach ($rule in $response.data.records) {
                Write-Host "$($rule.id): $($rule.source_scheme)://$($rule.source_host):$($rule.source_port) -> $($rule.dest_scheme)://$($rule.dest_host):$($rule.dest_port)"
            }
            return $true
        } else {
            Write-LogError "리버스 프록시 규칙 조회 실패: $($response.error.code)"
            return $false
        }
    } catch {
        Write-LogError "API 호출 실패: $($_.Exception.Message)"
        return $false
    }
}

# 리버스 프록시 규칙 추가
function Add-ReverseProxyRule {
    param([string]$ServiceName)
    
    if (-not $SubdomainConfig.ContainsKey($ServiceName)) {
        Write-LogError "알 수 없는 서비스: $ServiceName"
        return $false
    }
    
    $config = $SubdomainConfig[$ServiceName]
    
    Write-LogStep "리버스 프록시 규칙 추가: $ServiceName"
    Write-LogInfo "  서브도메인: $($config.subdomain)"
    Write-LogInfo "  외부 포트: $($config.external_port)"
    Write-LogInfo "  내부 포트: $($config.internal_port)"
    
    $apiUrl = "https://${DSM_HOST}:${DSM_PORT}/webapi/entry.cgi"
    $headers = @{ Cookie = "_sid_=$($script:DSM_SID)" }
    $data = @{
        api = "SYNO.Core.Portal.ReverseProxy"
        version = 1
        method = "create"
        source_scheme = "https"
        source_host = $config.subdomain
        source_port = 443
        dest_scheme = "http"
        dest_host = "localhost"
        dest_port = $config.internal_port
        enable_websocket = "true"
        enable_http2 = "true"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $data -ContentType "application/x-www-form-urlencoded"
        
        if ($response.success -eq $true) {
            Write-LogSuccess "리버스 프록시 규칙 추가 성공: $ServiceName"
            return $true
        } else {
            Write-LogError "리버스 프록시 규칙 추가 실패: $($response.error.code)"
            return $false
        }
    } catch {
        Write-LogError "API 호출 실패: $($_.Exception.Message)"
        return $false
    }
}

# 리버스 프록시 규칙 삭제
function Remove-ReverseProxyRule {
    param([string]$RuleId)
    
    if (-not $RuleId) {
        Write-LogError "규칙 ID가 필요합니다"
        return $false
    }
    
    Write-LogStep "리버스 프록시 규칙 삭제: ID $RuleId"
    
    $apiUrl = "https://${DSM_HOST}:${DSM_PORT}/webapi/entry.cgi"
    $headers = @{ Cookie = "_sid_=$($script:DSM_SID)" }
    $data = @{
        api = "SYNO.Core.Portal.ReverseProxy"
        version = 1
        method = "delete"
        id = $RuleId
    }
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Headers $headers -Body $data -ContentType "application/x-www-form-urlencoded"
        
        if ($response.success -eq $true) {
            Write-LogSuccess "리버스 프록시 규칙 삭제 성공: ID $RuleId"
            return $true
        } else {
            Write-LogError "리버스 프록시 규칙 삭제 실패: $($response.error.code)"
            return $false
        }
    } catch {
        Write-LogError "API 호출 실패: $($_.Exception.Message)"
        return $false
    }
}

# 모든 서브도메인 설정
function Set-AllSubdomains {
    Write-LogStep "모든 서브도메인 리버스 프록시 설정 시작"
    
    $successCount = 0
    $totalCount = $SubdomainConfig.Count
    
    foreach ($service in $SubdomainConfig.Keys) {
        if (Add-ReverseProxyRule $service) {
            $successCount++
        }
        Start-Sleep -Seconds 1  # API 호출 간격
    }
    
    Write-LogInfo "설정 완료: $successCount/$totalCount 성공"
    
    if ($successCount -eq $totalCount) {
        Write-LogSuccess "모든 서브도메인 설정 완료!"
    } else {
        Write-LogWarn "일부 서브도메인 설정 실패. 로그를 확인하세요."
    }
}

# 서브도메인 상태 확인
function Test-SubdomainStatus {
    Write-LogStep "서브도메인 접속 상태 확인"
    
    foreach ($service in $SubdomainConfig.Keys) {
        $config = $SubdomainConfig[$service]
        
        Write-LogInfo "🔍 $service ($($config.subdomain)) 확인 중..."
        
        # HTTPS 접속 테스트
        try {
            $httpsTest = Invoke-WebRequest -Uri "https://$($config.subdomain)" -TimeoutSec 5 -UseBasicParsing
            Write-LogSuccess "  ✅ HTTPS 접속 가능"
        } catch {
            Write-LogWarn "  ❌ HTTPS 접속 실패"
        }
        
        # 내부 포트 테스트
        try {
            $internalTest = Invoke-WebRequest -Uri "http://localhost:$($config.internal_port)" -TimeoutSec 5 -UseBasicParsing
            Write-LogSuccess "  ✅ 내부 서비스 동작 중 (포트 $($config.internal_port))"
        } catch {
            Write-LogWarn "  ⚠️  내부 서비스 미동작 (포트 $($config.internal_port))"
        }
    }
}

# 도움말 출력
function Show-Help {
    Write-Host "시놀로지 NAS 리버스 프록시 서브도메인 관리 (PowerShell)" -ForegroundColor Cyan
    Write-Host "======================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "사용법: .\reverse-proxy-manager.ps1 -Command <명령어> [-Parameter <값>]" -ForegroundColor White
    Write-Host ""
    Write-Host "명령어:" -ForegroundColor Yellow
    Write-Host "  list                   - 기존 리버스 프록시 규칙 조회"
    Write-Host "  add                    - 특정 서비스 서브도메인 추가 (-Parameter <서비스명>)"
    Write-Host "  delete                 - 특정 규칙 삭제 (-Parameter <규칙ID>)"
    Write-Host "  setup-all              - 모든 서브도메인 설정"
    Write-Host "  status                 - 서브도메인 접속 상태 확인"
    Write-Host "  help                   - 이 도움말 출력"
    Write-Host ""
    Write-Host "지원 서비스:" -ForegroundColor Yellow
    foreach ($service in $SubdomainConfig.Keys) {
        $config = $SubdomainConfig[$service]
        Write-Host "  $service - $($config.subdomain) (외부:$($config.external_port) -> 내부:$($config.internal_port)) - $($config.description)"
    }
    Write-Host ""
    Write-Host "환경변수:" -ForegroundColor Yellow
    Write-Host "  DSM_HOST  - DSM 호스트 주소 (기본값: 192.168.0.5)"
    Write-Host "  DSM_PORT  - DSM 포트 번호 (기본값: 5001)"
    Write-Host "  DSM_USER  - DSM 사용자명 (기본값: crossman)"
    Write-Host "  DSM_PASS  - DSM 비밀번호 (입력 프롬프트에서 설정 가능)"
    Write-Host ""
    Write-Host "예제:" -ForegroundColor Green
    Write-Host "  .\reverse-proxy-manager.ps1 -Command list"
    Write-Host "  .\reverse-proxy-manager.ps1 -Command add -Parameter n8n"
    Write-Host "  .\reverse-proxy-manager.ps1 -Command setup-all"
}

# 메인 실행 로직
switch ($Command) {
    "list" {
        if (Connect-DSM) {
            Get-ReverseProxyRules
            Disconnect-DSM
        }
    }
    "add" {
        if (-not $Parameter) {
            Write-LogError "서비스명이 필요합니다. 예: -Command add -Parameter n8n"
            exit 1
        }
        if (Connect-DSM) {
            Add-ReverseProxyRule $Parameter
            Disconnect-DSM
        }
    }
    "delete" {
        if (-not $Parameter) {
            Write-LogError "규칙 ID가 필요합니다. 예: -Command delete -Parameter 1"
            exit 1
        }
        if (Connect-DSM) {
            Remove-ReverseProxyRule $Parameter
            Disconnect-DSM
        }
    }
    "setup-all" {
        if (Connect-DSM) {
            Set-AllSubdomains
            Disconnect-DSM
        }
    }
    "status" {
        Test-SubdomainStatus
    }
    "help" {
        Show-Help
    }
    default {
        Write-LogError "알 수 없는 명령어: $Command"
        Show-Help
        exit 1
    }
}
