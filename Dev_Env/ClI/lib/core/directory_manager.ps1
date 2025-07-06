# Core 디렉토리 구조 관리 모듈
function Initialize-CoreStructure {
    param(
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env",
        [string]$LogType
    )
    $coreDirs = @(
        "$BaseDir/Core/Env/Global",
        "$BaseDir/Core/Env/Services",
        "$BaseDir/Core/Env/Integration",
        "$BaseDir/Core/Docs/Global/Architecture",
        "$BaseDir/Core/Docs/Global/Guides",
        "$BaseDir/Core/Docs/Services",
        "$BaseDir/Core/Docs/Integration",
        "$BaseDir/Core/Logs/Global",
        "$BaseDir/Core/Logs/Services",
        "$BaseDir/Core/Logs/Integration/Diagnostic",
        "$BaseDir/Core/Logs/Integration/Workflow"
    )
    foreach ($dir in $coreDirs) {
        try {
            & wsl bash -c "/usr/bin/mkdir -p '$dir'" | Out-Null
            Write-Log $LogType "Core 디렉토리 생성: $dir" "SUCCESS"
        } catch {
            Write-Log $LogType "Core 디렉토리 생성 실패: $dir" "FAIL: $_"
        }
    }
}
function Initialize-ServiceStructure {
    param(
        [string]$Service,
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env/Services",
        [string]$LogType
    )
    $serviceDirs = @(
        "$BaseDir/$Service/env",
        "$BaseDir/$Service/docs",
        "$BaseDir/$Service/logs"
    )
    foreach ($dir in $serviceDirs) {
        $cmd = "wsl bash -c '/usr/bin/mkdir -p $dir'"
        try {
            Invoke-Expression $cmd | Out-Null
            Write-Log $LogType "서비스 디렉토리 생성: $dir" "SUCCESS"
        } catch {
            Write-Log $LogType "서비스 디렉토리 생성 실패: $dir" "FAIL: $_"
        }
    }
    # 서비스별 로그 심볼릭 링크 생성
    $cmd = @"
wsl bash -c '
/usr/bin/ln -sf $BaseDir/$Service/logs /mnt/d/Dev/DCEC/Dev_Env/Core/Logs/Services/$Service
/usr/bin/ln -sf $BaseDir/$Service/docs /mnt/d/Dev/DCEC/Dev_Env/Core/Docs/Services/$Service
/usr/bin/ln -sf $BaseDir/$Service/env /mnt/d/Dev/DCEC/Dev_Env/Core/Env/Services/$Service
'
"@
    try {
        Invoke-Expression $cmd | Out-Null
        Write-Log $LogType "서비스 심볼릭 링크 생성" "SUCCESS"
    } catch {
        Write-Log $LogType "서비스 심볼릭 링크 생성 실패" "FAIL: $_"
    }
}
Export-ModuleMember -Function Initialize-CoreStructure, Initialize-ServiceStructure
