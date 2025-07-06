# API 서버 프로젝트 초기화 스크립트
param (
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    [Parameter(Mandatory=$true)]
    [ValidateSet('sqlite', 'postgresql')]
    [string]$DatabaseType,
    [Parameter(Mandatory=$false)]
    [bool]$EnableApiDocs = $true
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# 기본 환경 초기화
. "$PSScriptRoot\..\..\init_common.ps1"
Write-ColorLog "API 서버 프로젝트 초기화: $ProjectName" -Level INFO -Color Green
# Python 가상환경 설정
python -m venv .venv
if ($IsWindows) {
    .\.venv\Scripts\Activate.ps1
} else {
    . ./.venv/bin/activate
}
# 의존성 설치
pip install -r requirements.txt
# 데이터베이스 설정
$envContent = Get-Content "config/.env.example"
if ($DatabaseType -eq 'postgresql') {
    $envContent = $envContent -replace "sqlite:///./app.db", "postgresql://user:password@localhost:5432/$ProjectName"
}
$envContent | Set-Content "config/.env"
if ($EnableApiDocs) {
    # API 문서 설정 추가
    Add-Content "src/main.py" @"
# API 문서 설정
app = FastAPI(
    title="$ProjectName API",
    description="$ProjectName REST API 문서",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)
"@
}
Write-ColorLog "프로젝트 초기화 완료" -Level INFO -Color Green
Write-ColorLog "시작하려면: uvicorn src.main:app --reload" -Level INFO -Color Green
