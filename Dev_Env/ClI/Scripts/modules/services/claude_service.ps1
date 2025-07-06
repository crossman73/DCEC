# Claude 서비스 설치 및 설정 모듈
function Install-ClaudeService {
    param(
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env",
        [string]$LogType
    )
    $serviceDir = "$BaseDir/Services/Claude"
    $logDir = "$serviceDir/logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    # npm 전역 설치 디렉토리 설정
    $installCmd = @'
cd $serviceDir
/usr/bin/export NPM_GLOBAL="$HOME/.npm-global"
/usr/bin/export PATH="$NPM_GLOBAL/bin:$HOME/.local/bin:/usr/local/bin:$PATH"
/usr/bin/npm install -g @anthropic-ai/claude-code --prefix "$NPM_GLOBAL" 2>&1 | /usr/bin/tee $logDir/install.log
# 설치 확인
/usr/bin/echo "[설치 확인]" >> $logDir/validation.log
/usr/bin/which claude >> $logDir/validation.log 2>&1
/usr/bin/which claude-code >> $logDir/validation.log 2>&1
/usr/bin/claude --help | /usr/bin/head -n 5 >> $logDir/validation.log 2>&1
'@
    try {
        wsl bash -c $installCmd
        if ($LASTEXITCODE -ne 0) {
            throw "Claude CLI 설치 실패"
        }
        Write-Log $LogType "Claude 서비스 설치" "SUCCESS"
        return $true
    } catch {
        Write-Log $LogType "Claude 서비스 설치 실패" "FAIL: $_"
        return $false
    }
}
Export-ModuleMember -Function Install-ClaudeService
