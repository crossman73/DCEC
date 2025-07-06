# AI 서비스 프로젝트 초기화 스크립트
param (
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    [Parameter(Mandatory=$true)]
    [ValidateSet('claude', 'gpt', 'gemini', 'all')]
    [string]$AIModel,
    [Parameter(Mandatory=$false)]
    [bool]$EnableApiDocs = $true
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# 기본 환경 초기화
. "$PSScriptRoot\..\..\init_common.ps1"
Write-ColorLog "AI 서비스 프로젝트 초기화: $ProjectName" -Level INFO -Color Green
# Python 가상환경 설정
python -m venv .venv
if ($IsWindows) {
    .\.venv\Scripts\Activate.ps1
} else {
    . ./.venv/bin/activate
}
# 선택된 모델에 따라 의존성 설치
$requirements = @()
switch ($AIModel) {
    'claude' {
        $requirements += 'anthropic'
    }
    'gpt' {
        $requirements += 'openai'
    }
    'gemini' {
        $requirements += 'google-generativeai'
    }
    'all' {
        $requirements += @('anthropic', 'openai', 'google-generativeai')
    }
}
$requirements += @(
    'langchain',
    'fastapi',
    'uvicorn',
    'pydantic',
    'python-dotenv'
)
foreach ($req in $requirements) {
    pip install $req
}
# .env 파일 설정
$envContent = ""
if ($AIModel -in @('claude', 'all')) {
    $envContent += "ANTHROPIC_API_KEY=your-claude-api-key`n"
}
if ($AIModel -in @('gpt', 'all')) {
    $envContent += "OPENAI_API_KEY=your-openai-api-key`n"
}
if ($AIModel -in @('gemini', 'all')) {
    $envContent += "GOOGLE_API_KEY=your-google-api-key`n"
}
$envContent | Set-Content "config/.env"
if ($EnableApiDocs) {
    # API 문서 설정 추가
    Add-Content "src/main.py" @"
# API 문서 설정
app = FastAPI(
    title="$ProjectName AI Service",
    description="$ProjectName AI 서비스 API 문서",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)
"@
}
Write-ColorLog "프로젝트 초기화 완료" -Level INFO -Color Green
Write-ColorLog "시작하려면: uvicorn src.main:app --reload" -Level INFO -Color Green
