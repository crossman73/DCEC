# CPSE 프로젝트 - NAS/로컬 경로 자동 감지 및 동기화 스크립트 (PowerShell)
# Version: 2.0.0
# Description: Windows 환경에서 NAS와 로컬 간 프로젝트 파일 동기화 관리

param(
  [Parameter(Mandatory=$true)][ValidateSet('detect','set','sync','view','status')]$action,
  [string]$root,
  [switch]$dryRun,
  [switch]$verbose
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

# 설정 파일 경로
$configPath = "../../config/path-config.json"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (!(Test-Path $configPath)) {
    Write-Error "path-config.json 파일이 존재하지 않습니다: $configPath"
    exit 1
}

try {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "설정 파일 파싱 오류: $_"
    exit 1
}

switch ($action) {
    'detect' {
        Write-Step "NAS 경로 자동 감지 시작"
        
        # 여러 네트워크 드라이브 확인
        $nasFound = $false
        foreach ($drive in @("Z:", "Y:", "X:", "W:")) {
            if (Test-Path "$drive\") {
                $testPath = "$drive\CPSE"
                if (Test-Path $testPath) {
                    $config.current_root = $testPath
                    Write-Info "NAS 경로 감지: $testPath"
                    $nasFound = $true
                    break
                }
            }
        }
        
        if (!$nasFound) {
            $config.current_root = $config.local_root
            Write-Warn "NAS 경로를 찾을 수 없어 로컬 경로를 사용: $($config.local_root)"
        }
        
        $config | ConvertTo-Json -Depth 4 | Set-Content $configPath
    }
    
    'set' {
        if ($root) {
            if (Test-Path $root) {
                $config.current_root = $root
                $config | ConvertTo-Json -Depth 4 | Set-Content $configPath
                Write-Info "현재 경로가 $root(으)로 설정됨"
            } else {
                Write-Error "지정된 경로가 존재하지 않습니다: $root"
                exit 1
            }
        } else {
            Write-Error "root 경로를 입력하세요"
            exit 1
        }
    }
    
    'sync' {
        $src = $config.current_root
        $dst = if ($src -eq $config.local_root) { 
            # 로컬에서 NAS로
            $config.nas_root -replace "/volume1", "Z:"
        } else { 
            # NAS에서 로컬로
            $config.local_root 
        }
        
        Write-Step "동기화 시작: $src → $dst"
        
        if ($dryRun) {
            Write-Info "DRY RUN 모드 - 실제 복사는 수행되지 않습니다"
            $robocopyArgs = @($src, $dst, "/MIR", "/L", "/NP", "/R:3", "/W:5")
        } else {
            $robocopyArgs = @($src, $dst, "/MIR", "/NP", "/R:3", "/W:5")
        }
        
        # 제외 패턴 추가
        foreach ($pattern in $config.sync_options.exclude_patterns) {
            $robocopyArgs += "/XD"
            $robocopyArgs += $pattern
        }
        
        if ($verbose) {
            $robocopyArgs += "/V"
        }
        
        try {
            & robocopy @robocopyArgs
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -le 3) {
                $config.last_synced = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                $config | ConvertTo-Json -Depth 4 | Set-Content $configPath
                Write-Info "동기화 완료"
            } else {
                Write-Error "동기화 중 오류 발생 (Exit Code: $exitCode)"
            }
        } catch {
            Write-Error "동기화 실행 오류: $_"
        }
    }
    
    'status' {
        Write-Step "동기화 상태 확인"
        Write-Info "현재 경로: $($config.current_root)"
        Write-Info "마지막 동기화: $($config.last_synced)"
        
        if ($config.current_root -and (Test-Path $config.current_root)) {
            $size = (Get-ChildItem $config.current_root -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $sizeGB = [math]::Round($size / 1GB, 2)
            Write-Info "프로젝트 크기: $sizeGB GB"
        }
    }
    
    'view' {
        $config | ConvertTo-Json -Depth 4 | Write-Host
    }
}