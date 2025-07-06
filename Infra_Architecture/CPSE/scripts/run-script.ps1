# CPSE 통합 스크립트 실행 도우미
# 모든 PowerShell 스크립트를 편리하게 실행할 수 있는 통합 인터페이스

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('setup', 'security', 'maintenance', 'all', 'help')]
    [string]$Category,
    
    [Parameter()]
    [ValidateSet('path-sync', 'env-manager', 'secrets-manager', 'network-diagnostics', 'permissions')]
    [string]$Script,
    
    [Parameter()]
    [string]$Action,
    
    [Parameter()]
    [hashtable]$Parameters = @{},
    
    [switch]$DryRun,
    [switch]$Verbose
)

# 색상 출력 함수
function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    $colors = @{
        "Red" = "Red"; "Green" = "Green"; "Yellow" = "Yellow"
        "Blue" = "Blue"; "Magenta" = "Magenta"; "Cyan" = "Cyan"
    }
    Write-Host $Text -ForegroundColor $colors[$Color]
}

function Write-Info { Write-ColorText "[INFO] $args" "Green" }
function Write-Warn { Write-ColorText "[WARN] $args" "Yellow" }
function Write-Error { Write-ColorText "[ERROR] $args" "Red" }
function Write-Step { Write-ColorText "[STEP] $args" "Blue" }
function Write-Success { Write-ColorText "[SUCCESS] $args" "Magenta" }

# 스크립트 경로 매핑
$scriptMap = @{
    'setup' = @{
        'path-sync' = @{
            'path' = 'scripts/setup/path-sync.ps1'
            'description' = 'Windows/NAS 간 경로 동기화'
            'actions' = @('detect', 'set', 'sync', 'view', 'status')
        }
        'env-manager' = @{
            'path' = 'scripts/setup/env-manager.ps1'
            'description' = '환경 정보 관리'
            'actions' = @('view', 'update', 'export', 'validate')
        }
        'permissions' = @{
            'path' = 'scripts/setup-permissions.ps1'
            'description' = 'PowerShell 실행 권한 설정'
            'actions' = @('check', 'set')
        }
    }
    'security' = @{
        'secrets-manager' = @{
            'path' = 'scripts/security/secrets-manager.ps1'
            'description' = '보안 정보 관리'
            'actions' = @('add', 'update', 'delete', 'view', 'generate', 'backup')
        }
    }
    'maintenance' = @{
        'network-diagnostics' = @{
            'path' = 'scripts/maintenance/network-diagnostics.ps1'
            'description' = '네트워크 진단'
            'actions' = @('check', 'monitor', 'report', 'fix')
        }
    }
}

# 도움말 표시
function Show-Help {
    Write-Info "CPSE 통합 스크립트 실행 도우미"
    Write-Info "=================================="
    Write-Info ""
    Write-Info "사용법:"
    Write-Info "  .\run-script.ps1 -Category <category> [-Script <script>] [-Action <action>] [-Parameters <hashtable>]"
    Write-Info ""
    Write-Info "카테고리:"
    Write-Info "  setup       - 초기 설정 및 환경 구성"
    Write-Info "  security    - 보안 관련 스크립트"
    Write-Info "  maintenance - 유지보수 및 모니터링"
    Write-Info "  all         - 모든 스크립트 목록"
    Write-Info "  help        - 도움말 표시"
    Write-Info ""
    Write-Info "예시:"
    Write-Info "  .\run-script.ps1 -Category setup -Script path-sync -Action detect"
    Write-Info "  .\run-script.ps1 -Category security -Script secrets-manager -Action view"
    Write-Info "  .\run-script.ps1 -Category maintenance -Script network-diagnostics -Action check"
    Write-Info ""
}

# 카테고리별 스크립트 목록 표시
function Show-CategoryScripts {
    param([string]$CategoryName)
    
    if (-not $scriptMap.ContainsKey($CategoryName)) {
        Write-Error "알 수 없는 카테고리: $CategoryName"
        return
    }
    
    Write-Info "$CategoryName 카테고리 스크립트:"
    Write-Info "=" * 50
    
    foreach ($scriptName in $scriptMap[$CategoryName].Keys) {
        $scriptInfo = $scriptMap[$CategoryName][$scriptName]
        Write-Info "🔸 $scriptName"
        Write-Info "   설명: $($scriptInfo.description)"
        Write-Info "   경로: $($scriptInfo.path)"
        Write-Info "   지원 액션: $($scriptInfo.actions -join ', ')"
        Write-Info ""
    }
}

# 스크립트 실행
function Invoke-Script {
    param(
        [string]$CategoryName,
        [string]$ScriptName,
        [string]$ActionName,
        [hashtable]$ScriptParameters
    )
    
    if (-not $scriptMap.ContainsKey($CategoryName)) {
        Write-Error "알 수 없는 카테고리: $CategoryName"
        return
    }
    
    if (-not $scriptMap[$CategoryName].ContainsKey($ScriptName)) {
        Write-Error "알 수 없는 스크립트: $ScriptName"
        return
    }
    
    $scriptInfo = $scriptMap[$CategoryName][$ScriptName]
    $scriptPath = $scriptInfo.path
    
    if (-not (Test-Path $scriptPath)) {
        Write-Error "스크립트 파일이 존재하지 않습니다: $scriptPath"
        return
    }
    
    Write-Step "스크립트 실행 중: $ScriptName"
    Write-Info "경로: $scriptPath"
    Write-Info "액션: $ActionName"
    
    if ($DryRun) {
        Write-Warn "DryRun 모드: 실제 실행하지 않음"
        Write-Info "실행 예정 명령:"
        Write-Info "& `"$scriptPath`" -action $ActionName"
        return
    }
    
    try {
        # 기본 매개변수 설정
        $params = @{}
        if ($ActionName) {
            $params['action'] = $ActionName
        }
        
        # 추가 매개변수 병합
        foreach ($key in $ScriptParameters.Keys) {
            $params[$key] = $ScriptParameters[$key]
        }
        
        # 스크립트 실행
        & $scriptPath @params
        
        Write-Success "스크립트 실행 완료: $ScriptName"
        
    } catch {
        Write-Error "스크립트 실행 중 오류 발생: $($_.Exception.Message)"
    }
}

# 메인 로직
switch ($Category) {
    'help' {
        Show-Help
    }
    'all' {
        Write-Info "모든 스크립트 목록:"
        Write-Info "=" * 50
        
        foreach ($categoryName in $scriptMap.Keys) {
            Show-CategoryScripts $categoryName
        }
    }
    default {
        if (-not $Script) {
            Show-CategoryScripts $Category
        } else {
            if (-not $Action) {
                Write-Error "액션을 지정해야 합니다."
                Write-Info "사용 가능한 액션: $($scriptMap[$Category][$Script].actions -join ', ')"
                exit 1
            }
            
            Invoke-Script -CategoryName $Category -ScriptName $Script -ActionName $Action -ScriptParameters $Parameters
        }
    }
}
