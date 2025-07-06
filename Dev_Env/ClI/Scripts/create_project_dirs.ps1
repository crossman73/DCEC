#requires -Version 7.0
<#
.SYNOPSIS
    Creates complete DCEC project directory structure with three main components.
.DESCRIPTION
    Creates the full DCEC project architecture consisting of:
    1. Dev_Env - Development environment and services for consistent development continuity
    2. Infra_Architecture - Network, hardware and infrastructure management by environment
    3. Governance - Operational policies, documentation and governance projects
    This structure supports both Windows and WSL2 environments for maximum compatibility.
.PARAMETER RootPath
    The root path where to create the project structure.
    Default is 'D:\Dev\DCEC'.
.EXAMPLE
    .\create_project_dirs.ps1
    Creates the complete DCEC project structure in the default location.
.EXAMPLE
    .\create_project_dirs.ps1 -RootPath "E:\Projects\DCEC"
    Creates the complete DCEC project structure in the specified location.
.NOTES
    Author: DCEC Development Team
    Date: 2025-07-06
    Requires: PowerShell 7.0 or later, WSL2
    Project Structure:
    - Dev_Env: Development environment services and tools
    - Infra_Architecture: Infrastructure management by environment
    - Governance: Operational policies and documentation
    - Operations: (Future) Environment maintenance and operations
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath = 'D:\Dev\DCEC'
)
Begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'
    # Script-level variables
    $script:LogType = 'DIRSETUP'
    $script:LogDir = Join-Path -Path $RootPath -ChildPath 'Dev_Env\ClI\logs'
    $script:timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:LogFile = Join-Path -Path $script:LogDir -ChildPath ('{0}_{1}.log' -f $script:LogType, $script:timestamp)
    # Main project structure components
    $script:MainComponents = @{
        'Dev_Env' = @{
            'Description' = 'Development environment services and tools for consistent development continuity'
            'SubDirectories' = @(
                'ClI\bin',
                'ClI\lib',
                'ClI\Common',
                'ClI\config',
                'ClI\docs',
                'ClI\logs',
                'ClI\chat',
                'ClI\Modules',
                'ClI\Scripts',
                'ClI\Tests',
                'IDE\VScode',
                'Fonts',
                'MCP\Desktop',
                'MCP\Server',
                'n8n',
                'Powershell',
                'Integrade'
            )
        }
        'Infra_Architecture' = @{
            'Description' = 'Infrastructure management organized by environment and component type'
            'SubDirectories' = @(
                'NAS_Synology_DS920_Plus',
                'Router_ASUS_RT-AX88u',
                'Sub_Domain',
                'Vpn',
                'Network\Production',
                'Network\Development',
                'Network\Testing',
                'Hardware\Servers',
                'Hardware\Workstations',
                'Hardware\Storage',
                'Security\Certificates',
                'Security\Access_Control',
                'Monitoring\Logs',
                'Monitoring\Metrics',
                'chat'
            )
        }
        'Governance' = @{
            'Description' = 'Operational policies, documentation and governance projects'
            'SubDirectories' = @(
                'Policies\Development',
                'Policies\Operations',
                'Policies\Security',
                'Documentation\Architecture',
                'Documentation\Procedures',
                'Documentation\Standards',
                'Projects\Governance',
                'Templates\Documents',
                'Templates\Projects',
                'Compliance\Audit',
                'Compliance\Reports',
                'chat'
            )
        }
    }
    # Development services within Dev_Env
    $script:DevServices = @(
        'ClaudeCodeService',
        'GeminiService',
        'UtilsService',
        'BackupService'
    )
    $script:ServiceSubDirs = @(
        'config',
        'bin',
        'logs',
        'src',
        'tests',
        'docs'
    )
    # Templates
    $script:ConfigTemplate = @'
# Service authentication/security environment variables
API_KEY=__REPLACE_ME__
SECRET=__REPLACE_ME__
ENDPOINT=__REPLACE_ME__
'@
    $script:GitIgnoreTemplate = @'
# Security settings
secure.env
# Log files
logs/
*.log
# Build output
bin/
obj/
# Temporary files
temp/
*.tmp
'@
    function Initialize-LogDirectory {
        [CmdletBinding()]
        [OutputType([void])]
        param()
        if (-not (Test-Path -Path $script:LogDir)) {
            $null = New-Item -Path $script:LogDir -ItemType Directory -Force
            Write-Verbose -Message "Created log directory: $script:LogDir"
        }
    }
    function Write-ProjectLog {
        [CmdletBinding()]
        [OutputType([void])]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Type,
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Message,
            [Parameter()]
            [string]$Result = ''
        )
        $currentTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logLine = '{0} [{1}] {2}' -f $currentTime, $Type, $Message
        if ($Result) {
            $logLine += ' [{0}]' -f $Result
        }
        Add-Content -Path $script:LogFile -Value $logLine
        Write-Verbose -Message $logLine
    }
    function Convert-ToWslPath {
        [CmdletBinding()]
        [OutputType([string])]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Path
        )
        return $Path.Replace('\', '/').Replace('D:', '/mnt/d')
    }
    function Test-WslCommand {
        [CmdletBinding()]
        [OutputType([bool])]
        param()
        try {
            $null = & wsl bash -c 'exit'
            return $true
        }
        catch {
            Write-Warning -Message 'WSL installation is required'
            return $false
        }
    }
    function New-ServiceDirectory {
        [CmdletBinding(SupportsShouldProcess)]
        [OutputType([bool])]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Path
        )
        try {
            if ($PSCmdlet.ShouldProcess($Path, "Create directory")) {
                $wslPath = Convert-ToWslPath -Path $Path
                # Create Windows directory
                if (-not (Test-Path -Path $Path)) {
                    $null = New-Item -Path $Path -ItemType Directory -Force
                }
                # Create WSL directory
                $wslCommand = 'mkdir -p "{0}"' -f $wslPath
                $null = wsl bash -c $wslCommand
                # Verify existence
                $wslTestCommand = 'test -d "{0}"' -f $wslPath
                if ((Test-Path -Path $Path) -and (wsl bash -c $wslTestCommand)) {
                    Write-ProjectLog -Type $script:LogType -Message 'Directory creation completed' -Result $Path
                    return $true
                }
                else {
                    Write-ProjectLog -Type $script:LogType -Message 'Directory creation failed' -Result $Path
                    return $false
                }
            }
            return $false
        }
        catch {
            Write-ProjectLog -Type $script:LogType -Message 'Directory creation error' -Result ('{0} - {1}' -f $Path, $_)
            throw $_
        }
    }
    function New-ConfigFile {
        [CmdletBinding(SupportsShouldProcess)]
        [OutputType([bool])]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Path,
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Template
        )
        try {
            if (-not (Test-Path -Path $Path)) {
                if ($PSCmdlet.ShouldProcess($Path, "Create configuration file")) {
                    Set-Content -Path $Path -Value $Template
                    $wslPath = Convert-ToWslPath -Path $Path
                    $null = wsl bash -c ('chmod 600 "{0}"' -f $wslPath)
                    Write-ProjectLog -Type $script:LogType -Message 'Configuration file created' -Result $Path
                    return $true
                }
            }
            return $false
        }
        catch {
            Write-ProjectLog -Type $script:LogType -Message 'Configuration file creation failed' -Result ('{0} - {1}' -f $Path, $_)
            throw $_
        }
    }
    function New-DevService {
        [CmdletBinding()]
        [OutputType([void])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$DevEnvPath
        )
        try {
            Write-ProjectLog -Type $script:LogType -Message 'Creating development services'
            foreach ($service in $script:DevServices) {
                $servicePath = Join-Path -Path $DevEnvPath -ChildPath $service
                $null = New-ServiceDirectory -Path $servicePath
                # Create service subdirectories
                foreach ($subDir in $script:ServiceSubDirs) {
                    $fullPath = Join-Path -Path $servicePath -ChildPath $subDir
                    $null = New-ServiceDirectory -Path $fullPath
                }
                # Create service-specific config files
                $configPath = Join-Path -Path $servicePath -ChildPath 'config\secure.env'
                $null = New-ConfigFile -Path $configPath -Template $script:ConfigTemplate
                $gitignorePath = Join-Path -Path $servicePath -ChildPath '.gitignore'
                $null = New-ConfigFile -Path $gitignorePath -Template $script:GitIgnoreTemplate
                Write-ProjectLog -Type $script:LogType -Message "Development service created" -Result $service
            }
        }
        catch {
            Write-ProjectLog -Type $script:LogType -Message 'Development services creation error' -Result ('{0}' -f $_)
            throw $_
        }
    }
    function New-ProjectStructure {
        [CmdletBinding()]
        [OutputType([bool])]
        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$BasePath,
            [Parameter(Mandatory = $true)]
            [hashtable]$Structure
        )
        try {
            foreach ($component in $Structure.Keys) {
                $componentPath = Join-Path -Path $BasePath -ChildPath $component
                $componentInfo = $Structure[$component]
                Write-ProjectLog -Type $script:LogType -Message "Creating $component structure" -Result $componentInfo.Description
                # Create main component directory
                $null = New-ServiceDirectory -Path $componentPath
                # Create subdirectories
                foreach ($subDir in $componentInfo.SubDirectories) {
                    $fullPath = Join-Path -Path $componentPath -ChildPath $subDir
                    $null = New-ServiceDirectory -Path $fullPath
                }
                # Create component-specific documentation
                $readmePath = Join-Path -Path $componentPath -ChildPath 'README.md'
                $readmeContent = @"
# $component
## Description
$($componentInfo.Description)
## Directory Structure
$(($componentInfo.SubDirectories | ForEach-Object { "- $_" }) -join "`n")
## Usage
This directory contains the $component components of the DCEC project.
## Last Updated
$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
                if (-not (Test-Path -Path $readmePath)) {
                    Set-Content -Path $readmePath -Value $readmeContent
                    Write-ProjectLog -Type $script:LogType -Message 'Component README created' -Result $readmePath
                }
            }
            return $true
        }
        catch {
            Write-ProjectLog -Type $script:LogType -Message 'Project structure creation error' -Result ('{0}' -f $_)
            throw $_
        }
    }
}
Process {
    try {
        Initialize-LogDirectory
        Write-ProjectLog -Type $script:LogType -Message 'Starting complete DCEC project structure creation'
        # Check WSL installation
        if (-not (Test-WslCommand)) {
            throw 'WSL is required for this operation'
        }
        # Create main project structure (Dev_Env, Infra_Architecture, Governance)
        Write-ProjectLog -Type $script:LogType -Message 'Creating main project components'
        $null = New-ProjectStructure -BasePath $RootPath -Structure $script:MainComponents
        # Create global chat directory for cross-project conversations
        $globalChatPath = Join-Path -Path $RootPath -ChildPath 'chat'
        $null = New-ServiceDirectory -Path $globalChatPath
        Write-ProjectLog -Type $script:LogType -Message 'Global chat directory created' -Result $globalChatPath
        # Create development services within Dev_Env
        $devEnvPath = Join-Path -Path $RootPath -ChildPath 'Dev_Env'
        New-DevService -DevEnvPath $devEnvPath
        # Create main project README
        $mainReadmePath = Join-Path -Path $RootPath -ChildPath 'README.md'
        $mainReadmeContent = @"
# DCEC Project
## Overview
DCEC (Development, Infrastructure, Governance) project structure for comprehensive development environment management.
## Main Components
### 1. Dev_Env
Development environment services and tools for consistent development continuity across different environments.
### 2. Infra_Architecture
Infrastructure management organized by environment types (Production, Development, Testing) and component categories (Network, Hardware, Security, Monitoring).
### 3. Governance
Operational policies, documentation, and governance projects for maintaining project standards and compliance.
### 4. Operations (Future)
Will contain environment maintenance and operational procedures.
## Getting Started
1. Navigate to the appropriate component directory
2. Follow the README.md instructions in each component
3. Use the provided tools and scripts for environment setup
## Project Structure
```
DCEC/
├── Dev_Env/           # Development environment and services
├── Infra_Architecture/ # Infrastructure management
├── Governance/        # Policies and documentation
└── Operations/        # (Future) Maintenance and operations
```
## Last Updated
$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
        if (-not (Test-Path -Path $mainReadmePath)) {
            Set-Content -Path $mainReadmePath -Value $mainReadmeContent
            Write-ProjectLog -Type $script:LogType -Message 'Main project README created' -Result $mainReadmePath
        }
        Write-ProjectLog -Type $script:LogType -Message 'Complete DCEC project structure creation completed' -Result 'SUCCESS'
        Write-Output ('Complete DCEC project structure has been created. Log file: {0}' -f $script:LogFile)
        Write-Output ''
        Write-Output 'Project Structure Created:'
        Write-Output '├── Dev_Env - Development environment and services'
        Write-Output '├── Infra_Architecture - Infrastructure management'
        Write-Output '├── Governance - Policies and documentation'
        Write-Output '└── Operations - (Future) Maintenance and operations'
    }
    catch {
        Write-ProjectLog -Type $script:LogType -Message 'Fatal error occurred' -Result ('{0}' -f $_)
        throw $_
    }
}
End {
    Write-Verbose 'Script execution completed'
}
