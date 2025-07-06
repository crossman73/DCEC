# Core 디렉토리 구조 관리 모듈
using namespace System.IO
[CmdletBinding()]
param()
$script:DefaultBaseDir = "D:\Dev\DCEC\Dev_Env"
$script:DefaultLogType = "SETUP"
function Convert-PathToWsl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]${WindowsPath}
    )
    process {
        return ${WindowsPath}.Replace("\", "/").Replace("D:", "/mnt/d")
    }
}
function Convert-PathToWindows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]${WslPath}
    )
    process {
        return ${WslPath}.Replace("/mnt/d", "D:").Replace("/", "\")
    }
}
function Test-WslCommand {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    try {
        $null = & wsl bash -c "exit"
        return $true
    }
    catch {
        Write-Warning -Message "WSL 명령 실행 실패. WSL이 설치되어 있는지 확인하세요."
        return $false
    }
}
function Initialize-CoreStructure {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]${BaseDir} = $DefaultBaseDir,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]${LogType} = $DefaultLogType
    )
    try {
        if (-not (Test-WslCommand)) {
            throw [System.InvalidOperationException]::new("WSL이 필요합니다.")
        }
        $coreDirs = @(
            "Core\Env\Global",
            "Core\Env\Services",
            "Core\Env\Integration",
            "Core\Docs\Global\Architecture",
            "Core\Docs\Global\Guides",
            "Core\Docs\Services",
            "Core\Docs\Integration",
            "Core\Logs\Global",
            "Core\Logs\Services",
            "Core\Logs\Integration\Diagnostic",
            "Core\Logs\Integration\Workflow"
        )
        foreach ($dir in $coreDirs) {
            $fullPath = Join-Path -Path ${BaseDir} -ChildPath $dir
            try {
                # Windows 디렉토리 생성
                if (-not (Test-Path -Path $fullPath)) {
                    $null = New-Item -Path $fullPath -ItemType Directory -Force
                }
                # WSL 디렉토리 생성
                $wslPath = Convert-PathToWsl -WindowsPath $fullPath
                $null = wsl bash -c "mkdir -p `"$wslPath`""
                Write-Log -Type ${LogType} -Message "디렉토리 생성 완료" -Result $fullPath
            }
            catch {
                $errorMsg = "디렉토리 생성 실패: $fullPath - $_"
                Write-Log -Type ${LogType} -Message $errorMsg -Result "ERROR"
                throw [System.IO.IOException]::new($errorMsg, $_.Exception)
            }
        }
    }
    catch {
        Write-Log -Type ${LogType} -Message "Core 구조 초기화 실패" -Result "ERROR: $_"
        throw
    }
}
function Initialize-ServiceStructure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]${Service},
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]${BaseDir} = (Join-Path -Path $DefaultBaseDir -ChildPath "Services"),
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]${LogType} = $DefaultLogType
    )
    try {
        if (-not (Test-WslCommand)) {
            throw [System.InvalidOperationException]::new("WSL이 필요합니다.")
        }
        $serviceDirs = @(
            "env",
            "docs",
            "logs",
            "src",
            "tests",
            "config"
        )
        $serviceRoot = Join-Path -Path ${BaseDir} -ChildPath ${Service}
        foreach ($dir in $serviceDirs) {
            $fullPath = Join-Path -Path $serviceRoot -ChildPath $dir
            try {
                if (-not (Test-Path -Path $fullPath)) {
                    $null = New-Item -Path $fullPath -ItemType Directory -Force
                }
                $wslPath = Convert-PathToWsl -WindowsPath $fullPath
                $null = wsl bash -c "mkdir -p `"$wslPath`""
                Write-Log -Type ${LogType} -Message "서비스 디렉토리 생성" -Result $fullPath
            }
            catch {
                $errorMsg = "서비스 디렉토리 생성 실패: $fullPath - $_"
                Write-Log -Type ${LogType} -Message $errorMsg -Result "ERROR"
                throw [System.IO.IOException]::new($errorMsg, $_.Exception)
            }
        }
        # 심볼릭 링크 생성
        $coreDir = Join-Path -Path $DefaultBaseDir -ChildPath "Core"
        $links = @{
            "logs" = Join-Path -Path $coreDir -ChildPath "Logs\Services\$Service"
            "docs" = Join-Path -Path $coreDir -ChildPath "Docs\Services\$Service"
            "env"  = Join-Path -Path $coreDir -ChildPath "Env\Services\$Service"
        }
        foreach ($link in $links.GetEnumerator()) {
            try {
                $target = Join-Path -Path $serviceRoot -ChildPath $link.Key
                $linkPath = $link.Value
                if (Test-Path -Path $linkPath) {
                    Remove-Item -Path $linkPath -Force
                }
                $null = New-Item -ItemType SymbolicLink -Path $linkPath -Target $target -Force
                $wslTarget = Convert-PathToWsl -WindowsPath $target
                $wslLink = Convert-PathToWsl -WindowsPath $linkPath
                $null = wsl bash -c "ln -sf `"$wslTarget`" `"$wslLink`""
                Write-Log -Type ${LogType} -Message "심볼릭 링크 생성 완료" -Result "$($link.Key) -> $target"
            }
            catch {
                $errorMsg = "심볼릭 링크 생성 실패: $($link.Key) - $_"
                Write-Log -Type ${LogType} -Message $errorMsg -Result "ERROR"
                throw [System.IO.IOException]::new($errorMsg, $_.Exception)
            }
        }
    }
    catch {
        Write-Log -Type ${LogType} -Message "서비스 구조 초기화 실패" -Result "ERROR: $_"
        throw
    }
}
function Test-DirectoryStructure {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]${BasePath}
    )
    $errors = [System.Collections.Generic.List[string]]::new()
    # Core 디렉토리 검사
    $corePaths = @(
        "Core\Env\Global",
        "Core\Docs\Global",
        "Core\Logs\Global"
    )
    foreach ($path in $corePaths) {
        $fullPath = Join-Path -Path ${BasePath} -ChildPath $path
        if (-not (Test-Path -Path $fullPath)) {
            $errors.Add("필수 디렉토리 누락: $fullPath")
        }
    }
    # 서비스 디렉토리 검사
    $servicesPath = Join-Path -Path ${BasePath} -ChildPath "Services"
    if (Test-Path -Path $servicesPath) {
        Get-ChildItem -Path $servicesPath -Directory | ForEach-Object {
            $serviceDirs = @("env", "docs", "logs", "src", "config")
            foreach ($dir in $serviceDirs) {
                $dirPath = Join-Path -Path $_.FullName -ChildPath $dir
                if (-not (Test-Path -Path $dirPath)) {
                    $errors.Add("서비스 디렉토리 누락: $dirPath")
                }
            }
        }
    }
    if ($errors.Count -gt 0) {
        Write-Warning -Message "디렉토리 구조 검증 실패:`n$($errors -join "`n")"
        return $false
    }
    return $true
}
Export-ModuleMember -Function @(
    'Initialize-CoreStructure',
    'Initialize-ServiceStructure',
    'Test-DirectoryStructure',
    'Convert-PathToWsl',
    'Convert-PathToWindows'
)
