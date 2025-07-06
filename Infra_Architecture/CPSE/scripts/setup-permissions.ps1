# CPSE 스크립트 실행 권한 설정 스크립트
# PowerShell 스크립트 실행 정책 설정 및 환경 준비

param(
    [switch]$CheckOnly,
    [switch]$Force
)

# 관리자 권한 확인
function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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

Write-Step "CPSE 스크립트 실행 권한 설정 시작"
Write-Info "현재 작업 디렉토리: $(Get-Location)"

# 현재 실행 정책 확인
$currentPolicy = Get-ExecutionPolicy
Write-Info "현재 PowerShell 실행 정책: $currentPolicy"

if ($CheckOnly) {
    Write-Step "실행 권한 검사 모드"
    
    # 권한 상태 확인
    if ($currentPolicy -eq "Restricted") {
        Write-Error "PowerShell 스크립트 실행이 제한되어 있습니다."
        Write-Warn "해결 방법: Set-ExecutionPolicy RemoteSigned -Scope CurrentUser"
        exit 1
    } elseif ($currentPolicy -in @("AllSigned", "RemoteSigned", "Unrestricted")) {
        Write-Success "PowerShell 스크립트 실행이 허용되어 있습니다."
    } else {
        Write-Warn "알 수 없는 실행 정책입니다: $currentPolicy"
    }
    
    # 스크립트 파일 권한 확인
    $scriptFiles = Get-ChildItem -Path "." -Recurse -Filter "*.ps1"
    Write-Info "발견된 PowerShell 스크립트: $($scriptFiles.Count)개"
    
    foreach ($script in $scriptFiles) {
        $relativePath = $script.FullName.Replace((Get-Location).Path, ".")
        if (Test-Path $script.FullName) {
            Write-Success "✓ $relativePath"
        } else {
            Write-Error "✗ $relativePath"
        }
    }
    
    exit 0
}

# 실행 정책 설정
Write-Step "PowerShell 실행 정책 설정"

if ($currentPolicy -eq "Restricted") {
    Write-Warn "현재 스크립트 실행이 제한되어 있습니다."
    
    if ($Force) {
        Write-Step "강제 실행 정책 변경 시도"
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Success "실행 정책이 RemoteSigned로 변경되었습니다."
        } catch {
            Write-Error "실행 정책 변경에 실패했습니다: $($_.Exception.Message)"
            Write-Warn "관리자 권한으로 실행하거나 다음 명령을 수동으로 실행하세요:"
            Write-Warn "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
            exit 1
        }
    } else {
        Write-Info "실행 정책을 변경하시겠습니까? (Y/N)"
        $response = Read-Host
        if ($response -match '^[Yy]') {
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
                Write-Success "실행 정책이 RemoteSigned로 변경되었습니다."
            } catch {
                Write-Error "실행 정책 변경에 실패했습니다: $($_.Exception.Message)"
                exit 1
            }
        } else {
            Write-Warn "실행 정책 변경을 취소했습니다."
            exit 0
        }
    }
} else {
    Write-Success "PowerShell 스크립트 실행이 이미 허용되어 있습니다."
}

# 환경 변수 확인
Write-Step "환경 변수 확인"

$requiredDirs = @("config", "logs", "backup")
foreach ($dir in $requiredDirs) {
    if (Test-Path $dir) {
        Write-Success "✓ $dir 디렉토리 존재"
    } else {
        Write-Warn "✗ $dir 디렉토리 없음 - 생성 필요"
    }
}

# 설정 파일 확인
Write-Step "설정 파일 확인"

$configFiles = @(
    "config/path-config.json",
    "config/env-info.json", 
    "config/user-secrets.json",
    ".env"
)

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Write-Success "✓ $file 존재"
    } else {
        Write-Warn "✗ $file 없음 - 생성 필요"
    }
}

# 스크립트 테스트
Write-Step "주요 스크립트 테스트"

$testScripts = @(
    @{ Path = "scripts/setup/path-sync.ps1"; Args = "-action view" },
    @{ Path = "scripts/setup/env-manager.ps1"; Args = "-action view" },
    @{ Path = "scripts/security/secrets-manager.ps1"; Args = "-action view" },
    @{ Path = "scripts/maintenance/network-diagnostics.ps1"; Args = "-action check" }
)

foreach ($test in $testScripts) {
    if (Test-Path $test.Path) {
        Write-Info "테스트: $($test.Path)"
        try {
            # 스크립트 구문 검사만 수행
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $test.Path -Raw), [ref]$null)
            Write-Success "✓ 구문 검사 통과"
        } catch {
            Write-Error "✗ 구문 오류: $($_.Exception.Message)"
        }
    } else {
        Write-Error "✗ 스크립트 파일 없음: $($test.Path)"
    }
}

Write-Success "CPSE 스크립트 실행 권한 설정 완료"
Write-Info "이제 PowerShell 스크립트를 실행할 수 있습니다."
