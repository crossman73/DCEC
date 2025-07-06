# BackupService 모듈
# 백업 및 복원 기능을 관리하는 PowerShell 모듈
function Initialize-BackupService {
    param(
        [string]$BackupRoot = "D:\Dev\DCEC\Dev_Env\Core\Backup",
        [string]$LogPath = "D:\Dev\DCEC\Dev_Env\Core\Logs\backup_service.log"
    )
    # 백업 디렉토리 구조 생성
    $backupDirs = @(
        "$BackupRoot\Env",
        "$BackupRoot\Config",
        "$BackupRoot\Packages",
        "$BackupRoot\Scripts"
    )
    foreach ($dir in $backupDirs) {
        if (!(Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force
            Write-Log "BACKUP" "백업 디렉토리 생성: $dir" "SUCCESS"
        }
    }
}
function Backup-ServiceConfiguration {
    param(
        [string]$ServiceName,
        [string]$ConfigPath,
        [string]$BackupRoot = "D:\Dev\DCEC\Dev_Env\Core\Backup"
    )
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = Join-Path $BackupRoot "Config\$ServiceName`_$timestamp.zip"
    try {
        Compress-Archive -Path $ConfigPath -DestinationPath $backupPath -Force
        Write-Log "BACKUP" "$ServiceName 설정 백업" "SUCCESS: $backupPath"
    }
    catch {
        Write-Log "BACKUP" "$ServiceName 설정 백업 실패" "ERROR: $_"
    }
}
function Backup-GlobalPackage {
    param(
        [string]$BackupRoot = "D:\Dev\DCEC\Dev_Env\Core\Backup"
    )
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $packagesPath = Join-Path $BackupRoot "Packages\global_packages_$timestamp.txt"
    $backupCmd = @'
/usr/bin/npm list -g --depth=0 > $env:BACKUP_PATH
/usr/bin/echo "==== Python Packages ====" >> $env:BACKUP_PATH
/usr/bin/pip list >> $env:BACKUP_PATH 2>/dev/null || true
'@
    $env:BACKUP_PATH = $packagesPath
    $backupOutput = wsl bash -c "$backupCmd" 2>&1
    Write-Log "백업 작업 결과:`n$backupOutput" -Level INFO
    Write-Log "BACKUP" "전역 패키지 목록 백업" "파일: $packagesPath"
}
function Restore-ServiceConfiguration {
    param(
        [string]$ServiceName,
        [string]$BackupRoot = "D:\Dev\DCEC\Dev_Env\Core\Backup",
        [string]$TargetPath
    )
    # 최신 백업 찾기
    $latestBackup = Get-ChildItem -Path "$BackupRoot\Config" -Filter "$ServiceName*.zip" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1
    if ($latestBackup) {
        try {
            Expand-Archive -Path $latestBackup.FullName -DestinationPath $TargetPath -Force
            Write-Log "RESTORE" "$ServiceName 설정 복원" "SUCCESS: $($latestBackup.Name)"
        }
        catch {
            Write-Log "RESTORE" "$ServiceName 설정 복원 실패" "ERROR: $_"
        }
    }
    else {
        Write-Log "RESTORE" "$ServiceName 설정 복원 실패" "ERROR: 백업 파일 없음"
    }
}
# 백업 서비스 상태 보고서 생성
function Get-BackupServiceReport {
    param(
        [string]$BackupRoot = "D:\Dev\DCEC\Dev_Env\Core\Backup"
    )
    $report = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        BackupCounts = @{}
        LatestBackups = @{}
        TotalSize = 0
    }
    Get-ChildItem $BackupRoot -Recurse -File | ForEach-Object {
        $type = $_.Directory.Name
        if (!$report.BackupCounts.ContainsKey($type)) {
            $report.BackupCounts[$type] = 0
            $report.LatestBackups[$type] = $null
        }
        $report.BackupCounts[$type]++
        $report.TotalSize += $_.Length
        if ($null -eq $report.LatestBackups[$type] -or
            $_.LastWriteTime -gt $report.LatestBackups[$type].LastWriteTime) {
            $report.LatestBackups[$type] = $_
        }
    }
    return $report
}
# 백업 정리 (오래된 백업 삭제)
function Clear-OldBackup {
    param(
        [string]$BackupRoot = "D:\Dev\DCEC\Dev_Env\Core\Backup",
        [int]$DaysToKeep = 30
    )
    $cutoffDate = (Get-Date).AddDays(-$DaysToKeep)
    Get-ChildItem $BackupRoot -Recurse -File |
    Where-Object { $_.LastWriteTime -lt $cutoffDate } |
    ForEach-Object {
        try {
            Remove-Item $_.FullName -Force
            Write-Log "BACKUP" "오래된 백업 삭제" "SUCCESS: $($_.Name)"
        }
        catch {
            Write-Log "BACKUP" "백업 삭제 실패" "ERROR: $($_.Name) - $_"
        }
    }
}
Export-ModuleMember -Function @(
    'Initialize-BackupService',
    'Backup-ServiceConfiguration',
    'Backup-GlobalPackage',
    'Restore-ServiceConfiguration',
    'Get-BackupServiceReport',
    'Clear-OldBackup'
)
