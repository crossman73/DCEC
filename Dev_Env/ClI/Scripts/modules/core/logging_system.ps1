# 로깅 시스템 모듈
using namespace System.IO
[CmdletBinding()]
param()
# 로그 설정
$script:LogConfig = @{
    RootPath = "D:\Dev\DCEC\Dev_Env\ClI\logs"
    MaxSize = 10MB
    MaxFiles = 10
    TimeFormat = "yyyy-MM-dd HH:mm:ss"
    DefaultLevel = "INFO"
}
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]${Type},
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]${Message},
        [Parameter()]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]${Level} = $LogConfig.DefaultLevel
    )
    try {
        $timestamp = Get-Date -Format $LogConfig.TimeFormat
        $logFile = Join-Path -Path $LogConfig.RootPath -ChildPath "${Type}_$(Get-Date -Format 'yyyyMMdd').log"
        # 로그 디렉토리 확인
        if (-not (Test-Path -Path $LogConfig.RootPath)) {
            $null = New-Item -Path $LogConfig.RootPath -ItemType Directory -Force
        }
        # 로그 순환 확인
        if (Test-Path -Path $logFile) {
            $fileInfo = Get-Item -Path $logFile
            if ($fileInfo.Length -gt $LogConfig.MaxSize) {
                Start-LogRotation -LogFile $logFile
            }
        }
        # 로그 작성
        $logEntry = "[$timestamp] [${Level}] ${Message}"
        Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
        # 콘솔 출력
        switch ($Level) {
            'ERROR'   { Write-Error $logEntry }
            'WARNING' { Write-Warning $logEntry }
            'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
            default   { Write-Verbose $logEntry }
        }
    }
    catch {
        Write-Error "로그 작성 실패: $_"
    }
}
function Start-LogRotation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]${LogFile}
    )
    try {
        $directory = Split-Path -Path ${LogFile} -Parent
        $fileName = Split-Path -Path ${LogFile} -Leaf
        $baseName = $fileName.Split('.')[0]
        # 기존 로그 파일 이동
        for ($i = $LogConfig.MaxFiles; $i -gt 0; $i--) {
            $oldFile = Join-Path -Path $directory -ChildPath "${baseName}_$i.log"
            $newFile = Join-Path -Path $directory -ChildPath "${baseName}_$($i+1).log"
            if (Test-Path -Path $oldFile) {
                if ($i -eq $LogConfig.MaxFiles) {
                    Remove-Item -Path $oldFile -Force
                }
                else {
                    Move-Item -Path $oldFile -Destination $newFile -Force
                }
            }
        }
        # 현재 로그 파일 이동
        Move-Item -Path ${LogFile} -Destination (Join-Path -Path $directory -ChildPath "${baseName}_1.log") -Force
    }
    catch {
        Write-Error "로그 순환 실패: $_"
    }
}
function Get-LogSummary {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]${Type},
        [Parameter()]
        [DateTime]${StartTime},
        [Parameter()]
        [DateTime]${EndTime}
    )
    try {
        $logs = Get-ChildItem -Path $LogConfig.RootPath -Filter "*.log"
        $summary = @{
            TotalFiles = $logs.Count
            TotalSize = ($logs | Measure-Object -Property Length -Sum).Sum
            TypeStats = @{
            }
            LevelStats = @{
            }
        }
        foreach ($log in $logs) {
            if (${Type} -and -not $log.Name.StartsWith(${Type})) {
                continue
            }
            Get-Content -Path $log.FullName | ForEach-Object {
                if ($_ -match '\[(.*?)\] \[(INFO|WARNING|ERROR|SUCCESS)\]') {
                    $timestamp = [DateTime]::ParseExact($Matches[1], $LogConfig.TimeFormat, $null)
                    if ((${StartTime} -and $timestamp -lt ${StartTime}) -or
                        (${EndTime} -and $timestamp -gt ${EndTime})) {
                        return
                    }
                    $level = $Matches[2]
                    $summary.LevelStats[$level] = ($summary.LevelStats[$level] ?? 0) + 1
                }
            }
        }
        return $summary
    }
    catch {
        Write-Error "로그 요약 생성 실패: $_"
        return $null
    }
}
Export-ModuleMember -Function @(
    'Write-Log',
    'Start-LogRotation',
    'Get-LogSummary'
)
