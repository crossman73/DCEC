# DCECCore.psm1
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$FunctionsPath = Join-Path $ScriptPath "Functions"
# Functions 폴더의 모든 .ps1 파일을 가져옵니다
$Functions = @( Get-ChildItem -Path $FunctionsPath\*.ps1 -ErrorAction SilentlyContinue )
# 각 함수 파일을 dot source로 로드합니다
foreach($Function in $Functions) {
    try {
        . $Function.FullName
    }
    catch {
        Write-Error -Message "Failed to import function $($Function.FullName): $_"
    }
}
# 공개할 함수들을 Export합니다
Export-ModuleMember -Function * -Alias *
