#requires -Version 7.0
<#
.SYNOPSIS
    Main project setup script v2 for DCEC environment.
.DESCRIPTION
    Sets up and manages all services and integration environments for the DCEC project.
    This script handles:
    - Core directory structure creation
    - Service initialization and dependency management
    - Environment configuration
    - Backup services
    - Workflow management
    - Status reporting
.PARAMETER RootPath
    The root path where the DCEC environment will be set up.
    Defaults to "Dev\DCEC" under the user's profile directory.
.EXAMPLE
    .\create_project_dirs_v2.ps1
    Sets up the project structure in the default location.
.EXAMPLE
    .\create_project_dirs_v2.ps1 -RootPath "D:\Projects\DCEC"
    Sets up the project structure in the specified location.
.NOTES
    This is version 2 of the setup script with improved:
    - Error handling
    - Modularity
    - Status reporting
    - Service dependency management
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath = (Join-Path $env:USERPROFILE "Dev\DCEC")
)
# Initialize script
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
# Basic path setup
$script:envPath = Join-Path -Path $RootPath -ChildPath 'Dev_Env'
$script:corePath = Join-Path -Path $envPath -ChildPath 'Core'
$script:servicesPath = Join-Path -Path $envPath -ChildPath 'Services'
$script:integrationPath = Join-Path -Path $envPath -ChildPath 'Integration'
$script:modulePath = Join-Path -Path $envPath -ChildPath 'ClI\Scripts\modules'
# Define required core modules
[string[]]$requiredModules = @(
    'core/logging_system.ps1',
    'core/directory_setup.ps1'
)
# Define optional enhancement modules
[string[]]$optionalModules = @(
    'core/env_manager.ps1',
    'core/doc_template_manager.ps1',
    'services/backup_service.ps1',
    'services/claude_service.ps1',
    'services/utils_service.ps1',
    'integration/workflow_manager.ps1'
)
# Load required modules
foreach ($module in $requiredModules) {
    $modulePath = Join-Path -Path $script:modulePath -ChildPath $module
    if (Test-Path -Path $modulePath) {
        try {
            . $modulePath
            Write-Verbose -Message ('Required module loaded: {0}' -f $module)
        }
        catch {
            throw ('Failed to load required module {0}: {1}' -f $module, $_.Exception.Message)
        }
    }
    else {
        throw ('Required module not found: {0}' -f $module)
    }
}
# Load optional modules
foreach ($module in $optionalModules) {
    $modulePath = Join-Path -Path $script:modulePath -ChildPath $module
    if (Test-Path -Path $modulePath) {
        try {
            . $modulePath
            Write-Verbose -Message ('Optional module loaded: {0}' -f $module)
        }
        catch {
            Write-Warning -Message ('Failed to load optional module {0}: {1}' -f $module, $_.Exception.Message)
        }
    }
    else {
        Write-Warning -Message ('Optional module not found: {0}' -f $module)
    }
}
# Verify required functions
[string[]]$requiredFunctions = @(
    'Initialize-LoggingSystem',
    'Initialize-CoreDirectories',
    'Initialize-Environment'
)
$missingFunctions = $requiredFunctions.Where{
    -not (Get-Command -Name $_ -ErrorAction SilentlyContinue)
}
if ($missingFunctions) {
    throw ('Required functions not found: {0}' -f ($missingFunctions -join ', '))
}
# 1. Initialize logging system
try {
    Initialize-LoggingSystem
    Write-Log -Type 'SETUP' -Message 'Starting project setup' -Level 'INFO'
}
catch {
    throw ('Failed to initialize logging system: {0}' -f $_.Exception.Message)
}
# 2. Create core directory structure
try {
    Initialize-CoreDirectories -RootPath $corePath
    Write-Log -Type 'SETUP' -Message 'Core directory structure created successfully' -Level 'SUCCESS'
}
catch {
    Write-Log -Type 'SETUP' -Message ('Failed to create core directory structure: {0}' -f $_.Exception.Message) -Level 'ERROR'
    throw
}
# 3. Initialize environment variables
try {
    $envConfigPath = Join-Path -Path $corePath -ChildPath 'Env'
    Initialize-Environment -EnvPath $envConfigPath
    Write-Log -Type 'SETUP' -Message 'Environment variables initialized successfully' -Level 'SUCCESS'
}
catch {
    Write-Log -Type 'SETUP' -Message ('Failed to initialize environment: {0}' -f $_.Exception.Message) -Level 'ERROR'
    throw
}
# 4. Initialize services
[hashtable[]]$services = @(
    @{
        Name = 'Claude'
        Path = Join-Path -Path $servicesPath -ChildPath 'Claude'
        Dependencies = @()
        InitFunction = 'Initialize-ClaudeService'
    },
    @{
        Name = 'Utils'
        Path = Join-Path -Path $servicesPath -ChildPath 'Utils'
        Dependencies = @('Claude')
        InitFunction = 'Initialize-UtilsService'
    }
)
foreach ($service in $services) {
    try {
        # Create service directory
        if (-not (Test-Path -Path $service.Path)) {
            $null = New-Item -Path $service.Path -ItemType Directory -Force
            Write-Log -Type 'SETUP' -Message ('Created service directory: {0}' -f $service.Path) -Level 'INFO'
        }
        # Verify and execute service initialization function
        $initFunction = Get-Command -Name $service.InitFunction -ErrorAction SilentlyContinue
        if ($initFunction) {
            & $initFunction -ServicePath $service.Path
            Write-Log -Type 'SETUP' -Message ('Initialized service: {0}' -f $service.Name) -Level 'SUCCESS'
            # Register dependencies if available
            if ($service.Dependencies.Count -gt 0) {
                $registerDependency = Get-Command -Name 'Register-ServiceDependency' -ErrorAction SilentlyContinue
                if ($registerDependency) {
                    foreach ($dep in $service.Dependencies) {
                        Register-ServiceDependency -ServiceName $service.Name -DependsOn $dep
                        Write-Log -Type 'SETUP' -Message ('Registered dependency {0} -> {1}' -f $service.Name, $dep) -Level 'INFO'
                    }
                    Write-Log -Type 'SETUP' -Message ('Completed dependency registration for: {0}' -f $service.Name) -Level 'SUCCESS'
                }
                else {
                    Write-Warning -Message 'Service dependency registration is not available'
                }
            }
        }
        else {
            Write-Warning -Message ('Service initialization function not found: {0}' -f $service.InitFunction)
        }
    }
    catch {
        Write-Log -Type 'SETUP' -Message ('Failed to setup service {0}: {1}' -f $service.Name, $_.Exception.Message) -Level 'ERROR'
        throw
    }
}
# 5. Optional workflow and backup tasks
[hashtable]$optionalFunctions = @{
    'Initialize-IntegrationWorkflow' = {
        param([string]$Path)
        Initialize-IntegrationWorkflow -IntegrationRoot $Path
        Write-Log -Type 'SETUP' -Message 'Integration workflow initialized successfully' -Level 'SUCCESS'
    }
    'Backup-GlobalPackages' = {
        Backup-GlobalPackages
        Write-Log -Type 'SETUP' -Message 'Global packages backup completed' -Level 'SUCCESS'
    }
    'Start-ServiceWorkflow' = {
        Start-ServiceWorkflow
        Write-Log -Type 'SETUP' -Message 'Service workflow started successfully' -Level 'SUCCESS'
    }
}
foreach ($funcName in $optionalFunctions.Keys) {
    $function = Get-Command -Name $funcName -ErrorAction SilentlyContinue
    if ($function) {
        try {
            Write-Log -Type 'SETUP' -Message ('Executing optional function: {0}' -f $funcName) -Level 'INFO'
            switch ($funcName) {
                'Initialize-IntegrationWorkflow' {
                    & $optionalFunctions[$funcName] $integrationPath
                }
                default {
                    & $optionalFunctions[$funcName]
                }
            }
        }
        catch {
            Write-Log -Type 'SETUP' -Message ('Failed to execute {0}: {1}' -f $funcName, $_.Exception.Message) -Level 'WARNING'
        }
    }
    else {
        Write-Verbose -Message ('Optional function not available: {0}' -f $funcName)
    }
}
# 6. Generate status report
try {
    # Get workflow status if available
    $status = if (Get-Command -Name 'Get-WorkflowStatus' -ErrorAction SilentlyContinue) {
        Get-WorkflowStatus
    }
    else {
        @{
            ActiveServices = @()
            InactiveServices = @()
            Issues = @()
        }
    }
    # Get backup report if available
    $backupReport = if (Get-Command -Name 'Get-BackupServiceReport' -ErrorAction SilentlyContinue) {
        Get-BackupServiceReport
    }
    else {
        @{
            BackupCounts = @{}
            TotalSize = 0
        }
    }
    # Prepare report data
    $report = @{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        ActiveServices = $status.ActiveServices ?? @()
        InactiveServices = $status.InactiveServices ?? @()
        BackupStatus = $backupReport
        Issues = $status.Issues ?? @()
    }
    # Save report to file
    $reportPath = Join-Path -Path $corePath -ChildPath 'Logs' -AdditionalChildPath 'setup_report.json'
    $null = New-Item -Path (Split-Path $reportPath) -ItemType Directory -Force -ErrorAction SilentlyContinue
    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
    Write-Log -Type 'SETUP' -Message 'Project setup completed successfully' -Level 'SUCCESS'
    Write-Log -Type 'SETUP' -Message ('Status report generated: {0}' -f $reportPath) -Level 'INFO'
    # Display setup summary
    Write-Host "`n=== Project Setup Summary ===" -ForegroundColor Cyan
    if ($status.ActiveServices) {
        Write-Host ('Active Services: {0}' -f ($status.ActiveServices -join ', ')) -ForegroundColor Green
    }
    if ($status.InactiveServices) {
        Write-Host ('Inactive Services: {0}' -f ($status.InactiveServices -join ', ')) -ForegroundColor Yellow
    }
    if ($status.Issues) {
        Write-Host "`nWarnings:" -ForegroundColor Yellow
        $status.Issues | ForEach-Object {
            Write-Host ('- {0}' -f $_) -ForegroundColor Yellow
        }
    }
    if ($backupReport.BackupCounts) {
        Write-Host "`nBackup Status:" -ForegroundColor Cyan
        Write-Host ('Total Backup Size: {0:N2} MB' -f (($backupReport.TotalSize ?? 0) / 1MB)) -ForegroundColor Gray
        foreach ($type in $backupReport.BackupCounts.Keys) {
            Write-Host ('{0}: {1} files' -f $type, $backupReport.BackupCounts[$type]) -ForegroundColor Gray
        }
    }
}
catch {
    Write-Log -Type 'SETUP' -Message ('Failed to generate status report: {0}' -f $_.Exception.Message) -Level 'ERROR'
    throw
}
End {
    # Clean up and finalize
    Write-Verbose 'Project setup script completed'
    Write-Verbose ('Total execution time: {0:N2} seconds' -f $($Host.PrivateData.Timer.TotalSeconds))
}
