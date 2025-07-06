# Gemini 서비스 환경 변수 설정
function Initialize-GeminiEnvironment {
    param(
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env/Env",
        [string]$LogType
    )
    $geminiConfig = @{
        api = @{
            "GEMINI_API_KEY" = "__REPLACE_ME__"
            "GEMINI_PROJECT_ID" = "__REPLACE_ME__"
        }
        config = @{
            "GEMINI_HOME" = "/mnt/d/Dev/DCEC/GeminiService"
            "GEMINI_CONFIG_DIR" = "$BaseDir/Services/Gemini"
        }
    }
    Initialize-ServiceEnv -Service "Gemini" -BaseDir $BaseDir -Config $geminiConfig -LogType $LogType
}
Export-ModuleMember -Function Initialize-GeminiEnvironment
