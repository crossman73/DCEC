# Functions/Logging.ps1
function Initialize-Logging {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$LogPath = (Join-Path $PSScriptRoot "..\..\Logs")
    )
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force
    }
    $Script:DCECLogPath = $LogPath
    $Script:DCECLogFile = Join-Path $LogPath "dcec_$(Get-Date -Format 'yyyyMMdd').log"
}
function Write-DCECLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Level = 'Information'
    )
    if (-not $Script:DCECLogFile) {
        Initialize-Logging
    }
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$TimeStamp] [$Level] $Message"
    Add-Content -Path $Script:DCECLogFile -Value $LogMessage
    Write-Host $LogMessage
}
