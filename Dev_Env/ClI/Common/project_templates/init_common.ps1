# 프로젝트 공통 초기화 스크립트
using module '.\Scripts\modules\core\logging.ps1'
using module '.\Scripts\modules\core\directory_setup.ps1'
function Initialize-ProjectEnvironment {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ProjectName,
        [Parameter(Mandatory=$true)]
        [string]$ProjectType,
        [string]$Description = ""
    )
    try {
        # 로깅 초기화
        Initialize-Logging -Type $ProjectType
        # 세션 ID 생성
        $sessionId = [guid]::NewGuid().ToString()
        Initialize-ChatLogging -SessionId $sessionId
        Write-ColorLog "프로젝트 환경 초기화 시작: $ProjectName" -Level INFO -Color Green
        # 작업 컨텍스트 초기화
        Initialize-WorkContext -BasePath $PWD -Description $Description
        # 기본 디렉토리 구조 생성
        Initialize-DirectoryStructure -BasePath $PWD -Force
        # Git 저장소 초기화
        if (!(Test-Path ".git")) {
            git init
            # .gitignore 생성
            @"
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
# Virtual Environment
.env
.venv
venv/
ENV/
# IDE
.idea/
.vscode/
*.swp
*.swo
# Logs
logs/
*.log
# Local development
*.db
*.sqlite3
"@ | Out-File -FilePath ".gitignore" -Encoding UTF8
            git add .
            git commit -m "Initial commit: Project structure"
        }
        Write-ColorLog "프로젝트 환경 초기화 완료" -Level INFO -Color Green
        return $true
    }
    catch {
        Write-ColorLog "프로젝트 환경 초기화 실패: $($_.Exception.Message)" -Level ERROR -Color Red
        return $false
    }
}
