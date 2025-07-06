#requires -Version 7.0
<#
.SYNOPSIS
    CLI tool project initialization script.
.DESCRIPTION
    Initializes a new CLI tool project with virtual environment,
    dependencies, and optional Click auto-completion.
.PARAMETER ProjectName
    The name of the CLI tool project to initialize.
.PARAMETER EnableAutoComplete
    Whether to enable Click command auto-completion.
    Defaults to true.
.PARAMETER LogLevel
    The logging level to use.
    Valid values: DEBUG, INFO, WARN, ERROR
    Defaults to INFO.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectName,
    [Parameter()]
    [bool]$EnableAutoComplete = $true,
    [Parameter()]
    [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
    [string]$LogLevel = 'INFO'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
# Initialize basic environment
$initCommonPath = Join-Path $PSScriptRoot '..\..\init_common.ps1'
. $initCommonPath
Write-ColorLog 'Starting CLI tool project setup' -Level INFO -Color Green
Write-ColorLog ('Project name: {0}' -f $ProjectName) -Level INFO
# Setup Python virtual environment
Write-ColorLog 'Creating Python virtual environment...' -Level INFO
try {
    # Start environment setup
    $env:PYTHONIOENCODING = 'utf-8'
    $env:PYTHONUTF8 = '1'
    $pythonCmd = Get-Command 'python' -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        & $pythonCmd.Source -m venv .venv
    } else {
        throw "Python command not found. Please ensure Python is installed and in PATH."
    }
    # Activate virtual environment
    $activateScript = if ($IsWindows) {
        Join-Path '.venv' 'Scripts' 'Activate.ps1'
    } else {
        Join-Path '.venv' 'bin' 'activate'
    }
    if (Test-Path $activateScript) {
        . $activateScript
        Write-ColorLog "Virtual environment activated" -Level INFO
    } else {
        throw "Virtual environment activation script not found: $activateScript"
    }
    # Install dependencies
    Write-ColorLog "Installing dependencies..." -Level INFO
    & $pythonCmd.Source -m pip install --upgrade pip
    & pip install -r requirements.txt
    # Update configuration
    $configPath = Join-Path 'config' 'default.yaml'
    if (Test-Path $configPath) {
        $configContent = Get-Content $configPath
        $configContent = $configContent -replace 'level: INFO', "level: $LogLevel"
        Set-Content -Path $configPath -Value $configContent
        Write-ColorLog "Configuration updated with log level: $LogLevel" -Level INFO
    } else {
        Write-ColorLog "Configuration file not found: $configPath" -Level WARN
    }
if ($EnableAutoComplete) {
    # Install Click auto-completion script
    Write-ColorLog "Generating auto-completion script..." -Level INFO
    # Generate completion script
    $pythonCmd = Get-Command 'python' -ErrorAction SilentlyContinue
    if ($pythonCmd -and (Test-Path 'src/main.py')) {
        try {
            # Temporarily store and set Click environment variable
            # Click uses this environment variable for completion script generation
            $env:_CLICK_COMPLETE = 'powershell_source'
            # Generate and save completion script
            $completionScript = & $pythonCmd.Source 'src/main.py'
            if ($LASTEXITCODE -eq 0 -and $completionScript) {
                $completionScript | Set-Content -Path 'completion.ps1'
                Write-ColorLog "Auto-completion script generated successfully" -Level INFO
                Write-ColorLog "To enable auto-completion, run: . ./completion.ps1" -Level INFO -Color Yellow
            } else {
                Write-ColorLog "Failed to generate completion script" -Level WARN
            }
        }
        catch {
            Write-ColorLog "Error generating completion script: $_" -Level ERROR
        }
        finally {
            # Restore original environment state
            if ($originalClickComplete) {
                $env:_CLICK_COMPLETE = $originalClickComplete
            }
            else {
                Remove-Item Env:_CLICK_COMPLETE -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-ColorLog "Python or main script not found. Skipping auto-completion setup." -Level WARN
    }
}
# Install package in development mode
    Write-ColorLog "Installing package in development mode..." -Level INFO
    & pip install -e .
    Write-ColorLog "Project initialization completed successfully" -Level INFO -Color Green
    Write-ColorLog "To get started, run: $ProjectName --help" -Level INFO -Color Green
} catch {
    Write-ColorLog "Project initialization failed: $_" -Level ERROR -Color Red
    exit 1
}
