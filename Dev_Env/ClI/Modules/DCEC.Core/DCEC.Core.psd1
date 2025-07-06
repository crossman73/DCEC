@{
    ModuleVersion = '1.0.0'
    GUID = 'b46944e3-5b1b-4e0b-8f9d-8f76f2c3e195'
    Author = 'DCEC Development Team'
    CompanyName = 'DCEC'
    Copyright = '(c) 2025 DCEC. All rights reserved.'
    Description = 'Core functionality for DCEC development environment'
    PowerShellVersion = '5.1'
    RootModule = 'DCEC.Core.psm1'
    FunctionsToExport = @(
        'Initialize-Logging',
        'Write-Log',
        'Initialize-ChatLogging',
        'Add-ChatMessage',
        'Add-ChatSummaryPoint',
        'Write-ChatSummary',
        'Initialize-WorkContext',
        'Initialize-DirectoryStructure',
        'Test-DirectoryStructure',
        'Get-DirectoryStatus'
    )
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('DCEC', 'Development', 'Environment')
            LicenseUri = 'https://dcec.com/license'
            ProjectUri = 'https://dcec.com'
            ReleaseNotes = 'Initial release'
        }
    }
}
