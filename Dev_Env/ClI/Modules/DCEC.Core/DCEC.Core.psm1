# DCEC Core Module
# 로깅 및 디렉토리 관리 기능
# Enum 정의
enum LogLevel {
    INFO = 0
    WARNING = 1
    ERROR = 2
    DEBUG = 3
}
# 전역 변수
$script:LogColors = @{
    INFO = 'White'
    WARNING = 'Yellow'
    ERROR = 'Red'
    DEBUG = 'Cyan'
}
$script:LogType = ""
$script:LogFile = ""
$script:MinLogLevel = [LogLevel]::INFO
$script:SessionId = ""
$script:LogCounter = 0
$script:ChatLogDir = ""
$script:CurrentChatFile = ""
$script:ChatSummaryPoints = @()
$script:DirectoryHistory = @()
$script:EnvironmentInfo = $null
$script:WorkContext = $null
$script:ServiceDirectories = @(
    'ClaudeCodeService',
    'UtilsService',
    'GeminiService',
    'BackupService'
)
$script:CommonDirectories = @(
    'lib',
    'bin',
    'docs',
    'config'
)
# 여기에 logging.ps1과 directory_setup.ps1의 모든 함수 내용을 복사
# (이전에 작성한 모든 함수들을 여기에 포함)
