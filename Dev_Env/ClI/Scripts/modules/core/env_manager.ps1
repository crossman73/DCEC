# 환경 변수 관리 모듈
function Initialize-EnvStructure {
    param(
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env/Env",
        [string]$LogType
    )
    $envDirs = @(
        "$BaseDir/Global",
        "$BaseDir/Services/Claude",
        "$BaseDir/Services/Gemini",
        "$BaseDir/Services/Utils",
        "$BaseDir/Integration"
    )
    foreach ($dir in $envDirs) {
        $cmd = "wsl bash -c '/usr/bin/mkdir -p $dir'"
        try {
            Invoke-Expression $cmd | Out-Null
            Write-Log $LogType "환경 변수 디렉토리 생성: $dir" "SUCCESS"
        } catch {
            Write-Log $LogType "환경 변수 디렉토리 생성 실패: $dir" "FAIL: $_"
        }
    }
}
function New-EnvFile {
    param(
        [string]$Path,
        [hashtable]$EnvVars,
        [string]$Description,
        [string]$LogType
    )
    $envContent = @"
# $Description
# 생성일: $(/usr/bin/date +%Y-%m-%d)
# 주의: 이 파일은 자동으로 생성됩니다. 직접 수정하지 마세요.
"@
    foreach ($key in $EnvVars.Keys) {
        $envContent += "${key}=${EnvVars[$key]}`n"
    }
    $cmd = @"
/usr/bin/cat > '$Path' << 'EOF'
$envContent
EOF
chmod 600 '$Path'
"@
    try {
        wsl bash -c $cmd
        Write-Log $LogType "환경 변수 파일 생성: $Path" "SUCCESS"
        return $true
    } catch {
        Write-Log $LogType "환경 변수 파일 생성 실패: $Path" "FAIL: $_"
        return $false
    }
}
function Initialize-GlobalEnv {
    param(
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env/Env",
        [string]$LogType
    )
    # 시스템 공통 환경 변수
    $systemEnv = @{
        "DEV_HOME" = "/mnt/d/Dev/DCEC"
        "ENV_HOME" = "$BaseDir"
        "WORKSPACE_ROOT" = "/mnt/d/Dev/DCEC"
    }
    New-EnvFile -Path "$BaseDir/Global/system.env" -EnvVars $systemEnv -Description "시스템 공통 환경 변수" -LogType $LogType
    # PATH 관련 환경 변수
    $pathEnv = @{
        "PATH_BACKUP" = '$PATH'
        "CUSTOM_PATH" = "$BaseDir/bin:/usr/local/bin:/usr/bin"
    }
    New-EnvFile -Path "$BaseDir/Global/paths.env" -EnvVars $pathEnv -Description "PATH 환경 변수 설정" -LogType $LogType
}
function Initialize-ServiceEnv {
    param(
        [string]$Service,
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env/Env",
        [hashtable]$Config,
        [string]$LogType
    )
    $serviceDir = "$BaseDir/Services/$Service"
    # API 환경 변수
    if ($Config.ContainsKey("api")) {
        New-EnvFile -Path "$serviceDir/api.env" -EnvVars $Config.api -Description "$Service API 환경 변수" -LogType $LogType
    }
    # 설정 환경 변수
    if ($Config.ContainsKey("config")) {
        New-EnvFile -Path "$serviceDir/config.env" -EnvVars $Config.config -Description "$Service 설정 환경 변수" -LogType $LogType
    }
}
Export-ModuleMember -Function Initialize-EnvStructure, Initialize-GlobalEnv, Initialize-ServiceEnv
