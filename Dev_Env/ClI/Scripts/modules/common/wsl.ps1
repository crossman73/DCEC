# WSL 명령어 실행 유틸리티 모듈
# PowerShell에서 WSL 명령어를 안전하게 실행하기 위한 함수들
function New-WslScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,
        [string]$ScriptPath,
        [switch]$Temporary
    )
    if ($Temporary) {
        $tempDir = [System.IO.Path]::GetTempPath()
        $scriptName = [System.IO.Path]::GetRandomFileName() + ".sh"
        $ScriptPath = Join-Path $tempDir $scriptName
    }
    # PowerShell 변수를 WSL 변수로 이스케이프
    $escapedContent = $Content -replace '\$(?![\(\{])', '\$'
    $escapedContent | Out-File -FilePath $ScriptPath -Encoding utf8 -NoNewline
    $wslPath = Convert-WindowsPathToWsl $ScriptPath
    Invoke-WslCommand -Command "chmod +x $wslPath"
    if ($Temporary) {
        # 스크립트 실행 후 자동 삭제를 위한 PowerShell 이벤트 등록
        Register-ObjectEvent -InputObject (Get-Process -Id $pid) -EventName Exit -Action {
            Remove-Item -Path $ScriptPath -Force -ErrorAction SilentlyContinue
        } | Out-Null
    }
    return $ScriptPath
}
function Invoke-WslCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        [string]$WorkingDirectory,
        [hashtable]$Environment = @{},
        [switch]$UseLoginShell
    )
    # 환경 변수 설정 명령 생성
    $envSetup = $Environment.Keys | ForEach-Object {
        "export $($_)=""$($Environment[$_])"""
    }
    $envCommand = if ($envSetup) {
        $envSetup -join "; "
    } else {
        ""
    }
    # 작업 디렉토리 이동 명령 추가
    $cdCommand = if ($WorkingDirectory) {
        "cd ""$WorkingDirectory"" &&"
    } else {
        ""
    }
    # 최종 명령어 조합
    $fullCommand = @(
        $envCommand
        $cdCommand
        $Command
    ) | Where-Object { $_ } | Join-String -Separator " "
    # WSL 실행 옵션 설정
    $wslArgs = @(
        if ($UseLoginShell) { "bash", "-lc" } else { "bash", "-c" }
        $fullCommand
    )
    # 명령 실행 및 결과 반환
    $result = wsl @wslArgs 2>&1
    return $result
}
function Convert-WindowsPathToWsl {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowsPath
    )
    # UNC 경로 처리
    if ($WindowsPath -match "^\\\\") {
        throw "UNC 경로는 지원되지 않습니다: $WindowsPath"
    }
    # 드라이브 문자를 WSL 경로로 변환
    if ($WindowsPath -match "^([A-Za-z]):(.*)") {
        $drive = $matches[1].ToLower()
        $path = $matches[2] -replace "\\", "/"
        return "/mnt/$drive$path"
    }
    # 이미 WSL 경로 형식이면 그대로 반환
    if ($WindowsPath -match "^/") {
        return $WindowsPath
    }
    # 상대 경로는 오류 발생
    throw "절대 경로만 지원됩니다: $WindowsPath"
}
function Install-WslPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Package,
        [string]$LogFile,
        [switch]$Update
    )
    $updateCmd = if ($Update) {
        "sudo apt-get update &&"
    } else {
        ""
    }
    $installCmd = if ($LogFile) {
        "$updateCmd sudo apt-get install -y $Package 2>&1 | tee $LogFile"
    } else {
        "$updateCmd sudo apt-get install -y $Package"
    }
    $result = Invoke-WslCommand -Command $installCmd -UseLoginShell
    return $result
}
Export-ModuleMember -Function @(
    'New-WslScript',
    'Invoke-WslCommand',
    'Convert-WindowsPathToWsl',
    'Install-WslPackage'
)
