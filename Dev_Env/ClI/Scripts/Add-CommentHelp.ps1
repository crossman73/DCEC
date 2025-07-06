# PowerShell Comment-based Help 자동 추가 스크립트
# 이 스크립트는 함수에 기본적인 Comment-based help를 추가합니다.

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

function Add-CommentBasedHelp {
    param(
        [string]$FunctionName,
        [string]$Content
    )
    
    # 기본 Comment-based help 템플릿
    $helpTemplate = @"
    <#
    .SYNOPSIS
    $FunctionName 함수의 기능을 설명합니다.
    
    .DESCRIPTION
    이 함수는 DCEC 프로젝트의 표준 기능을 제공합니다.
    
    .EXAMPLE
    $FunctionName
    
    .NOTES
    이 함수는 DCEC 네임스페이스를 사용합니다.
    #>
"@
    
    # function 선언 다음에 help 삽입
    $pattern = "(function\s+$FunctionName\s*\{?\s*\r?\n)(\s*param\s*\()"
    $replacement = "`$1$helpTemplate`r`n`$2"
    
    $Content -replace $pattern, $replacement
}

# 메인 실행 부분
if (Test-Path $FilePath) {
    $content = Get-Content $FilePath -Raw
    
    # function 선언을 찾는 정규식
    $functionPattern = 'function\s+([A-Za-z][A-Za-z0-9-_]*)\s*\{'
    $functions = [regex]::Matches($content, $functionPattern)
    
    $modifiedContent = $content
    
    foreach ($match in $functions) {
        $functionName = $match.Groups[1].Value
        Write-Host "Comment-based help 추가: $functionName"
        
        # 이미 Comment-based help가 있는지 확인
        $beforeFunction = $content.Substring(0, $match.Index)
        $hasHelp = $beforeFunction -match '<#[\s\S]*?\.SYNOPSIS[\s\S]*?#>'
        
        if (-not $hasHelp) {
            $helpTemplate = @"
    <#
    .SYNOPSIS
    $functionName 함수의 기능을 제공합니다.
    
    .DESCRIPTION
    이 함수는 DCEC 프로젝트의 표준 기능을 제공합니다.
    
    .EXAMPLE
    $functionName
    
    .NOTES
    이 함수는 DCEC 네임스페이스를 사용합니다.
    #>
"@
            
            # function 선언 뒤에 help 삽입
            $functionDeclaration = $match.Value
            $replacement = "$functionDeclaration`r`n$helpTemplate"
            $modifiedContent = $modifiedContent -replace [regex]::Escape($functionDeclaration), $replacement
        }
    }
    
    # 수정된 내용을 파일에 저장
    Set-Content -Path $FilePath -Value $modifiedContent -Encoding UTF8BOM
    Write-Host "Comment-based help 추가 완료: $FilePath"
}
else {
    Write-Error "파일을 찾을 수 없습니다: $FilePath"
}
