#requires -Version 7.0
<#
.SYNOPSIS
    DCEC Memory Management System - Chat session continuity and context preservation
.DESCRIPTION
    Provides comprehensive memory management for AI chat sessions including:
    - Session continuity across IDE restarts
    - Context preservation and retrieval
    - Conversation history management
    - Problem tracking integration
    - Project state maintenance
.EXAMPLE
    Import-Module .\Memory-Manager.ps1
    Initialize-MemorySystem -ProjectName "DCEC_CLI" -WorkContext "PowerShell_Development"
.EXAMPLE
    $context = Get-SessionContext -Days 7
    Resume-ConversationContext -SessionId "SESSION_DCEC_20250706_144223"
.NOTES
    Author: DCEC Development Team
    Date: 2025-07-06
    Version: 1.0
    Dependencies: DCECCore logging system
#>
[CmdletBinding()]
param()
# Import required modules and setup logging
$ModulePath = Join-Path $PSScriptRoot "..\Modules\DCECCore\DCECCore.psm1"
if (Test-Path $ModulePath) {
    try {
        Import-Module $ModulePath -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "DCECCore module import failed: $_"
    }
}
# Fallback logging functions if DCECCore not available
if (-not (Get-Command Initialize-Logging -ErrorAction SilentlyContinue)) {
    function Initialize-Logging {
        param([string]$LogPath)
        $global:MemoryLogFile = Join-Path $LogPath "memory_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        if (-not (Test-Path $LogPath)) {
            New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
        }
        return $global:MemoryLogFile
    }
}
if (-not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    function Write-Log {
        param([string]$Level, [string]$Message, [string]$Result = "", [string]$Category = "")
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logLine = "[$timestamp] [$Level] [$Category] $Message"
        if ($Result) { $logLine += " [$Result]" }
        Write-Host $logLine -ForegroundColor $(if($Level -eq "ERROR"){"Red"} elseif($Level -eq "WARN"){"Yellow"} else {"White"})
        if ($global:MemoryLogFile) {
            Add-Content -Path $global:MemoryLogFile -Value $logLine
        }
    }
}
if (-not (Get-Command Initialize-ChatLogging -ErrorAction SilentlyContinue)) {
    function Initialize-ChatLogging {
        param([string]$ProjectName, [string]$ProblemId = "")
        $chatFile = Join-Path $script:MemoryConfig.CurrentChatDir "$ProjectName`_$(Get-Date -Format 'yyMMddHHmmss').chat"
        $global:CurrentChatFile = $chatFile
        $header = @"
===========================================
Session ID: $global:SessionId
Project: $ProjectName
Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Problem ID: $ProblemId
===========================================
"@
        Set-Content -Path $chatFile -Value $header
        Write-Log -Level INFO -Message "Chat logging initialized" -Result $chatFile -Category "Memory"
    }
}
if (-not (Get-Command Add-ChatSummaryPoint -ErrorAction SilentlyContinue)) {
    function Add-ChatSummaryPoint {
        param([string]$Point)
        if ($null -eq $global:ChatSummaryPoints) { $global:ChatSummaryPoints = @() }
        $global:ChatSummaryPoints += $Point
        Write-Log -Level INFO -Message "Chat summary point added" -Result $Point -Category "Memory"
    }
}
# Memory system configuration
$script:MemoryConfig = @{
    # Global memory for cross-project conversations
    GlobalChatDir = "d:\Dev\DCEC\chat"
    GlobalContextFile = "d:\Dev\DCEC\chat\global_context.json"
    # Project-specific memory locations
    ProjectDirs = @{
        'Dev_Env' = "d:\Dev\DCEC\Dev_Env\ClI\chat"
        'Infra_Architecture' = "d:\Dev\DCEC\Infra_Architecture\chat"
        'Governance' = "d:\Dev\DCEC\Governance\chat"
    }
    # Current project context (will be set dynamically)
    CurrentProject = $null
    CurrentChatDir = $null
    CurrentContextFile = $null
    # General settings
    MaxContextDays = 30
    MaxSessions = 100
}
function Initialize-MemorySystem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectName,
        [Parameter()]
        [ValidateSet('Global', 'Dev_Env', 'Infra_Architecture', 'Governance')]
        [string]$ProjectScope = 'Global',
        [Parameter()]
        [string]$WorkContext = "General",
        [Parameter()]
        [string]$ProblemId = ""
    )
    try {
        Write-Host "🧠 Initializing DCEC Memory System..." -ForegroundColor Cyan
        Write-Host "   Project: $ProjectName" -ForegroundColor Yellow
        Write-Host "   Scope: $ProjectScope" -ForegroundColor Yellow
        # Set current project context
        $script:MemoryConfig.CurrentProject = $ProjectScope
        if ($ProjectScope -eq 'Global') {
            $script:MemoryConfig.CurrentChatDir = $script:MemoryConfig.GlobalChatDir
            $script:MemoryConfig.CurrentContextFile = $script:MemoryConfig.GlobalContextFile
        } else {
            $script:MemoryConfig.CurrentChatDir = $script:MemoryConfig.ProjectDirs[$ProjectScope]
            $script:MemoryConfig.CurrentContextFile = Join-Path $script:MemoryConfig.ProjectDirs[$ProjectScope] "context.json"
        }
        # Initialize logging system if not already done
        $baseDir = if ($ProjectScope -eq 'Global') {
            "d:\Dev\DCEC"
        } else {
            Split-Path $script:MemoryConfig.CurrentChatDir -Parent
        }
        Initialize-Logging -LogPath $baseDir | Out-Null
        # Create memory directories
        $memoryDirs = @(
            $script:MemoryConfig.CurrentChatDir,
            (Split-Path $script:MemoryConfig.CurrentContextFile)
        )
        # Also ensure global directory exists for cross-project access
        if ($ProjectScope -ne 'Global') {
            $memoryDirs += $script:MemoryConfig.GlobalChatDir
            $memoryDirs += (Split-Path $script:MemoryConfig.GlobalContextFile)
        }
        foreach ($dir in $memoryDirs) {
            if (-not (Test-Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
                Write-Log -Level INFO -Message "Created memory directory" -Result $dir -Category "Memory"
            }
        }
        # Initialize chat logging
        Initialize-ChatLogging -ProjectName $ProjectName -ProblemId $ProblemId
        # Load or create session context
        $script:SessionContext = Get-SessionContext
        # Update current session info
        $currentSession = @{
            SessionId = $global:SessionId ?? (New-Guid).ToString()
            ProjectName = $ProjectName
            WorkContext = $WorkContext
            StartTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ProblemId = $ProblemId
            LastActivity = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Status = "Active"
        }
        # Add to session history
        if (-not $script:SessionContext.Sessions) {
            $script:SessionContext.Sessions = @()
        }
        $script:SessionContext.Sessions += $currentSession
        $script:SessionContext.CurrentSession = $currentSession
        $script:SessionContext.LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        # Save context
        Save-SessionContext
        # Display memory summary
        Show-MemorySummary
        Write-Host "✅ Memory system initialized successfully!" -ForegroundColor Green
        Write-Log -Level INFO -Message "Memory system initialized" -Result "ProjectName: $ProjectName, Context: $WorkContext" -Category "Memory"
        return $currentSession.SessionId
    }
    catch {
        Write-Error "Failed to initialize memory system: $_"
        Write-Log -Level ERROR -Message "Memory system initialization failed" -Result $_.Exception.Message -Category "Memory"
        throw
    }
}
function Get-SessionContext {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Days = 7
    )
    try {
        if (Test-Path $script:MemoryConfig.CurrentContextFile) {
            $context = Get-Content $script:MemoryConfig.CurrentContextFile -Raw | ConvertFrom-Json -AsHashtable
            # Filter sessions by date range
            $cutoffDate = (Get-Date).AddDays(-$Days)
            if ($context.Sessions) {
                $context.Sessions = $context.Sessions | Where-Object {
                    [DateTime]::Parse($_.StartTime) -gt $cutoffDate
                }
            }
            return $context
        }
        else {
            # Create new context
            $newContext = @{
                Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                ProjectScope = $script:MemoryConfig.CurrentProject
                Sessions = @()
                CurrentSession = $null
                ProjectState = @{}
                ConversationTopics = @()
                ResolvedProblems = @()
                PendingTasks = @()
            }
            return $newContext
        }
    }
    catch {
        Write-Warning "Failed to load session context: $_"
        return @{
            Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ProjectScope = $script:MemoryConfig.CurrentProject
            Sessions = @()
            CurrentSession = $null
            ProjectState = @{}
            ConversationTopics = @()
            ResolvedProblems = @()
            PendingTasks = @()
        }
    }
}
function Save-SessionContext {
    [CmdletBinding()]
    param()
    try {
        if ($script:SessionContext) {
            $script:SessionContext.LastUpdated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $script:SessionContext.ProjectScope = $script:MemoryConfig.CurrentProject
            # Keep only recent sessions to prevent file bloat
            if ($script:SessionContext.Sessions.Count -gt $script:MemoryConfig.MaxSessions) {
                $script:SessionContext.Sessions = $script:SessionContext.Sessions |
                    Sort-Object StartTime -Descending |
                    Select-Object -First $script:MemoryConfig.MaxSessions
            }
            $contextJson = $script:SessionContext | ConvertTo-Json -Depth 10
            Set-Content -Path $script:MemoryConfig.CurrentContextFile -Value $contextJson -Encoding UTF8
            Write-Log -Level DEBUG -Message "Session context saved" -Result $script:MemoryConfig.CurrentContextFile -Category "Memory"
        }
    }
    catch {
        Write-Error "Failed to save session context: $_"
        Write-Log -Level ERROR -Message "Failed to save session context" -Result $_.Exception.Message -Category "Memory"
    }
}
function Resume-ConversationContext {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$SessionId,
        [Parameter()]
        [int]$LastSessions = 3
    )
    try {
        Write-Host "🔄 Resuming conversation context..." -ForegroundColor Yellow
        # Get recent chat files
        $chatFiles = Get-ChildItem -Path $script:MemoryConfig.CurrentChatDir -Filter "*.chat" |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First $LastSessions
        if ($chatFiles.Count -eq 0) {
            Write-Host "ℹ️  No previous conversation history found." -ForegroundColor Blue
            return
        }
        $contextSummary = @{
            RecentSessions = @()
            KeyTopics = @()
            ResolvedProblems = @()
            PendingIssues = @()
            ImportantDecisions = @()
        }
        foreach ($file in $chatFiles) {
            $content = Get-Content $file.FullName -Raw
            # Extract session metadata
            if ($content -match 'Session ID: (.+)') {
                $sessionId = $Matches[1].Trim()
            }
            if ($content -match 'Project: (.+)') {
                $project = $Matches[1].Trim()
            }
            if ($content -match 'Started: (.+)') {
                $started = $Matches[1].Trim()
            }
            # Extract summary points
            $summaryPoints = @()
            if ($content -match '===========================================\s*대화 요약[^=]*===========================================\s*(.+?)(?=\s*문제 해결 현황:|\s*$)') {
                $summarySection = $Matches[1]
                $summaryPoints = ($summarySection -split '\n' | Where-Object { $_ -match '^\s*-' }) -replace '^\s*-\s*', ''
            }
            # Extract resolved problems
            $resolvedProblems = @()
            if ($content -match '문제 해결 현황:\s*-------------------------------------------\s*(.+?)$') {
                $problemSection = $Matches[1]
                $problemBlocks = $problemSection -split '\[([^\]]+)\]' | Where-Object { $_ -and $_ -notmatch '^\s*$' }
                for ($i = 0; $i -lt $problemBlocks.Count; $i += 2) {
                    if ($i + 1 -lt $problemBlocks.Count) {
                        $problemId = $problemBlocks[$i]
                        $problemDetails = $problemBlocks[$i + 1]
                        if ($problemDetails -match '상태:\s*해결됨') {
                            $resolvedProblems += $problemId
                        }
                    }
                }
            }
            $sessionSummary = @{
                SessionId = $sessionId
                Project = $project
                Started = $started
                File = $file.Name
                SummaryPoints = $summaryPoints
                ResolvedProblems = $resolvedProblems
            }
            $contextSummary.RecentSessions += $sessionSummary
            $contextSummary.KeyTopics += $summaryPoints
            $contextSummary.ResolvedProblems += $resolvedProblems
        }
        # Display context summary
        Write-Host "`n📋 CONVERSATION CONTEXT SUMMARY" -ForegroundColor Cyan
        Write-Host "=" * 50 -ForegroundColor Cyan
        Write-Host "`n🕒 Recent Sessions:" -ForegroundColor Green
        foreach ($session in $contextSummary.RecentSessions) {
            Write-Host "  • [$($session.Project)] $($session.Started)" -ForegroundColor White
            if ($session.SummaryPoints) {
                foreach ($point in $session.SummaryPoints) {
                    Write-Host "    → $point" -ForegroundColor Gray
                }
            }
        }
        if ($contextSummary.ResolvedProblems) {
            Write-Host "`n✅ Recently Resolved:" -ForegroundColor Green
            $uniqueProblems = $contextSummary.ResolvedProblems | Sort-Object -Unique
            foreach ($problem in $uniqueProblems) {
                Write-Host "  • $problem" -ForegroundColor White
            }
        }
        # Update session context
        if ($script:SessionContext) {
            $script:SessionContext.ConversationTopics = $contextSummary.KeyTopics | Sort-Object -Unique
            $script:SessionContext.ResolvedProblems = $contextSummary.ResolvedProblems | Sort-Object -Unique
            Save-SessionContext
        }
        Write-Host "`n🎯 Context restored! Continue your conversation with full awareness of recent work." -ForegroundColor Green
        Write-Log -Level INFO -Message "Conversation context resumed" -Result "$($chatFiles.Count) sessions analyzed" -Category "Memory"
        return $contextSummary
    }
    catch {
        Write-Error "Failed to resume conversation context: $_"
        Write-Log -Level ERROR -Message "Failed to resume conversation context" -Result $_.Exception.Message -Category "Memory"
    }
}
function Add-MemoryPoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Topic,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter()]
        [ValidateSet('Decision', 'Problem', 'Solution', 'Task', 'Note')]
        [string]$Type = 'Note',
        [Parameter()]
        [string]$ProblemId = ""
    )
    try {
        $memoryPoint = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Topic = $Topic
            Description = $Description
            Type = $Type
            ProblemId = $ProblemId
            SessionId = $global:SessionId
        }
        # Add to appropriate category
        switch ($Type) {
            'Decision' {
                if (-not $script:SessionContext.ImportantDecisions) { $script:SessionContext.ImportantDecisions = @() }
                $script:SessionContext.ImportantDecisions += $memoryPoint
            }
            'Problem' {
                if (-not $script:SessionContext.PendingTasks) { $script:SessionContext.PendingTasks = @() }
                $script:SessionContext.PendingTasks += $memoryPoint
            }
            'Solution' {
                if (-not $script:SessionContext.ResolvedProblems) { $script:SessionContext.ResolvedProblems = @() }
                $script:SessionContext.ResolvedProblems += $memoryPoint
            }
            default {
                if (-not $script:SessionContext.ConversationTopics) { $script:SessionContext.ConversationTopics = @() }
                $script:SessionContext.ConversationTopics += $memoryPoint
            }
        }
        Save-SessionContext
        # Also add to chat log if available
        Add-ChatSummaryPoint -Point "$Type`: $Topic - $Description"
        Write-Host "💭 Memory point added: [$Type] $Topic" -ForegroundColor Magenta
        Write-Log -Level INFO -Message "Memory point added" -Result "${Type}: ${Topic}" -Category "Memory"
    }
    catch {
        Write-Error "Failed to add memory point: $_"
        Write-Log -Level ERROR -Message "Failed to add memory point" -Result $_.Exception.Message -Category "Memory"
    }
}
function Show-MemorySummary {
    [CmdletBinding()]
    param()
    try {
        Write-Host "`n🧠 DCEC MEMORY SYSTEM STATUS" -ForegroundColor Cyan
        Write-Host "=" * 40 -ForegroundColor Cyan
        $context = Get-SessionContext
        Write-Host "🎯 Current Scope: $($script:MemoryConfig.CurrentProject ?? 'Not Set')" -ForegroundColor Yellow
        Write-Host "📂 Chat Directory: $($script:MemoryConfig.CurrentChatDir)" -ForegroundColor Gray
        Write-Host "📊 Sessions: $($context.Sessions.Count ?? 0) recent" -ForegroundColor White
        Write-Host "💭 Topics: $($context.ConversationTopics.Count ?? 0) tracked" -ForegroundColor White
        Write-Host "✅ Resolved: $($context.ResolvedProblems.Count ?? 0) problems" -ForegroundColor Green
        Write-Host "⏳ Pending: $($context.PendingTasks.Count ?? 0) tasks" -ForegroundColor Yellow
        if ($context.CurrentSession) {
            Write-Host "`n🎯 Current Session:" -ForegroundColor Cyan
            Write-Host "  • Project: $($context.CurrentSession.ProjectName)" -ForegroundColor White
            Write-Host "  • Context: $($context.CurrentSession.WorkContext)" -ForegroundColor White
            Write-Host "  • Started: $($context.CurrentSession.StartTime)" -ForegroundColor White
        }
        # Show recent chat files in current scope
        $recentChats = Get-ChildItem -Path $script:MemoryConfig.CurrentChatDir -Filter "*.chat" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 5
        if ($recentChats) {
            Write-Host "`n💬 Recent Conversations ($($script:MemoryConfig.CurrentProject)):" -ForegroundColor Cyan
            foreach ($chat in $recentChats) {
                $age = [math]::Round(((Get-Date) - $chat.LastWriteTime).TotalHours, 1)
                Write-Host "  • $($chat.Name) ($age hours ago)" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
    catch {
        Write-Warning "Failed to show memory summary: $_"
    }
}
function Search-ConversationHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SearchTerm,
        [Parameter()]
        [int]$Days = 30,
        [Parameter()]
        [int]$MaxResults = 10,
        [Parameter()]
        [ValidateSet('Current', 'Global', 'All')]
        [string]$SearchScope = 'Current'
    )
    try {
        Write-Host "🔍 Searching conversation history for: '$SearchTerm'" -ForegroundColor Yellow
        Write-Host "   Scope: $SearchScope" -ForegroundColor Gray
        $searchDirs = @()
        switch ($SearchScope) {
            'Current' {
                $searchDirs = @($script:MemoryConfig.CurrentChatDir)
            }
            'Global' {
                $searchDirs = @($script:MemoryConfig.GlobalChatDir)
            }
            'All' {
                $searchDirs = @($script:MemoryConfig.GlobalChatDir) + $script:MemoryConfig.ProjectDirs.Values
            }
        }
        $results = @()
        $cutoffDate = (Get-Date).AddDays(-$Days)
        foreach ($dir in $searchDirs) {
            if (-not (Test-Path $dir)) { continue }
            $chatFiles = Get-ChildItem -Path $dir -Filter "*.chat" |
                Where-Object { $_.LastWriteTime -gt $cutoffDate } |
                Sort-Object LastWriteTime -Descending
            foreach ($file in $chatFiles) {
                $content = Get-Content $file.FullName -Raw
                if ($content -match $SearchTerm) {
                    # Extract context around the match
                    $lines = $content -split '\n'
                    $matchingLines = @()
                    for ($i = 0; $i -lt $lines.Count; $i++) {
                        if ($lines[$i] -match $SearchTerm) {
                            $start = [Math]::Max(0, $i - 2)
                            $end = [Math]::Min($lines.Count - 1, $i + 2)
                            $context = $lines[$start..$end] -join '\n'
                            $matchingLines += $context
                        }
                    }
                    if ($matchingLines) {
                        $results += @{
                            File = $file.Name
                            Directory = $dir
                            LastModified = $file.LastWriteTime
                            Matches = $matchingLines
                        }
                    }
                }
            }
        }
        # Display results
        if ($results.Count -eq 0) {
            Write-Host "❌ No matches found for '$SearchTerm'" -ForegroundColor Red
        }
        else {
            Write-Host "✅ Found $($results.Count) conversation(s) with matches:" -ForegroundColor Green
            $displayCount = [Math]::Min($results.Count, $MaxResults)
            for ($i = 0; $i -lt $displayCount; $i++) {
                $result = $results[$i]
                Write-Host "`n📄 $($result.File) ($($result.LastModified))" -ForegroundColor Cyan
                foreach ($match in $result.Matches) {
                    Write-Host "  $($match -replace $SearchTerm, "**$SearchTerm**")" -ForegroundColor White
                    Write-Host "  ---" -ForegroundColor Gray
                }
            }
            if ($results.Count -gt $MaxResults) {
                Write-Host "`n... and $($results.Count - $MaxResults) more results" -ForegroundColor Gray
            }
        }
        Write-Log -Level INFO -Message "Conversation search completed" -Result "$($results.Count) matches for '$SearchTerm'" -Category "Memory"
        return $results
    }
    catch {
        Write-Error "Failed to search conversation history: $_"
        Write-Log -Level ERROR -Message "Conversation search failed" -Result $_.Exception.Message -Category "Memory"
    }
}
function Export-MemorySnapshot {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ExportPath = "",
        [Parameter()]
        [int]$Days = 30
    )
    try {
        if (-not $ExportPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $baseDir = if ($script:MemoryConfig.CurrentProject -eq 'Global') {
                "d:\Dev\DCEC"
            } else {
                Split-Path $script:MemoryConfig.CurrentChatDir -Parent
            }
            $ExportPath = Join-Path $baseDir "exports\memory_snapshot_$timestamp.zip"
        }
        $exportDir = Split-Path $ExportPath
        if (-not (Test-Path $exportDir)) {
            New-Item -Path $exportDir -ItemType Directory -Force | Out-Null
        }
        $tempDir = Join-Path $env:TEMP "dcec_memory_export_$(Get-Date -Format 'HHmmss')"
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        try {
            # Copy session context
            if (Test-Path $script:MemoryConfig.CurrentContextFile) {
                Copy-Item $script:MemoryConfig.CurrentContextFile -Destination $tempDir
            }
            # Copy recent chat files
            $cutoffDate = (Get-Date).AddDays(-$Days)
            $recentChats = Get-ChildItem -Path $script:MemoryConfig.CurrentChatDir -Filter "*.chat" |
                Where-Object { $_.LastWriteTime -gt $cutoffDate }
            $chatExportDir = Join-Path $tempDir "chat_logs"
            New-Item -Path $chatExportDir -ItemType Directory -Force | Out-Null
            foreach ($chat in $recentChats) {
                Copy-Item $chat.FullName -Destination $chatExportDir
            }
            # Create export summary
            $summary = @{
                ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                DaysIncluded = $Days
                ChatFilesCount = $recentChats.Count
                SessionContext = $(if (Test-Path $script:MemoryConfig.CurrentContextFile) { "Included" } else { "Not Available" })
                ExportedBy = $env:USERNAME
            }
            $summary | ConvertTo-Json | Set-Content -Path (Join-Path $tempDir "export_info.json")
            # Create ZIP archive
            Compress-Archive -Path "$tempDir\*" -DestinationPath $ExportPath -Force
            Write-Host "📦 Memory snapshot exported to: $ExportPath" -ForegroundColor Green
            Write-Log -Level INFO -Message "Memory snapshot exported" -Result $ExportPath -Category "Memory"
            return $ExportPath
        }
        finally {
            # Clean up temp directory
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Recurse -Force
            }
        }
    }
    catch {
        Write-Error "Failed to export memory snapshot: $_"
        Write-Log -Level ERROR -Message "Memory snapshot export failed" -Result $_.Exception.Message -Category "Memory"
    }
}
function Switch-ProjectScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Global', 'Dev_Env', 'Infra_Architecture', 'Governance')]
        [string]$NewScope,
        [Parameter()]
        [string]$ProjectName = "DCEC_Project"
    )
    try {
        Write-Host "🔄 Switching to project scope: $NewScope" -ForegroundColor Yellow
        # Save current context before switching
        if ($script:SessionContext) {
            Save-SessionContext
        }
        # Update memory configuration
        $script:MemoryConfig.CurrentProject = $NewScope
        if ($NewScope -eq 'Global') {
            $script:MemoryConfig.CurrentChatDir = $script:MemoryConfig.GlobalChatDir
            $script:MemoryConfig.CurrentContextFile = $script:MemoryConfig.GlobalContextFile
        } else {
            $script:MemoryConfig.CurrentChatDir = $script:MemoryConfig.ProjectDirs[$NewScope]
            $script:MemoryConfig.CurrentContextFile = Join-Path $script:MemoryConfig.ProjectDirs[$NewScope] "context.json"
        }
        # Load new context
        $script:SessionContext = Get-SessionContext
        Write-Host "✅ Switched to $NewScope scope" -ForegroundColor Green
        Write-Host "   Chat Directory: $($script:MemoryConfig.CurrentChatDir)" -ForegroundColor Gray
        Write-Log -Level INFO -Message "Project scope switched" -Result "New scope: $NewScope" -Category "Memory"
        return $true
    }
    catch {
        Write-Error "Failed to switch project scope: $_"
        Write-Log -Level ERROR -Message "Failed to switch project scope" -Result $_.Exception.Message -Category "Memory"
        return $false
    }
}
# Export functions
Export-ModuleMember -Function @(
    'Initialize-MemorySystem',
    'Get-SessionContext',
    'Resume-ConversationContext',
    'Add-MemoryPoint',
    'Show-MemorySummary',
    'Search-ConversationHistory',
    'Export-MemorySnapshot',
    'Switch-ProjectScope'
)
# Initialize memory system on module load
Write-Host "🧠 DCEC Memory Management System loaded" -ForegroundColor Magenta
Write-Host "   Use Initialize-MemorySystem to start tracking conversations" -ForegroundColor Gray
