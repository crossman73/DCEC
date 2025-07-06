# PSScriptAnalyzer Settings
@{
    # Severity configuration
    Severity = @('Error', 'Warning')
    
    # Rules to exclude (문제 탭 혼란 방지)
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',           # Write-Host 사용 허용 (로깅용)
        'PSUseShouldProcessForStateChangingFunctions', # ShouldProcess 의무화 제외
        'PSProvideCommentHelp',            # Comment-based help 의무화 제외 (단계적 적용)
        'PSAvoidTrailingWhitespace',       # 후행 공백 경고 제외 (자동 정리됨)
        'PSUseBOMForUnicodeEncodedFile'    # BOM 경고 제외 (자동 적용됨)
    )

    # Rule configurations
    Rules = @{
        PSUseConsistentIndentation = @{
            Enable = $true
            Kind = 'space'
            IndentationSize = 4
        }
        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckSeparator = $true
        }
        PSAlignAssignmentStatement = @{
            Enable = $true
            CheckHashtable = $true
        }
        PSProvideCommentHelp = @{
            Enable = $true
            Placement = 'begin'
            ExportedOnly = $false
        }
    }

    # Custom rule configuration
    CustomRulePath = @()
    RecurseCustomRulePath = $false
}
