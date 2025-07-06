# n8n + MCP 운영 매뉴얼 📚
## 자동화 스크립트 + 장애대응 + 현행화 가이드

---

## 🎯 매뉴얼 개요
- **목적**: n8n + MCP 환경의 안정적 운영 및 유지보수
- **대상**: Windows 11, 8GB 메모리 환경
- **버전**: v1.0 (2025.06.16 기준)
- **업데이트 주기**: 월 1회 현행화 체크

---

## 📋 목차
1. [자동화 스크립트 모음](#1-자동화-스크립트-모음)
2. [헬스체크 및 모니터링](#2-헬스체크-및-모니터링)
3. [장애 대응 매뉴얼](#3-장애-대응-매뉴얼)
4. [백업 및 복구](#4-백업-및-복구)
5. [현행화 및 업데이트](#5-현행화-및-업데이트)
6. [성능 최적화](#6-성능-최적화)
7. [문제해결 FAQ](#7-문제해결-faq)

---

## 1. 자동화 스크립트 모음

### 1-1. 올인원 시작 스크립트

**start-n8n-environment.ps1**
```powershell
<#
.SYNOPSIS
n8n + MCP 환경 자동 시작 스크립트
.DESCRIPTION
모든 서비스를 순차적으로 시작하고 상태를 확인합니다
.AUTHOR
무무와 클로드
.VERSION
1.0
#>

param(
    [switch]$SkipHealthCheck,
    [switch]$Verbose
)

# 설정
$PROJECT_ROOT = "C:\dev\n8n-mcp-workspace"
$LOG_FILE = "$PROJECT_ROOT\logs\startup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LOG_FILE -Value $logMessage
}

function Test-DockerRunning {
    try {
        docker version | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-ServiceHealth {
    param($ServiceName, $Url, $ExpectedStatusCode = 200)
    
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq $ExpectedStatusCode) {
            Write-Log "$ServiceName is healthy (Status: $($response.StatusCode))" "SUCCESS"
            return $true
        } else {
            Write-Log "$ServiceName returned unexpected status: $($response.StatusCode)" "WARNING"
            return $false
        }
    } catch {
        Write-Log "$ServiceName health check failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# 메인 실행
Write-Log "=== n8n + MCP 환경 시작 ===" "INFO"

# 1. 사전 확인
Write-Log "Docker 상태 확인 중..." "INFO"
if (-not (Test-DockerRunning)) {
    Write-Log "Docker Desktop을 시작하는 중..." "INFO"
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden
    
    $timeout = 60
    $timer = 0
    while (-not (Test-DockerRunning) -and $timer -lt $timeout) {
        Start-Sleep 2
        $timer += 2
        Write-Progress -Activity "Docker 시작 대기" -Status "$timer/$timeout 초" -PercentComplete (($timer / $timeout) * 100)
    }
    
    if (-not (Test-DockerRunning)) {
        Write-Log "Docker 시작 실패. 수동으로 Docker Desktop을 실행해주세요." "ERROR"
        exit 1
    }
}

# 2. 프로젝트 디렉토리로 이동
Set-Location $PROJECT_ROOT
Write-Log "작업 디렉토리: $(Get-Location)" "INFO"

# 3. Docker Compose 실행
Write-Log "Docker Compose 서비스 시작 중..." "INFO"
try {
    docker-compose up -d
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Docker 서비스 시작 완료" "SUCCESS"
    } else {
        Write-Log "Docker 서비스 시작 실패" "ERROR"
        exit 1
    }
} catch {
    Write-Log "Docker Compose 실행 실패: $($_.Exception.Message)" "ERROR"
    exit 1
}

# 4. MCP 서버 시작
Write-Log "MCP 서버 시작 중..." "INFO"
try {
    Set-Location "$PROJECT_ROOT\mcp-servers"
    
    # 백그라운드에서 MCP 서버 실행
    $mcpJob = Start-Job -ScriptBlock {
        Set-Location $args[0]
        npx @modelcontextprotocol/server-filesystem --allowed-path "$($args[0])\..\local-files" --port 3001 --host 0.0.0.0
    } -ArgumentList $PROJECT_ROOT\mcp-servers
    
    Write-Log "MCP 서버 백그라운드 실행 (Job ID: $($mcpJob.Id))" "SUCCESS"
    
} catch {
    Write-Log "MCP 서버 시작 실패: $($_.Exception.Message)" "ERROR"
}

# 5. 헬스체크 (옵션)
if (-not $SkipHealthCheck) {
    Write-Log "서비스 헬스체크 시작..." "INFO"
    Start-Sleep 15  # 서비스 초기화 대기
    
    $healthResults = @{
        "n8n" = (Test-ServiceHealth "n8n" "http://localhost:5678")
        "MCP Server" = (Test-ServiceHealth "MCP Server" "http://localhost:3001" -ExpectedStatusCode 404)  # MCP는 404가 정상
    }
    
    $healthyServices = ($healthResults.Values | Where-Object { $_ -eq $true }).Count
    $totalServices = $healthResults.Count
    
    Write-Log "헬스체크 완료: $healthyServices/$totalServices 서비스 정상" "INFO"
    
    if ($healthyServices -eq $totalServices) {
        Write-Log "모든 서비스가 정상 동작 중입니다!" "SUCCESS"
        
        # 브라우저에서 n8n 열기
        Start-Process "http://localhost:5678"
        
    } else {
        Write-Log "일부 서비스에 문제가 있습니다. 로그를 확인해주세요." "WARNING"
    }
}

# 6. 실행 상태 요약
Write-Log "=== 환경 시작 완료 ===" "INFO"
Write-Log "n8n 웹 인터페이스: http://localhost:5678" "INFO"
Write-Log "로그 파일: $LOG_FILE" "INFO"
Write-Log "ID: admin, PW: changeme123" "INFO"

Set-Location $PROJECT_ROOT
```

### 1-2. 환경 정리 스크립트

**cleanup-n8n-environment.ps1**
```powershell
<#
.SYNOPSIS
n8n + MCP 환경 안전 종료 및 정리 스크립트
.DESCRIPTION
모든 서비스를 안전하게 종료하고 시스템 리소스를 정리합니다
#>

param(
    [switch]$DeepClean,
    [switch]$PreserveData
)

$PROJECT_ROOT = "C:\dev\n8n-mcp-workspace"
$LOG_FILE = "$PROJECT_ROOT\logs\cleanup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $LOG_FILE -Value $logMessage
}

Write-Log "=== n8n + MCP 환경 정리 시작 ===" "INFO"

Set-Location $PROJECT_ROOT

# 1. MCP 서버 프로세스 종료
Write-Log "MCP 서버 프로세스 종료 중..." "INFO"
Get-Job | Where-Object { $_.Name -like "*mcp*" -or $_.Command -like "*server-filesystem*" } | Stop-Job -PassThru | Remove-Job
Get-Process | Where-Object { $_.ProcessName -eq "node" -and $_.MainWindowTitle -like "*mcp*" } | Stop-Process -Force

# 2. Docker Compose 서비스 종료
Write-Log "Docker 서비스 종료 중..." "INFO"
docker-compose down

if ($DeepClean) {
    Write-Log "딥 클린 모드: Docker 이미지 및 캐시 정리..." "INFO"
    docker system prune -f
    docker volume prune -f
}

# 3. 로그 정리 (30일 이상 된 로그 삭제)
Write-Log "오래된 로그 파일 정리 중..." "INFO"
$cutoffDate = (Get-Date).AddDays(-30)
Get-ChildItem "$PROJECT_ROOT\logs" -Filter "*.log" | Where-Object { $_.CreationTime -lt $cutoffDate } | Remove-Item -Force

# 4. 임시 파일 정리
Write-Log "임시 파일 정리 중..." "INFO"
Remove-Item "$PROJECT_ROOT\local-files\temp\*" -Recurse -Force -ErrorAction SilentlyContinue

Write-Log "=== 환경 정리 완료 ===" "SUCCESS"
```

### 1-3. 백업 자동화 스크립트

**backup-n8n-data.ps1**
```powershell
<#
.SYNOPSIS
n8n 데이터 자동 백업 스크립트
.DESCRIPTION
n8n 워크플로우, 설정, 데이터를 자동으로 백업합니다
#>

param(
    [switch]$FullBackup,
    [string]$BackupPath = "C:\dev\n8n-backups"
)

$PROJECT_ROOT = "C:\dev\n8n-mcp-workspace"
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$BACKUP_DIR = "$BackupPath\backup-$TIMESTAMP"

function Write-Log {
    param($Message, $Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# 백업 디렉토리 생성
New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
Write-Log "백업 시작: $BACKUP_DIR" "INFO"

# 1. n8n 데이터 백업
Write-Log "n8n 데이터 백업 중..." "INFO"
docker-compose exec -T n8n n8n export:workflow --output=/files/workflows-backup-$TIMESTAMP.json --all
docker-compose exec -T n8n n8n export:credentials --output=/files/credentials-backup-$TIMESTAMP.json --all

# 2. 설정 파일 백업
Write-Log "설정 파일 백업 중..." "INFO"
Copy-Item "$PROJECT_ROOT\docker-compose.yml" "$BACKUP_DIR\" -Force
Copy-Item "$PROJECT_ROOT\configs" "$BACKUP_DIR\configs" -Recurse -Force

# 3. 사용자 파일 백업
Write-Log "사용자 파일 백업 중..." "INFO"
Copy-Item "$PROJECT_ROOT\local-files" "$BACKUP_DIR\local-files" -Recurse -Force

# 4. 전체 백업 (옵션)
if ($FullBackup) {
    Write-Log "Docker 볼륨 백업 중..." "INFO"
    docker run --rm -v n8n-mcp-workspace_n8n_data:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/n8n-volume-$TIMESTAMP.tar.gz -C /data .
}

# 5. 백업 검증
$backupSize = (Get-ChildItem $BACKUP_DIR -Recurse | Measure-Object -Property Length -Sum).Sum
Write-Log "백업 완료 (크기: $([math]::Round($backupSize/1MB, 2)) MB)" "SUCCESS"

# 6. 오래된 백업 정리 (14일 이상)
$cutoffDate = (Get-Date).AddDays(-14)
Get-ChildItem $BackupPath -Directory | Where-Object { $_.Name -like "backup-*" -and $_.CreationTime -lt $cutoffDate } | Remove-Item -Recurse -Force
Write-Log "오래된 백업 정리 완료" "INFO"
```

---

## 2. 헬스체크 및 모니터링

### 2-1. 실시간 모니터링 스크립트

**monitor-n8n-health.ps1**
```powershell
<#
.SYNOPSIS
n8n + MCP 환경 실시간 모니터링
.DESCRIPTION
시스템 리소스와 서비스 상태를 실시간으로 모니터링합니다
#>

param(
    [int]$IntervalSeconds = 30,
    [switch]$AlertMode
)

function Get-SystemMetrics {
    $memory = Get-CimInstance -ClassName Win32_OperatingSystem
    $cpu = Get-CimInstance -ClassName Win32_Processor
    
    $totalRAM = [math]::Round($memory.TotalVisibleMemorySize / 1MB, 2)
    $freeRAM = [math]::Round($memory.FreePhysicalMemory / 1MB, 2)
    $usedRAM = [math]::Round($totalRAM - $freeRAM, 2)
    $ramUsagePercent = [math]::Round(($usedRAM / $totalRAM) * 100, 1)
    
    return @{
        RAMTotal = $totalRAM
        RAMUsed = $usedRAM
        RAMFree = $freeRAM
        RAMUsagePercent = $ramUsagePercent
        Timestamp = Get-Date
    }
}

function Get-DockerMetrics {
    try {
        $stats = docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | ConvertFrom-Csv -Delimiter "`t"
        return $stats
    } catch {
        return $null
    }
}

function Test-Services {
    $services = @{
        "n8n" = @{ URL = "http://localhost:5678"; ExpectedStatus = 200 }
        "MCP" = @{ URL = "http://localhost:3001"; ExpectedStatus = 404 }
    }
    
    $results = @{}
    foreach ($service in $services.Keys) {
        try {
            $response = Invoke-WebRequest -Uri $services[$service].URL -TimeoutSec 5 -UseBasicParsing
            $results[$service] = ($response.StatusCode -eq $services[$service].ExpectedStatus)
        } catch {
            $results[$service] = $false
        }
    }
    
    return $results
}

# 메인 모니터링 루프
Write-Host "=== n8n + MCP 시스템 모니터링 시작 ===" -ForegroundColor Green
Write-Host "모니터링 간격: $IntervalSeconds 초" -ForegroundColor Yellow
Write-Host "중지하려면 Ctrl+C를 누르세요" -ForegroundColor Yellow
Write-Host ""

while ($true) {
    Clear-Host
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "=== 시스템 상태 ($timestamp) ===" -ForegroundColor Cyan
    
    # 시스템 메트릭
    $metrics = Get-SystemMetrics
    Write-Host "💻 시스템 리소스:" -ForegroundColor Green
    Write-Host "   RAM: $($metrics.RAMUsed)GB / $($metrics.RAMTotal)GB ($($metrics.RAMUsagePercent)%)" -ForegroundColor White
    
    if ($metrics.RAMUsagePercent -gt 80) {
        Write-Host "   ⚠️  메모리 사용량 높음!" -ForegroundColor Red
    }
    
    # Docker 컨테이너 상태
    Write-Host ""
    Write-Host "🐳 Docker 컨테이너:" -ForegroundColor Green
    $dockerStats = Get-DockerMetrics
    if ($dockerStats) {
        $dockerStats | Format-Table -AutoSize
    } else {
        Write-Host "   Docker 상태를 가져올 수 없습니다" -ForegroundColor Red
    }
    
    # 서비스 헬스체크
    Write-Host ""
    Write-Host "🔍 서비스 상태:" -ForegroundColor Green
    $serviceStatus = Test-Services
    foreach ($service in $serviceStatus.Keys) {
        $status = if ($serviceStatus[$service]) { "✅ 정상" } else { "❌ 오류" }
        $color = if ($serviceStatus[$service]) { "Green" } else { "Red" }
        Write-Host "   $service : $status" -ForegroundColor $color
    }
    
    # 알림 모드
    if ($AlertMode) {
        $unhealthyServices = $serviceStatus.Values | Where-Object { $_ -eq $false }
        if ($unhealthyServices.Count -gt 0 -or $metrics.RAMUsagePercent -gt 85) {
            [System.Media.SystemSounds]::Exclamation.Play()
        }
    }
    
    Write-Host ""
    Write-Host "다음 업데이트까지 $IntervalSeconds 초..." -ForegroundColor Gray
    
    Start-Sleep $IntervalSeconds
}
```

### 2-2. 로그 분석 스크립트

**analyze-logs.ps1**
```powershell
<#
.SYNOPSIS
n8n 로그 분석 및 이상 탐지
.DESCRIPTION
로그 파일을 분석하여 에러, 경고, 성능 이슈를 탐지합니다
#>

param(
    [string]$LogPath = "C:\dev\n8n-mcp-workspace\logs",
    [int]$LastHours = 24
)

$cutoffTime = (Get-Date).AddHours(-$LastHours)

function Analyze-Logs {
    param($LogFile)
    
    $content = Get-Content $LogFile
    $errors = $content | Where-Object { $_ -match "\[ERROR\]" }
    $warnings = $content | Where-Object { $_ -match "\[WARNING\]" }
    $performance = $content | Where-Object { $_ -match "timeout|slow|memory" }
    
    return @{
        File = $LogFile
        TotalLines = $content.Count
        Errors = $errors.Count
        Warnings = $warnings.Count
        PerformanceIssues = $performance.Count
        ErrorDetails = $errors | Select-Object -First 5
        WarningDetails = $warnings | Select-Object -First 5
    }
}

# 로그 파일 분석
$logFiles = Get-ChildItem $LogPath -Filter "*.log" | Where-Object { $_.LastWriteTime -gt $cutoffTime }

Write-Host "=== 로그 분석 결과 (최근 $LastHours 시간) ===" -ForegroundColor Cyan

foreach ($logFile in $logFiles) {
    $analysis = Analyze-Logs $logFile.FullName
    
    Write-Host ""
    Write-Host "📄 $($analysis.File)" -ForegroundColor Yellow
    Write-Host "   총 라인: $($analysis.TotalLines)"
    Write-Host "   에러: $($analysis.Errors)" -ForegroundColor $(if($analysis.Errors -gt 0) {"Red"} else {"Green"})
    Write-Host "   경고: $($analysis.Warnings)" -ForegroundColor $(if($analysis.Warnings -gt 0) {"Yellow"} else {"Green"})
    Write-Host "   성능 이슈: $($analysis.PerformanceIssues)" -ForegroundColor $(if($analysis.PerformanceIssues -gt 0) {"Red"} else {"Green"})
    
    if ($analysis.ErrorDetails.Count -gt 0) {
        Write-Host "   최근 에러 샘플:"
        $analysis.ErrorDetails | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
    }
}

# Docker 로그 분석
Write-Host ""
Write-Host "🐳 Docker 컨테이너 로그 분석:" -ForegroundColor Green

try {
    $n8nLogs = docker-compose logs --tail=100 n8n | Out-String
    $errorCount = ($n8nLogs -split "`n" | Where-Object { $_ -match "error|ERROR|Error" }).Count
    $warningCount = ($n8nLogs -split "`n" | Where-Object { $_ -match "warn|WARNING|Warning" }).Count
    
    Write-Host "   n8n 컨테이너 - 에러: $errorCount, 경고: $warningCount"
    
    if ($errorCount -gt 0) {
        Write-Host "   최근 에러:" -ForegroundColor Red
        $n8nLogs -split "`n" | Where-Object { $_ -match "error|ERROR|Error" } | Select-Object -First 3 | ForEach-Object {
            Write-Host "     $_" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   Docker 로그를 가져올 수 없습니다" -ForegroundColor Red
}
```

---

## 3. 장애 대응 매뉴얼

### 3-1. 일반적인 장애 상황별 대응

#### 🚨 n8n 웹 인터페이스 접근 불가

**증상**: http://localhost:5678 에 접근할 수 없음

**1단계 - 기본 확인**
```powershell
# Docker 컨테이너 상태 확인
docker-compose ps

# n8n 컨테이너 로그 확인
docker-compose logs n8n

# 포트 사용 상황 확인
netstat -an | findstr :5678
```

**2단계 - 일반적인 해결책**
```powershell
# 컨테이너 재시작
docker-compose restart n8n

# 전체 환경 재시작
docker-compose down
docker-compose up -d

# 포트 충돌 해결 (다른 포트 사용)
# docker-compose.yml에서 ports를 "5679:5678"로 변경
```

**3단계 - 고급 트러블슈팅**
```powershell
# 컨테이너 내부 접근
docker-compose exec n8n /bin/sh

# 컨테이너 리소스 확인
docker stats n8n

# 방화벽 확인
New-NetFirewallRule -DisplayName "n8n" -Direction Inbound -Port 5678 -Protocol TCP -Action Allow
```

#### 🚨 MCP 서버 연결 실패

**증상**: n8n에서 MCP 서버에 연결할 수 없음

**진단 스크립트**:
```powershell
# MCP 서버 프로세스 확인
Get-Process | Where-Object { $_.ProcessName -eq "node" }

# MCP 포트 확인
Test-NetConnection -ComputerName localhost -Port 3001

# MCP 서버 응답 테스트
Invoke-WebRequest -Uri "http://localhost:3001" -Method GET
```

**해결 방법**:
```powershell
# MCP 서버 재시작
Stop-Process -Name "node" -Force
cd C:\dev\n8n-mcp-workspace\mcp-servers
npx @modelcontextprotocol/server-filesystem --allowed-path "..\local-files" --port 3001 --host 0.0.0.0

# 방화벽 규칙 추가
New-NetFirewallRule -DisplayName "MCP Server" -Direction Inbound -Port 3001 -Protocol TCP -Action Allow
```

#### 🚨 메모리 부족 오류

**증상**: 시스템이 느려지거나 프로세스가 종료됨

**즉시 대응**:
```powershell
# 메모리 사용량 확인
Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 10

# Docker 메모리 제한 확인
docker stats --no-stream

# 불필요한 프로세스 종료
Stop-Process -Name "chrome", "firefox" -ErrorAction SilentlyContinue

# Docker 컨테이너 메모리 제한 조정
# docker-compose.yml의 memory 값을 1G로 감소
```

### 3-2. 자동 복구 스크립트

**auto-recovery.ps1**
```powershell
<#
.SYNOPSIS
n8n + MCP 환경 자동 복구 스크립트
.DESCRIPTION
일반적인 장애 상황을 자동으로 감지하고 복구를 시도합니다
#>

param(
    [switch]$DryRun,
    [int]$MaxRetries = 3
)

$PROJECT_ROOT = "C:\dev\n8n-mcp-workspace"
$recoveryActions = @()

function Write-Recovery {
    param($Message, $Action = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Action] $Message" -ForegroundColor $(
        switch($Action) {
            "ERROR" { "Red" }
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "RECOVERY" { "Magenta" }
            default { "White" }
        }
    )
    
    if ($Action -eq "RECOVERY") {
        $script:recoveryActions += $Message
    }
}

function Test-N8nHealth {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:5678" -TimeoutSec 5 -UseBasicParsing
        return $response.StatusCode -eq 200
    } catch {
        return $false
    }
}

function Test-McpHealth {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3001" -TimeoutSec 5 -UseBasicParsing
        return $response.StatusCode -eq 404  # MCP 서버는 404가 정상
    } catch {
        return $false
    }
}

function Recover-N8n {
    Write-Recovery "n8n 서비스 복구 시도" "RECOVERY"
    
    if (-not $DryRun) {
        # 1단계: 컨테이너 재시작
        docker-compose restart n8n
        Start-Sleep 15
        
        if (Test-N8nHealth) {
            Write-Recovery "n8n 컨테이너 재시작으로 복구 완료" "SUCCESS"
            return $true
        }
        
        # 2단계: 전체 재시작
        Write-Recovery "전체 환경 재시작 시도" "RECOVERY"
        docker-compose down
        docker-compose up -d
        Start-Sleep 30
        
        if (Test-N8nHealth) {
            Write-Recovery "전체 재시작으로 복구 완료" "SUCCESS"
            return $true
        }
        
        # 3단계: 볼륨 확인 및 복구
        Write-Recovery "볼륨 상태 확인 및 복구" "RECOVERY"
        docker volume inspect n8n-mcp-workspace_n8n_data
        
        return $false
    } else {
        Write-Recovery "[DRY RUN] n8n 복구 시뮬레이션" "WARNING"
        return $true
    }
}

function Recover-Mcp {
    Write-Recovery "MCP 서버 복구 시도" "RECOVERY"
    
    if (-not $DryRun) {
        # MCP 프로세스 종료
        Get-Process | Where-Object { $_.ProcessName -eq "node" -and $_.CommandLine -like "*server-filesystem*" } | Stop-Process -Force
        
        # MCP 서버 재시작
        Set-Location "$PROJECT_ROOT\mcp-servers"
        $mcpJob = Start-Job -Sc