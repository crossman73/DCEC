# 통합 로깅 시스템
# 모든 서비스와 모듈에서 사용할 수 있는 중앙 집중식 로깅 기능 제공
function Initialize-LoggingSystem {
    param(
        [string]$LogRoot = "D:\Dev\DCEC\Dev_Env\Core\Logs",
        [string]$ArchiveRoot = "D:\Dev\DCEC\Dev_Env\Core\Logs\Archive",
        [int]$MaxLogSizeMB = 10,
        [int]$MaxArchiveDays = 30
    )
    # 로그 디렉토리 구조 생성
    $logDirs = @(
        $LogRoot,
        $ArchiveRoot,
        "$LogRoot\Services",
        "$LogRoot\Integration",
        "$LogRoot\Backup",
        "$LogRoot\Security"
    )
    foreach ($dir in $logDirs) {
        if (!(Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force
        }
    }
    # 로깅 설정 저장
    $config = @{
        LogRoot = $LogRoot
        ArchiveRoot = $ArchiveRoot
        MaxLogSizeMB = $MaxLogSizeMB
        MaxArchiveDays = $MaxArchiveDays
        LastRotation = Get-Date -Format "yyyy-MM-dd"
    }
    $configPath = Join-Path $LogRoot "logging.config.json"
    $config | ConvertTo-Json | Set-Content $configPath
    # 글로벌 변수로 설정 저장
    $global:LoggingConfig = $config
}
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Level = "INFO",
        [string]$ServiceName = "",
        [string]$LogRoot = "D:\Dev\DCEC\Dev_Env\Core\Logs"
    )
    # 설정 로드
    if (!$global:LoggingConfig) {
        $configPath = Join-Path $LogRoot "logging.config.json"
        if (Test-Path $configPath) {
            $global:LoggingConfig = Get-Content $configPath | ConvertFrom-Json
        }
        else {
            Initialize-LoggingSystem
        }
    }
    # 로그 파일 경로 결정
    $logFile = if ($ServiceName) {
        Join-Path $global:LoggingConfig.LogRoot "Services\$ServiceName.log"
    }
    else {
        Join-Path $global:LoggingConfig.LogRoot "$Category.log"
    }
    # 로그 로테이션 체크
    if (Test-Path $logFile) {
        $logSize = (Get-Item $logFile).Length / 1MB
        if ($logSize -gt $global:LoggingConfig.MaxLogSizeMB) {
            Rotate-Log -LogFile $logFile
        }
    }
    # 타임스탬프 포맷
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    # 로그 메시지 포맷
    $logMessage = "[$timestamp] [$Level] [$Category] $Message"
    if ($ServiceName) {
        $logMessage = "[$ServiceName] $logMessage"
    }
    # 로그 파일 쓰기
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
    # 콘솔 출력 (오류 레벨일 경우 빨간색으로)
    if ($Level -eq "ERROR") {
        Write-Host $logMessage -ForegroundColor Red
    }
    elseif ($Level -eq "WARNING") {
        Write-Host $logMessage -ForegroundColor Yellow
    }
    else {
        Write-Host $logMessage
    }
}
function Rotate-Log {
    param(
        [string]$LogFile
    )
    if (!(Test-Path $LogFile)) {
        return
    }
    # 아카이브 파일명 생성
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $archiveFile = Join-Path $global:LoggingConfig.ArchiveRoot "$($LogFile | Split-Path -Leaf).$timestamp"
    # 로그 파일 이동
    Move-Item -Path $LogFile -Destination $archiveFile -Force
    # 새 로그 파일 생성
    New-Item -Path $LogFile -ItemType File -Force | Out-Null
    # 오래된 아카이브 정리
    $cutoffDate = (Get-Date).AddDays(-$global:LoggingConfig.MaxArchiveDays)
    Get-ChildItem $global:LoggingConfig.ArchiveRoot -File |
        Where-Object { $_.LastWriteTime -lt $cutoffDate } |
        Remove-Item -Force
}
function Get-LogSummary {
    param(
        [string]$Category,
        [string]$ServiceName = "",
        [DateTime]$StartTime = (Get-Date).AddHours(-24),
        [DateTime]$EndTime = (Get-Date)
    )
    # 로그 파일 결정
    $logFile = if ($ServiceName) {
        Join-Path $global:LoggingConfig.LogRoot "Services\$ServiceName.log"
    }
    else {
        Join-Path $global:LoggingConfig.LogRoot "$Category.log"
    }
    if (!(Test-Path $logFile)) {
        return @{
            TotalEntries = 0
            ErrorCount = 0
            WarningCount = 0
            InfoCount = 0
            RecentErrors = @()
        }
    }
    # 로그 분석
    $summary = @{
        TotalEntries = 0
        ErrorCount = 0
        WarningCount = 0
        InfoCount = 0
        RecentErrors = @()
    }
    Get-Content $logFile | ForEach-Object {
        if ($_ -match "\[([\d\-: .]+)\].*\[(ERROR|WARNING|INFO)\]") {
            $logTime = [DateTime]::ParseExact($matches[1], "yyyy-MM-dd HH:mm:ss.fff", $null)
            if ($logTime -ge $StartTime -and $logTime -le $EndTime) {
                $summary.TotalEntries++
                switch ($matches[2]) {
                    "ERROR" {
                        $summary.ErrorCount++
                        if ($summary.RecentErrors.Count -lt 10) {
                            $summary.RecentErrors += $_
                        }
                    }
                    "WARNING" { $summary.WarningCount++ }
                    "INFO" { $summary.InfoCount++ }
                }
            }
        }
    }
    return $summary
}
function Get-ServiceLogs {
    param(
        [string]$ServiceName,
        [int]$LastLines = 100,
        [string]$Filter = ""
    )
    $logFile = Join-Path $global:LoggingConfig.LogRoot "Services\$ServiceName.log"
    if (!(Test-Path $logFile)) {
        Write-Warning "로그 파일을 찾을 수 없습니다: $logFile"
        return @()
    }
    $logs = if ($Filter) {
        Get-Content $logFile | Where-Object { $_ -match $Filter } | Select-Object -Last $LastLines
    }
    else {
        Get-Content $logFile | Select-Object -Last $LastLines
    }
    return $logs
}
function Export-LogArchive {
    param(
        [string]$ExportPath,
        [DateTime]$StartTime = (Get-Date).AddDays(-7),
        [DateTime]$EndTime = (Get-Date)
    )
    # 임시 디렉토리 생성
    $tempDir = Join-Path $env:TEMP "LogExport_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    try {
        # 활성 로그 파일 복사
        Get-ChildItem $global:LoggingConfig.LogRoot -Recurse -File |
            Where-Object { $_.Extension -eq '.log' } |
            ForEach-Object {
                $destPath = Join-Path $tempDir $_.FullName.Substring($global:LoggingConfig.LogRoot.Length + 1)
                $destDir = Split-Path $destPath
                if (!(Test-Path $destDir)) {
                    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                }
                Copy-Item $_.FullName -Destination $destPath -Force
            }
        # 아카이브 로그 복사
        Get-ChildItem $global:LoggingConfig.ArchiveRoot -Recurse -File |
            Where-Object {
                $_.LastWriteTime -ge $StartTime -and
                $_.LastWriteTime -le $EndTime
            } |
            ForEach-Object {
                $destPath = Join-Path $tempDir "Archive" $_.Name
                $destDir = Split-Path $destPath
                if (!(Test-Path $destDir)) {
                    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                }
                Copy-Item $_.FullName -Destination $destPath -Force
            }
        # 설정 파일 복사
        Copy-Item (Join-Path $global:LoggingConfig.LogRoot "logging.config.json") `
                 -Destination (Join-Path $tempDir "logging.config.json") -Force
        # ZIP 파일 생성
        Compress-Archive -Path "$tempDir\*" -DestinationPath $ExportPath -Force
        Write-Log "LOGGING" "로그 아카이브 생성 완료" "SUCCESS: $ExportPath"
    }
    catch {
        Write-Log "LOGGING" "로그 아카이브 생성 실패" "ERROR: $_"
    }
    finally {
        # 임시 디렉토리 정리
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
    }
}
Export-ModuleMember -Function @(
    'Initialize-LoggingSystem',
    'Write-Log',
    'Get-LogSummary',
    'Get-ServiceLogs',
    'Export-LogArchive'
)
