# 유틸리티 함수 모듈
using module '..\core\logging.ps1'
function Convert-ToWslPath {
    param (
        [Parameter(Mandatory=$true)]
        [string]$WindowsPath
    )
    try {
        $wslPath = $WindowsPath -replace '^(\w):', '/mnt/$1' -replace '\\', '/'
        return $wslPath.ToLower()
    }
    catch {
        Write-Log -Level ERROR -Message "Windows 경로를 WSL 경로로 변환 실패" -Result $_.Exception.Message
        throw
    }
}
function Convert-ToWindowsPath {
    param (
        [Parameter(Mandatory=$true)]
        [string]$WslPath
    )
    try {
        if ($WslPath -match '^/mnt/(\w)(.*)') {
            $drive = $matches[1].ToUpper()
            $path = $matches[2] -replace '/', '\'
            return "${drive}:$path"
        }
        throw "잘못된 WSL 경로 형식: $WslPath"
    }
    catch {
        Write-Log -Level ERROR -Message "WSL 경로를 Windows 경로로 변환 실패" -Result $_.Exception.Message
        throw
    }
}
function Test-CommandExists {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Command
    )
    try {
        $exists = $null -ne (Get-Command -Name $Command -ErrorAction SilentlyContinue)
        Write-Log -Level DEBUG -Message "명령어 존재 여부 확인: $Command" -Result $exists
        return $exists
    }
    catch {
        Write-Log -Level ERROR -Message "명령어 존재 여부 확인 실패: $Command" -Result $_.Exception.Message
        return $false
    }
}
function Start-SafeProcess {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [string[]]$ArgumentList,
        [switch]$Wait,
        [switch]$NoWindow
    )
    try {
        $startInfo = @{
            FilePath = $FilePath
            ArgumentList = $ArgumentList
            Wait = $Wait
            NoNewWindow = $NoWindow
            PassThru = $true
        }
        Write-Log -Level DEBUG -Message "프로세스 시작: $FilePath $($ArgumentList -join ' ')"
        $process = Start-Process @startInfo
        if ($Wait) {
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) {
                throw "프로세스 종료 코드: $($process.ExitCode)"
            }
        }
        return $process
    }
    catch {
        Write-Log -Level ERROR -Message "프로세스 시작 실패" -Result $_.Exception.Message
        throw
    }
}
function Install-RequiredModule {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ModuleName,
        [string]$MinimumVersion,
        [switch]$AllowPrerelease
    )
    try {
        if (!(Get-Module -ListAvailable -Name $ModuleName)) {
            Write-Log -Level INFO -Message "모듈 설치 시작: $ModuleName"
            $installParams = @{
                Name = $ModuleName
                Force = $true
                Scope = 'CurrentUser'
            }
            if ($MinimumVersion) {
                $installParams['MinimumVersion'] = $MinimumVersion
            }
            if ($AllowPrerelease) {
                $installParams['AllowPrerelease'] = $true
            }
            Install-Module @installParams
            Write-Log -Level INFO -Message "모듈 설치 완료: $ModuleName"
        }
        else {
            Write-Log -Level DEBUG -Message "이미 설치된 모듈: $ModuleName"
        }
    }
    catch {
        Write-Log -Level ERROR -Message "모듈 설치 실패: $ModuleName" -Result $_.Exception.Message
        throw
    }
}
Export-ModuleMember -Function Convert-ToWslPath, Convert-ToWindowsPath, Test-CommandExists, Start-SafeProcess, Install-RequiredModule
