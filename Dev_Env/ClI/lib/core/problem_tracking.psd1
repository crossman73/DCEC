# 모듈 매니페스트 파일
@{
    ModuleVersion = '1.0.0'
    GUID = 'f8b0e1e0-5f1a-4c8e-9b0a-9c0b5c9b0b0b'
    Author = 'DCEC Team'
    Description = '문제 추적 및 관리 모듈'
    PowerShellVersion = '7.0'
    RequiredModules = @('logging')
    FunctionsToExport = @(
        'Initialize-ProblemTracking',
        'New-Problem',
        'Update-ProblemStatus',
        'Get-ProblemReport'
    )
    PrivateData = @{
        PSData = @{
            Tags = @('ProblemTracking', 'Logging', 'Management')
        }
    }
}
