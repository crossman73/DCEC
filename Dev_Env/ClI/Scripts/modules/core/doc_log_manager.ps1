# 문서 및 로그 디렉토리 관리 모듈
function Initialize-DocStructure {
    param(
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env",
        [string]$LogType
    )
    $docDirs = @(
        "$BaseDir/Docs/Global/Architecture",
        "$BaseDir/Docs/Global/Guides",
        "$BaseDir/Docs/Services/Claude",
        "$BaseDir/Docs/Services/Gemini",
        "$BaseDir/Docs/Services/Utils",
        "$BaseDir/Docs/Integration/Workflow",
        "$BaseDir/Docs/Integration/Backup"
    )
    foreach ($dir in $docDirs) {
        $cmd = "wsl bash -c '/usr/bin/mkdir -p $dir'"
        try {
            Invoke-Expression $cmd | Out-Null
            Write-Log $LogType "문서 디렉토리 생성: $dir" "SUCCESS"
        } catch {
            Write-Log $LogType "문서 디렉토리 생성 실패: $dir" "FAIL: $_"
        }
    }
}
function Initialize-LogStructure {
    param(
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env",
        [string]$LogType
    )
    $logDirs = @(
        "$BaseDir/Logs/Global",
        "$BaseDir/Logs/Services/Claude",
        "$BaseDir/Logs/Services/Gemini",
        "$BaseDir/Logs/Services/Utils",
        "$BaseDir/Logs/Integration/Workflow",
        "$BaseDir/Logs/Integration/Diagnostic"
    )
    foreach ($dir in $logDirs) {
        $cmd = "wsl bash -c '/usr/bin/mkdir -p $dir'"
        try {
            Invoke-Expression $cmd | Out-Null
            Write-Log $LogType "로그 디렉토리 생성: $dir" "SUCCESS"
        } catch {
            Write-Log $LogType "로그 디렉토리 생성 실패: $dir" "FAIL: $_"
        }
    }
}
function New-ServiceDoc {
    param(
        [string]$Service,
        [string]$DocType,
        [string]$Content,
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env",
        [string]$LogType
    )
    $docPath = "$BaseDir/Docs/Services/$Service/$DocType.md"
    $cmd = @"
/usr/bin/cat > '$docPath' << 'EOF'
$Content
EOF
"@
    try {
        wsl bash -c $cmd
        Write-Log $LogType "서비스 문서 생성: $docPath" "SUCCESS"
        return $true
    } catch {
        Write-Log $LogType "서비스 문서 생성 실패: $docPath" "FAIL: $_"
        return $false
    }
}
function Write-ServiceLog {
    param(
        [string]$Service,
        [string]$LogCategory,
        [string]$Message,
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env",
        [string]$LogType
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logPath = "$BaseDir/Logs/Services/$Service/$LogCategory.log"
    $logLine = "[$timestamp] $Message"
    $cmd = "echo '$logLine' >> '$logPath'"
    try {
        wsl bash -c $cmd
        return $true
    } catch {
        Write-Log $LogType "서비스 로그 기록 실패: $logPath" "FAIL: $_"
        return $false
    }
}
Export-ModuleMember -Function Initialize-DocStructure, Initialize-LogStructure, New-ServiceDoc, Write-ServiceLog
