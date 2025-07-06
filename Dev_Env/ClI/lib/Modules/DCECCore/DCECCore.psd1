# 모듈 매니페스트
@{
    RootModule = 'DCECCore.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a5c9e0d0-5f1a-4c8e-9b0a-9c0b5c9b0b0b'
    Author = 'DCEC Team'
    Description = 'DCEC Core Module for Development Environment Management'
    PowerShellVersion = '7.0'
    
    # 외부 모듈 의존성
    RequiredModules = @()
    
    # 내보낼 함수들
    FunctionsToExport = @(
        # 로깅 관련
        'Initialize-Logging',
        'Write-Log',
        'Initialize-ChatLogging',
        'Write-ChatMessage',
        'Write-ChatSummary',
        
        # 디렉토리 관련
        'Initialize-WorkContext',
        'Add-DirectoryChange',
        'Test-DirectoryStructure',
        'New-ServiceDirectory',
        'Initialize-DirectoryStructure',
        'Get-DirectoryStatus',
        
        # 문제 추적 관련
        'Initialize-ProblemTracking',
        'New-Problem',
        'Update-ProblemStatus',
        'Get-ProblemReport',
        
        # 환경 관리 관련
        'Initialize-Environment',
        'Get-EnvironmentStatus',
        'Update-EnvironmentConfig'
    )
    
    # 내보낼 변수들
    VariablesToExport = @()
    
    # 내보낼 별칭들
    AliasesToExport = @()
    
    # 프라이빗 데이터
    PrivateData = @{
        PSData = @{
            Tags = @('Development', 'Environment', 'Management', 'Logging', 'Directory', 'Problem Tracking')
            ProjectUri = 'https://github.com/yourusername/DCEC'
        }
    }
}
