function Install-UtilsService {
    param (
        [string]$workspaceRoot
    )
    $utilsHome = Join-Path $workspaceRoot "UtilsService"
    if (!(Test-Path $utilsHome)) {
        Write-Log "UtilsService" "디렉토리가 존재하지 않음" "SKIP"
        return
    }
    # jq, httpie 설치 및 로깅
    $toolsInstallCmd = @'
cd /mnt/d/Dev/DCEC/UtilsService
/usr/bin/sudo /usr/bin/apt-get update && /usr/bin/sudo /usr/bin/apt-get install -y jq httpie 2>&1 | /usr/bin/tee ./logs/utils_install.log
/usr/bin/echo "[jq --version]"; /usr/bin/jq --version || /usr/bin/echo "jq 설치 실패"
/usr/bin/echo "[http --version]"; /usr/bin/http --version || /usr/bin/echo "httpie 설치 실패"
'@
    $toolsResult = wsl bash -lc "$toolsInstallCmd" 2>&1
    Write-Log "UtilsService" "설치/확인 결과" $toolsResult
    # 진단 및 상태 확인
    $diagnoseCmd = @'
cd /mnt/d/Dev/DCEC/UtilsService
/usr/bin/echo "[설치 로그]"; /usr/bin/tail -n 20 ./logs/utils_install.log
/usr/bin/echo "[실행파일 위치]"; /usr/bin/which jq; /usr/bin/which http
/usr/bin/echo "[PATH]"; /usr/bin/echo $PATH
/usr/bin/echo "[에러 진단]"; /usr/bin/cat ./logs/utils_install.log | /usr/bin/grep -Ei "error|fail|warn" || /usr/bin/echo "에러/경고 없음"
'@
    $diagnoseResult = wsl bash -lc "$diagnoseCmd" 2>&1
    Write-Log "UtilsService" "진단" $diagnoseResult
    return $true
}
Export-ModuleMember -Function Install-UtilsService
