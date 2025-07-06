#requires -Version 7.0
<#
.SYNOPSIS
    Manages DCEC memory system context switching and chat session management.
.DESCRIPTION
    Provides functionality to:
    - Switch between Global and Sub-project memory contexts
    - Start and manage chat sessions
    - Store and retrieve persistent context
    - Maintain continuity across IDE restarts
.PARAMETER Action
    The action to perform: Switch, StartSession, SaveContext, LoadContext, or Status
.PARAMETER Scope
    The memory scope: Global, DevEnv, InfraArchitecture, or Governance
.PARAMETER SessionName
    Name for the chat session (optional)
.EXAMPLE
    .\Manage-MemorySystem.ps1 -Action Switch -Scope Global
    Switches to global memory context
.EXAMPLE
    .\Manage-MemorySystem.ps1 -Action StartSession -Scope DevEnv -SessionName "CLI-Development"
    Starts a new chat session in Dev_Env scope
.EXAMPLE
    .\Manage-MemorySystem.ps1 -Action Status
    Shows current memory system status
.NOTES
    Author: DCEC Development Team
    Date: 2025-07-06
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Switch', 'StartSession', 'SaveContext', 'LoadContext', 'Status')]
    [string]$Action,
    [Parameter()]
    [ValidateSet('Global', 'DevEnv', 'InfraArchitecture', 'Governance')]
    [string]$Scope,
    [Parameter()]
    [string]$SessionName,
    [Parameter()]
    [string]$RootPath = 'D:\Dev\DCEC'
)
Begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'
    # Memory paths configuration
    $script:MemoryPaths = @{
        'Global' = Join-Path -Path $RootPath -ChildPath 'Global_Memory'
        'DevEnv' = Join-Path -Path $RootPath -ChildPath 'Dev_Env\Memory'
        'InfraArchitecture' = Join-Path -Path $RootPath -ChildPath 'Infra_Architecture\Memory'
        'Governance' = Join-Path -Path $RootPath -ChildPath 'Governance\Memory'
    }
    # Current context file
    $script:CurrentContextFile = Join-Path -Path $RootPath -ChildPath '.current_memory_context.json'
    function Get-CurrentContext {
        [CmdletBinding()]
        [OutputType([hashtable])]
        param()
        if (Test-Path -Path $script:CurrentContextFile) {
            try {
                $content = Get-Content -Path $script:CurrentContextFile -Raw | ConvertFrom-Json
                return @{
                    Scope = $content.Scope
                    SessionId = $content.SessionId
                    SessionName = $content.SessionName
                    LastUpdate = $content.LastUpdate
                    MemoryPath = $content.MemoryPath
                }
            }
            catch {
                Write-Warning "Failed to read current context: $_"
                return @{}
            }
        }
        return @{}
    }
    function Set-CurrentContext {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Scope,
            [Parameter()]
            [string]$SessionId = '',
            [Parameter()]
            [string]$SessionName = '',
            [Parameter(Mandatory = $true)]
            [string]$MemoryPath
        )
        $context = @{
            Scope = $Scope
            SessionId = $SessionId
            SessionName = $SessionName
            LastUpdate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            MemoryPath = $MemoryPath
        }
        $context | ConvertTo-Json -Depth 10 | Set-Content -Path $script:CurrentContextFile
        Write-Host "✓ Context switched to: $Scope" -ForegroundColor Green
    }
    function Switch-MemoryContext {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$TargetScope
        )
        $memoryPath = $script:MemoryPaths[$TargetScope]
        if (-not (Test-Path -Path $memoryPath)) {
            Write-Warning "Memory system for $TargetScope not found. Initializing..."
            & "$PSScriptRoot\Initialize-MemorySystem.ps1" -MemoryScope $TargetScope -RootPath $RootPath
        }
        Set-CurrentContext -Scope $TargetScope -MemoryPath $memoryPath
        Write-Host "`n📍 Switched to $TargetScope memory context" -ForegroundColor Cyan
        Write-Host "📁 Memory path: $memoryPath" -ForegroundColor Gray
        # Load current context from scope
        $contextFile = Join-Path -Path $memoryPath -ChildPath 'current_context.json'
        if (Test-Path -Path $contextFile) {
            $scopeContext = Get-Content -Path $contextFile -Raw | ConvertFrom-Json
            Write-Host "📝 Current task: $($scopeContext.CurrentTask)" -ForegroundColor Yellow
        }
    }
    function Start-ChatSession {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Scope,
            [Parameter()]
            [string]$SessionName
        )
        $memoryPath = $script:MemoryPaths[$Scope]
        $sessionsFile = Join-Path -Path $memoryPath -ChildPath 'sessions.json'
        if (-not (Test-Path -Path $sessionsFile)) {
            Write-Error "Memory system for $Scope not initialized. Run Initialize-MemorySystem first."
            return
        }
        # Load existing sessions
        $sessions = Get-Content -Path $sessionsFile -Raw | ConvertFrom-Json
        # Generate new session
        $sessionId = "session_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        if (-not $SessionName) {
            $SessionName = "Chat_$(Get-Date -Format 'MMdd_HHmm')"
        }
        $newSession = @{
            Id = $sessionId
            Name = $SessionName
            Scope = $Scope
            StartTime = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            LastActivity = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            MessagesCount = 0
            Status = 'Active'
        }
        # Update sessions
        $sessions.CurrentSession = $sessionId
        $sessions.LastSessionId = [int]$sessions.LastSessionId + 1
        $sessions.Sessions += $newSession
        # Save updated sessions
        $sessions | ConvertTo-Json -Depth 10 | Set-Content -Path $sessionsFile
        # Create session directory
        $sessionDir = Join-Path -Path $memoryPath -ChildPath "Sessions\$sessionId"
        $null = New-Item -Path $sessionDir -ItemType Directory -Force
        # Update current context
        Set-CurrentContext -Scope $Scope -SessionId $sessionId -SessionName $SessionName -MemoryPath $memoryPath
        Write-Host "✅ Started new chat session: $SessionName" -ForegroundColor Green
        Write-Host "🆔 Session ID: $sessionId" -ForegroundColor Gray
        Write-Host "📁 Session path: $sessionDir" -ForegroundColor Gray
        return $sessionId
    }
    function Show-MemoryStatus {
        [CmdletBinding()]
        param()
        Write-Host "`n=== DCEC Memory System Status ===" -ForegroundColor Yellow
        # Current context
        $currentContext = Get-CurrentContext
        if ($currentContext.Scope) {
            Write-Host "`n📍 Current Context:" -ForegroundColor Cyan
            Write-Host "  Scope: $($currentContext.Scope)" -ForegroundColor White
            Write-Host "  Session: $($currentContext.SessionName)" -ForegroundColor White
            Write-Host "  Last Update: $($currentContext.LastUpdate)" -ForegroundColor Gray
        } else {
            Write-Host "`n⚠️  No active memory context" -ForegroundColor Yellow
        }
        # Available memory systems
        Write-Host "`n💾 Available Memory Systems:" -ForegroundColor Cyan
        foreach ($scope in $script:MemoryPaths.Keys) {
            $path = $script:MemoryPaths[$scope]
            $status = if (Test-Path -Path $path) { "✅ Initialized" } else { "❌ Not initialized" }
            Write-Host "  $scope : $status" -ForegroundColor White
            if (Test-Path -Path $path) {
                $sessionsFile = Join-Path -Path $path -ChildPath 'sessions.json'
                if (Test-Path -Path $sessionsFile) {
                    $sessions = Get-Content -Path $sessionsFile -Raw | ConvertFrom-Json
                    $activeCount = ($sessions.Sessions | Where-Object { $_.Status -eq 'Active' }).Count
                    Write-Host "    Sessions: $activeCount active" -ForegroundColor Gray
                }
            }
        }
        Write-Host "`n🎯 Available Actions:" -ForegroundColor Yellow
        Write-Host "  Switch context: .\Manage-MemorySystem.ps1 -Action Switch -Scope <Scope>" -ForegroundColor White
        Write-Host "  Start session: .\Manage-MemorySystem.ps1 -Action StartSession -Scope <Scope>" -ForegroundColor White
    }
}
Process {
    try {
        switch ($Action) {
            'Switch' {
                if (-not $Scope) {
                    throw "Scope parameter is required for Switch action"
                }
                Switch-MemoryContext -TargetScope $Scope
            }
            'StartSession' {
                if (-not $Scope) {
                    throw "Scope parameter is required for StartSession action"
                }
                Start-ChatSession -Scope $Scope -SessionName $SessionName
            }
            'Status' {
                Show-MemoryStatus
            }
            'SaveContext' {
                Write-Host "SaveContext action - Implementation pending" -ForegroundColor Yellow
            }
            'LoadContext' {
                Write-Host "LoadContext action - Implementation pending" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Error "Failed to execute action '$Action': $_"
        throw
    }
}
End {
    Write-Verbose 'Memory system management completed'
}
