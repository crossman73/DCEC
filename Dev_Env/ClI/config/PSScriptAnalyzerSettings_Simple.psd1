# PSScriptAnalyzer Settings - 문제 탭 혼란 최소화
@{
    # 심각도 설정 (Error만 표시)
    Severity = @('Error')
    
    # 제외할 규칙 (경고성 규칙들 제외)
    ExcludeRules = @(
        'PSAvoidUsingWriteHost',           # Write-Host 사용 허용
        'PSUseShouldProcessForStateChangingFunctions', # ShouldProcess 의무화 제외
        'PSProvideCommentHelp',            # Comment-based help 의무화 제외
        'PSAvoidTrailingWhitespace',       # 후행 공백 경고 제외
        'PSUseBOMForUnicodeEncodedFile',   # BOM 경고 제외
        'PSUseOutputTypeCorrectly',        # 출력 타입 경고 제외
        'PSReviewUnusedParameter'          # 미사용 매개변수 경고 제외
    )
    
    # 기본 규칙 설정
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
    }
}
