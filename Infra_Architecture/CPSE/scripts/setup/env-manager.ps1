# CPSE 프로젝트 - 환경 정보 관리 스크립트 (PowerShell)
# Version: 2.0.0
# Description: NAS 환경 정보 수집, 갱신, 조회 관리

param(
  [Parameter(Mandatory=$true)][ValidateSet('view','update','export','validate')]$action,
  [string]$key,
  [string]$value,
  [string]$service
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

$envPath = "../../config/env-info.json"

if (!(Test-Path $envPath)) {
    Write-Error "env-info.json 파일이 존재하지 않습니다: $envPath"
    exit 1
}

try {
    $envInfo = Get-Content $envPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "설정 파일 파싱 오류: $_"
    exit 1
}

switch ($action) {
    'view' {
        if ($service) {
            if ($envInfo.services.$service) {
                Write-Step "서비스 정보: $service"
                $envInfo.services.$service | ConvertTo-Json -Depth 3 | Write-Host
            } else {
                Write-Error "서비스를 찾을 수 없습니다: $service"
            }
        } else {
            $envInfo | ConvertTo-Json -Depth 4 | Write-Host
        }
    }
    
    'update' {
        if ($service -and $key -and $value) {
            if ($envInfo.services.$service) {
                $envInfo.services.$service.$key = $value
                $envInfo.last_updated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                
                try {
                    $envInfo | ConvertTo-Json -Depth 4 | Set-Content $envPath
                    Write-Info "[$service] $key 값이 $value(으)로 갱신되었습니다"
                } catch {
                    Write-Error "파일 저장 오류: $_"
                }
            } else {
                Write-Error "서비스를 찾을 수 없습니다: $service"
            }
        } elseif ($key -and $value) {
            # NAS 정보 업데이트
            $envInfo.nas.$key = $value
            $envInfo.last_updated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            
            try {
                $envInfo | ConvertTo-Json -Depth 4 | Set-Content $envPath
                Write-Info "[NAS] $key 값이 $value(으)로 갱신되었습니다"
            } catch {
                Write-Error "파일 저장 오류: $_"
            }
        } else {
            Write-Error "서비스, 키, 값을 모두 입력하세요"
            Write-Info "사용법: -action update -service <서비스명> -key <키> -value <값>"
            Write-Info "또는: -action update -key <키> -value <값> (NAS 정보 업데이트)"
        }
    }
    
    'export' {
        $exportPath = "../../logs/env-export-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        try {
            $envInfo | ConvertTo-Json -Depth 4 | Set-Content $exportPath
            Write-Info "환경 정보를 내보냈습니다: $exportPath"
        } catch {
            Write-Error "내보내기 오류: $_"
        }
    }
    
    'validate' {
        Write-Step "환경 정보 유효성 검사"
        $errors = @()
        
        # 필수 NAS 정보 확인
        if (!$envInfo.nas.hostname) { $errors += "NAS hostname이 설정되지 않음" }
        if (!$envInfo.nas.internal_ip) { $errors += "NAS 내부 IP가 설정되지 않음" }
        
        # 서비스 포트 중복 확인
        $ports = @()
        foreach ($svc in $envInfo.services.PSObject.Properties) {
            if ($svc.Value.port) {
                if ($ports -contains $svc.Value.port) {
                    $errors += "포트 중복: $($svc.Value.port) ($($svc.Name))"
                } else {
                    $ports += $svc.Value.port
                }
            }
        }
        
        if ($errors.Count -eq 0) {
            Write-Info "환경 정보 유효성 검사 통과"
        } else {
            Write-Error "발견된 문제점:"
            foreach ($errorMsg in $errors) {
                Write-Error "  - $errorMsg"
            }
        }
    }
}