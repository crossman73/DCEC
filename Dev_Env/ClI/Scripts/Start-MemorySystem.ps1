#requires -Version 7.0
<#
.SYNOPSIS
    DCEC Memory System Starter - Quick initialization for project-scoped memory management
.DESCRIPTION
    Provides quick start commands for initializing the DCEC memory system in different scopes:
    - Global: Cross-project conversations and integration tasks
    - Dev_Env: Development environment management
    - Infra_Architecture: Infrastructure and network management
    - Governance: Policies and documentation management
.PARAMETER ProjectScope
    The scope of the project memory to initialize.
    Valid values: Global, Dev_Env, Infra_Architecture, Governance
.PARAMETER ProjectName
    The name of the project/session to track
.PARAMETER WorkContext
    The work context description
.EXAMPLE
    .\Start-MemorySystem.ps1 -ProjectScope Global -ProjectName "DCEC_Integration" -WorkContext "Cross_Project_Coordination"
.EXAMPLE
    .\Start-MemorySystem.ps1 -ProjectScope Dev_Env -ProjectName "CLI_Quality_Management" -WorkContext "PowerShell_Development"
.NOTES
    Author: DCEC Development Team
    Date: 2025-07-06
    Version: 1.0
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Global', 'Dev_Env', 'Infra_Architecture', 'Governance')]
    [string]$ProjectScope,
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,
    [Parameter()]
    [string]$WorkContext = "General",
    [Parameter()]
    [string]$ProblemId = ""
)
Begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    # Import memory management module
    $memoryModulePath = Join-Path $PSScriptRoot "Memory-Manager.ps1"
    if (-not (Test-Path $memoryModulePath)) {
        throw "Memory-Manager.ps1 not found at: $memoryModulePath"
    }
    Import-Module $memoryModulePath -Force
}
Process {
    try {
        Write-Host "🚀 DCEC Memory System Initialization" -ForegroundColor Cyan
        Write-Host "=" * 50 -ForegroundColor Cyan
        # Display scope information
        $scopeDescriptions = @{
            'Global' = 'Cross-project conversations and integration tasks'
            'Dev_Env' = 'Development environment and CLI management'
            'Infra_Architecture' = 'Infrastructure and network management'
            'Governance' = 'Policies, documentation and governance'
        }
        Write-Host "📋 Project Information:" -ForegroundColor Yellow
        Write-Host "   • Scope: $ProjectScope" -ForegroundColor White
        Write-Host "   • Description: $($scopeDescriptions[$ProjectScope])" -ForegroundColor Gray
        Write-Host "   • Project Name: $ProjectName" -ForegroundColor White
        Write-Host "   • Work Context: $WorkContext" -ForegroundColor White
        if ($ProblemId) {
            Write-Host "   • Problem ID: $ProblemId" -ForegroundColor White
        }
        # Initialize memory system
        $sessionId = Initialize-MemorySystem -ProjectName $ProjectName -ProjectScope $ProjectScope -WorkContext $WorkContext -ProblemId $ProblemId
        # Show available commands
        Write-Host "`n📚 Available Memory Commands:" -ForegroundColor Green
        Write-Host "   • Switch-ProjectScope -NewScope <Scope>     # Switch to different project scope" -ForegroundColor Gray
        Write-Host "   • Add-MemoryPoint -Topic <Topic> -Description <Description>  # Add important memory point" -ForegroundColor Gray
        Write-Host "   • Search-ConversationHistory -SearchTerm <Term>  # Search conversation history" -ForegroundColor Gray
        Write-Host "   • Show-MemorySummary                        # Display current memory status" -ForegroundColor Gray
        Write-Host "   • Resume-ConversationContext                # Resume previous conversation context" -ForegroundColor Gray
        Write-Host "   • Export-MemorySnapshot                     # Export memory snapshot" -ForegroundColor Gray
        # Display quick start tips
        Write-Host "`n💡 Quick Start Tips:" -ForegroundColor Magenta
        Write-Host "   • Your conversations are saved to:" -ForegroundColor Gray
        switch ($ProjectScope) {
            'Global' {
                Write-Host "     D:\Dev\DCEC\chat\" -ForegroundColor Yellow
                Write-Host "   • Use this scope for integration and cross-project work" -ForegroundColor Gray
            }
            'Dev_Env' {
                Write-Host "     D:\Dev\DCEC\Dev_Env\chat\" -ForegroundColor Yellow
                Write-Host "   • Use this scope for CLI, development tools, and coding work" -ForegroundColor Gray
            }
            'Infra_Architecture' {
                Write-Host "     D:\Dev\DCEC\Infra_Architecture\chat\" -ForegroundColor Yellow
                Write-Host "   • Use this scope for network, hardware, and infrastructure work" -ForegroundColor Gray
            }
            'Governance' {
                Write-Host "     D:\Dev\DCEC\Governance\chat\" -ForegroundColor Yellow
                Write-Host "   • Use this scope for policies, documentation, and governance work" -ForegroundColor Gray
            }
        }
        Write-Host "   • Memory persists across IDE restarts!" -ForegroundColor Green
        Write-Host "   • Switch scopes anytime with Switch-ProjectScope" -ForegroundColor Green
        Write-Host "`n🎯 Memory system is ready for work!" -ForegroundColor Green
        return $sessionId
    }
    catch {
        Write-Error "Failed to initialize memory system: $_"
        throw
    }
}
End {
    Write-Verbose "Memory system initialization completed"
}
