# Claude 서비스 환경 변수 설정
function Initialize-ClaudeEnvironment {
    param(
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env/Env",
        [string]$LogType
    )
    $claudeConfig = @{
        api = @{
            "CLAUDE_API_KEY" = "__REPLACE_ME__"
            "CLAUDE_API_URL" = "https://api.anthropic.com/v1"
        }
        config = @{
            "CLAUDE_HOME" = "/mnt/d/Dev/DCEC/ClaudeCodeService"
            "CLAUDE_NPM_GLOBAL" = "$HOME/.npm-global"
            "CLAUDE_CONFIG_DIR" = "$BaseDir/Services/Claude"
        }
    }
    Initialize-ServiceEnv -Service "Claude" -BaseDir $BaseDir -Config $claudeConfig -LogType $LogType
}
Export-ModuleMember -Function Initialize-ClaudeEnvironment
