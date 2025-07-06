# CPSE 프로젝트 - VPN 네트워크 연결 상태 점검 스크립트 (PowerShell)
# Version: 2.0.0
# Description: OpenVPN을 통한 NAS 및 서비스 연결 상태 자동 점검 및 진단

param(
  [Parameter()][ValidateSet('check','monitor','report','fix')]$action = 'check',
  [switch]$continuous,
  [int]$interval = 60,
  [switch]$verbose,
  [string]$logFile
)

# 색상 출력 함수
function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    $colors = @{
        "Red" = "Red"; "Green" = "Green"; "Yellow" = "Yellow"
        "Blue" = "Blue"; "Magenta" = "Magenta"; "Cyan" = "Cyan"
    }
    Write-Host $Text -ForegroundColor $colors[$Color]
    
    # 로그 파일에도 기록
    if ($logFile) {
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Text" | Add-Content $logFile
    }
}

function Write-Info { Write-ColorText "[INFO] $args" "Green" }
function Write-Warn { Write-ColorText "[WARN] $args" "Yellow" }
function Write-Error { Write-ColorText "[ERROR] $args" "Red" }
function Write-Step { Write-ColorText "[STEP] $args" "Blue" }
function Write-Success { Write-ColorText "[SUCCESS] $args" "Magenta" }

# 환경 설정 로드
$envPath = "../../config/env-info.json"
if (Test-Path $envPath) {
    try {
        $envInfo = Get-Content $envPath -Raw | ConvertFrom-Json
    } catch {
        Write-Error "환경 설정 파일 읽기 오류: $_"
        exit 1
    }
} else {
    Write-Error "환경 설정 파일을 찾을 수 없습니다: $envPath"
    exit 1
}

# 기본 로그 파일 설정
if (!$logFile) {
    $logFile = "../../logs/vpn-check-$(Get-Date -Format 'yyyyMMdd').log"
}

# 점검 대상 정의
$targets = @(
    @{ Name = "NAS DSM"; Address = $envInfo.nas.internal_ip; Port = 5000; Type = "HTTP" },
    @{ Name = "NAS SSH"; Address = $envInfo.nas.internal_ip; Port = 22; Type = "TCP" }
)

# 서비스별 점검 대상 추가
foreach ($svcName in $envInfo.services.PSObject.Properties.Name) {
    $service = $envInfo.services.$svcName
    $targets += @{
        Name = "$svcName"; 
        Address = $envInfo.nas.internal_ip; 
        Port = $service.port; 
        Type = "HTTP";
        URL = "https://$($service.subdomain)"
    }
}

# 연결 테스트 함수
function Test-ServiceConnection {
    param($Target)
    
    $result = @{
        Name = $Target.Name
        Status = "UNKNOWN"
        ResponseTime = 0
        Details = ""
    }
    
    try {
        if ($Target.Type -eq "HTTP" -and $Target.URL) {
            # HTTP/HTTPS 테스트
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $response = Invoke-WebRequest -Uri $Target.URL -TimeoutSec 10 -UseBasicParsing
                $stopwatch.Stop()
                $result.ResponseTime = $stopwatch.ElapsedMilliseconds
                $result.Status = if ($response.StatusCode -eq 200) { "OK" } else { "WARN" }
                $result.Details = "HTTP $($response.StatusCode)"
            } catch {
                $stopwatch.Stop()
                $result.Status = "FAIL"
                $result.Details = $_.Exception.Message
            }
        } else {
            # TCP 포트 테스트
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $connectTask = $tcpClient.ConnectAsync($Target.Address, $Target.Port)
                $timeout = [System.Threading.Tasks.Task]::Delay(5000)
                $completedTask = [System.Threading.Tasks.Task]::WaitAny($connectTask, $timeout)
                
                if ($completedTask -eq 0 -and $tcpClient.Connected) {
                    $stopwatch.Stop()
                    $result.Status = "OK"
                    $result.ResponseTime = $stopwatch.ElapsedMilliseconds
                    $result.Details = "TCP Connected"
                } else {
                    $result.Status = "FAIL"
                    $result.Details = "Connection Timeout"
                }
                $tcpClient.Close()
            } catch {
                $result.Status = "FAIL"
                $result.Details = $_.Exception.Message
            }
        }
    } catch {
        $result.Status = "FAIL"
        $result.Details = "Unexpected error: $($_.Exception.Message)"
    }
    
    return $result
}

# VPN 연결 상태 확인
function Test-VPNConnection {
    $vpnStatus = @{
        Connected = $false
        Interface = ""
        IP = ""
        Details = ""
    }
    
    try {
        # TAP 어댑터 확인 (OpenVPN)
        $tapAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like "*TAP*" -or $_.Name -like "*OpenVPN*" }
        
        if ($tapAdapters) {
            foreach ($adapter in $tapAdapters) {
                if ($adapter.Status -eq "Up") {
                    $vpnStatus.Connected = $true
                    $vpnStatus.Interface = $adapter.Name
                    
                    # IP 주소 확인
                    $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
                    if ($ipConfig) {
                        $vpnStatus.IP = $ipConfig.IPAddress
                    }
                    break
                }
            }
        }
        
        $vpnStatus.Details = if ($vpnStatus.Connected) { 
            "Connected via $($vpnStatus.Interface) ($($vpnStatus.IP))" 
        } else { 
            "No active VPN connection found" 
        }
        
    } catch {
        $vpnStatus.Details = "VPN check error: $($_.Exception.Message)"
    }
    
    return $vpnStatus
}

# 네트워크 진단 실행
function Start-NetworkDiagnostics {
    Write-Step "네트워크 진단 시작"
    
    # VPN 연결 상태 확인
    $vpnStatus = Test-VPNConnection
    Write-Step "VPN 연결 상태: $($vpnStatus.Details)"
    
    if (!$vpnStatus.Connected) {
        Write-Warn "VPN이 연결되지 않았습니다. 일부 서비스에 접근할 수 없을 수 있습니다."
    }
    
    # 서비스 연결 테스트
    $results = @()
    $successCount = 0
    
    foreach ($target in $targets) {
        if ($verbose) {
            Write-Step "테스트 중: $($target.Name) ($($target.Address):$($target.Port))"
        }
        
        $result = Test-ServiceConnection $target
        $results += $result
        
        $statusColor = switch ($result.Status) {
            "OK" { "Green"; $successCount++ }
            "WARN" { "Yellow" }
            "FAIL" { "Red" }
            default { "White" }
        }
        
        $responseInfo = if ($result.ResponseTime -gt 0) { " ($($result.ResponseTime)ms)" } else { "" }
        Write-ColorText "  - $($result.Name): $($result.Status)$responseInfo - $($result.Details)" $statusColor
    }
    
    # 요약 정보
    Write-Step "점검 완료: $successCount/$($targets.Count) 서비스 정상"
    
    return @{
        VPN = $vpnStatus
        Services = $results
        Summary = @{
            Total = $targets.Count
            Success = $successCount
            Failed = $targets.Count - $successCount
        }
    }
}

# 지속적 모니터링
function Start-ContinuousMonitoring {
    Write-Info "지속적 모니터링 시작 (간격: $interval 초)"
    Write-Info "종료하려면 Ctrl+C를 누르세요"
    
    try {
        while ($true) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Step "[$timestamp] 네트워크 상태 점검"
            
            $diagnostics = Start-NetworkDiagnostics
            
            # 문제 감지시 알림
            if ($diagnostics.Summary.Failed -gt 0) {
                Write-Warn "⚠️  $($diagnostics.Summary.Failed)개 서비스에 문제가 감지되었습니다!"
            } else {
                Write-Success "✅ 모든 서비스가 정상 작동 중입니다"
            }
            
            Start-Sleep $interval
        }
    } catch {
        Write-Info "모니터링이 중단되었습니다"
    }
}

# 보고서 생성
function New-DiagnosticsReport {
    $diagnostics = Start-NetworkDiagnostics
    $reportPath = "../../logs/network-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    
    $report = @{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        VPN = $diagnostics.VPN
        Services = $diagnostics.Services
        Summary = $diagnostics.Summary
        Environment = @{
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            OS = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption
        }
    }
    
    try {
        $report | ConvertTo-Json -Depth 4 | Set-Content $reportPath
        Write-Info "진단 보고서 생성 완료: $reportPath"
    } catch {
        Write-Error "보고서 생성 오류: $_"
    }
    
    return $report
}

# 메인 실행 로직
switch ($action) {
    'check' {
        if ($continuous) {
            Start-ContinuousMonitoring
        } else {
            Start-NetworkDiagnostics | Out-Null
        }
    }
    
    'monitor' {
        Start-ContinuousMonitoring
    }
    
    'report' {
        New-DiagnosticsReport | Out-Null
    }
    
    'fix' {
        Write-Step "네트워크 연결 문제 자동 복구 시도"
        
        # 기본적인 네트워크 복구 시도
        try {
            Write-Info "DNS 캐시 플러시"
            ipconfig /flushdns | Out-Null
            
            Write-Info "네트워크 어댑터 새로고침"
            Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Restart-NetAdapter -Confirm:$false
            
            Start-Sleep 5
            
            Write-Info "복구 후 연결 테스트"
            Start-NetworkDiagnostics | Out-Null
            
        } catch {
            Write-Error "자동 복구 중 오류 발생: $_"
        }
    }
}