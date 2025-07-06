# Functions/DirectorySetup.ps1
function Initialize-Directory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredDirectories = @(
            'bin',
            'lib',
            'Common',
            'config',
            'docs',
            'Logs',
            'Modules',
            'Scripts',
            'Tests',
            'vendor'
        )
    )
    foreach ($Dir in $RequiredDirectories) {
        $DirPath = Join-Path $BasePath $Dir
        if (-not (Test-Path $DirPath)) {
            New-Item -ItemType Directory -Path $DirPath -Force
            Write-DCECLog -Message "Created directory: $DirPath" -Level Information
        }
    }
}
function Install-DCECEnvironment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [Parameter(Mandatory=$false)]
        [switch]$Force
    )
    # 기본 디렉토리 구조 초기화
    Initialize-Directory -BasePath $BasePath
    # 로깅 초기화
    Initialize-Logging
    # 문제 추적 시스템 초기화
    Initialize-ProblemTracking
    # 환경 설정 파일 생성
    $ConfigPath = Join-Path $BasePath "config\environment.json"
    if (-not (Test-Path $ConfigPath) -or $Force) {
        $DefaultConfig = @{
            version = "0.1.0"
            lastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            paths = @{
                modules = Join-Path $BasePath "Modules"
                scripts = Join-Path $BasePath "Scripts"
                logs = Join-Path $BasePath "Logs"
                config = Join-Path $BasePath "config"
            }
        }
        $DefaultConfig | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath
        Write-DCECLog -Message "Created environment configuration file: $ConfigPath" -Level Information
    }
    Write-DCECLog -Message "DCEC Environment installation completed" -Level Information
}
