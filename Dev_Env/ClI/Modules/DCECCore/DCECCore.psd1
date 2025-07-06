@{
    RootModule = 'DCECCore.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'f8b0e1a0-5b0a-4c1a-8c1a-0c1a8c1a0c1a'
    Author = 'DCEC Team'
    Description = 'DCEC Core functionality for development environment management'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Initialize-ProblemTracking',
        'New-Problem',
        'Update-Problem',
        'Get-ProblemReport',
        'Initialize-Logging',
        'Write-DCECLog',
        'Initialize-Directory',
        'Install-DCECEnvironment'
    )
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('DCEC', 'Development', 'Environment')
            ProjectUri = ''
        }
    }
}
