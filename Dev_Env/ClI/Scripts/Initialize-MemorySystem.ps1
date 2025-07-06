#requires -Version 7.0
<#
.SYNOPSIS
    Initializes the DCEC memory system with global and sub-project specific storage.
.DESCRIPTION
    Creates a hierarchical memory system that supports:
    - Global memory for integration and cross-project information
    - Sub-project specific memory for isolated development
    - Context switching between global and project-specific memory
.PARAMETER MemoryScope
    Specifies the memory scope: Global, DevEnv, InfraArchitecture, or Governance
.PARAMETER RootPath
    The root path of the DCEC project. Default is 'D:\Dev\DCEC'.
.EXAMPLE
    .\Initialize-MemorySystem.ps1 -MemoryScope Global
    Initializes global memory system
.EXAMPLE
    .\Initialize-MemorySystem.ps1 -MemoryScope DevEnv
    Initializes Dev_Env specific memory system
.NOTES
    Author: DCEC Development Team
    Date: 2025-07-06
    Memory Structure:
    - Global: For integration and cross-project coordination
    - SubProject: For isolated sub-project development
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Global', 'DevEnv', 'InfraArchitecture', 'Governance')]
    [string]$MemoryScope,
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath = 'D:\Dev\DCEC'
)
Begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'
    # Memory configuration
    $script:MemoryConfig = @{
        'Global' = @{
            'Path' = Join-Path -Path $RootPath -ChildPath 'Global_Memory'
            'Description' = 'Global memory for integration and cross-project coordination'
            'Categories' = @(
                'Integration',
                'CrossProject',
                'Architecture',
                'Planning',
                'Issues',
                'Decisions'
            )
        }
        'DevEnv' = @{
            'Path' = Join-Path -Path $RootPath -ChildPath 'Dev_Env\Memory'
            'Description' = 'Development environment specific memory'
            'Categories' = @(
                'CLI',
                'Tools',
                'Services',
                'Configuration',
                'Scripts',
                'Modules'
            )
        }
        'InfraArchitecture' = @{
            'Path' = Join-Path -Path $RootPath -ChildPath 'Infra_Architecture\Memory'
            'Description' = 'Infrastructure architecture specific memory'
            'Categories' = @(
                'Network',
                'Hardware',
                'Security',
                'Monitoring',
                'Environments',
                'Configurations'
            )
        }
        'Governance' = @{
            'Path' = Join-Path -Path $RootPath -ChildPath 'Governance\Memory'
            'Description' = 'Governance specific memory'
            'Categories' = @(
                'Policies',
                'Documentation',
                'Standards',
                'Compliance',
                'Templates',
                'Procedures'
            )
        }
    }
    function New-MemoryStructure {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Scope,
            [Parameter(Mandatory = $true)]
            [hashtable]$Config
        )
        $memoryPath = $Config.Path
        $categories = $Config.Categories
        Write-Host "Initializing $Scope memory system..." -ForegroundColor Cyan
        # Create main memory directory
        if (-not (Test-Path -Path $memoryPath)) {
            $null = New-Item -Path $memoryPath -ItemType Directory -Force
            Write-Host "  ✓ Created memory directory: $memoryPath" -ForegroundColor Green
        }
        # Create category subdirectories
        foreach ($category in $categories) {
            $categoryPath = Join-Path -Path $memoryPath -ChildPath $category
            if (-not (Test-Path -Path $categoryPath)) {
                $null = New-Item -Path $categoryPath -ItemType Directory -Force
                Write-Host "  ✓ Created category: $category" -ForegroundColor Green
            }
        }
        # Create memory configuration file
        $configPath = Join-Path -Path $memoryPath -ChildPath 'memory_config.json'
        $memoryConfigData = @{
            Scope = $Scope
            Description = $Config.Description
            CreatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Categories = $categories
            ChatSessions = @()
            LastAccessed = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
        $memoryConfigData | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath
        Write-Host "  ✓ Created memory configuration" -ForegroundColor Green
        # Create session management files
        $sessionsPath = Join-Path -Path $memoryPath -ChildPath 'sessions.json'
        $initialSessions = @{
            CurrentSession = $null
            Sessions = @()
            LastSessionId = 0
        }
        $initialSessions | ConvertTo-Json -Depth 10 | Set-Content -Path $sessionsPath
        Write-Host "  ✓ Created session management" -ForegroundColor Green
        # Create README for the memory system
        $readmePath = Join-Path -Path $memoryPath -ChildPath 'README.md'
        $readmeContent = @"
# $Scope Memory System
## Description
$($Config.Description)
## Structure
This memory system contains the following categories:
$(($categories | ForEach-Object { "- **$_**: Category for $_ related information" }) -join "`n")
## Usage
- Use this memory system to store persistent information for $Scope
- Chat sessions and context are automatically saved here
- Each category contains specific type of information
- Memory is preserved across IDE restarts
## Files
- `memory_config.json`: Memory system configuration
- `sessions.json`: Chat session management
- `current_context.json`: Current working context
- Category folders: Organized information storage
## Integration
- Global memory: Used for cross-project coordination
- Sub-project memory: Used for isolated development
- Context switching available between scopes
## Last Updated
$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
"@
        Set-Content -Path $readmePath -Value $readmeContent
        Write-Host "  ✓ Created README documentation" -ForegroundColor Green
        return $memoryPath
    }
    function New-ContextFile {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$MemoryPath,
            [Parameter(Mandatory = $true)]
            [string]$Scope
        )
        $contextPath = Join-Path -Path $MemoryPath -ChildPath 'current_context.json'
        $contextData = @{
            Scope = $Scope
            CurrentTask = 'Memory system initialization'
            WorkingDirectory = $MemoryPath
            LastUpdate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            ActiveCategories = @()
            RecentFiles = @()
            Notes = @(
                "Memory system initialized for $Scope",
                "Ready for persistent storage and context management"
            )
        }
        $contextData | ConvertTo-Json -Depth 10 | Set-Content -Path $contextPath
        Write-Host "  ✓ Created current context file" -ForegroundColor Green
    }
}
Process {
    try {
        Write-Host "`n=== DCEC Memory System Initialization ===" -ForegroundColor Yellow
        Write-Host "Scope: $MemoryScope" -ForegroundColor White
        $config = $script:MemoryConfig[$MemoryScope]
        if (-not $config) {
            throw "Invalid memory scope: $MemoryScope"
        }
        # Initialize memory structure
        $memoryPath = New-MemoryStructure -Scope $MemoryScope -Config $config
        # Create context file
        New-ContextFile -MemoryPath $memoryPath -Scope $MemoryScope
        Write-Host "`n✅ $MemoryScope memory system initialized successfully!" -ForegroundColor Green
        Write-Host "📁 Memory location: $memoryPath" -ForegroundColor Gray
        Write-Host "`n🎯 Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Start chat sessions in this scope" -ForegroundColor White
        Write-Host "  2. Store context and decisions" -ForegroundColor White
        Write-Host "  3. Switch between global and project scopes as needed" -ForegroundColor White
        # Return memory path for further use
        return $memoryPath
    }
    catch {
        Write-Error "Failed to initialize memory system: $_"
        throw
    }
}
End {
    Write-Verbose 'Memory system initialization completed'
}
