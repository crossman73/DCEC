# CPSE 프로젝트 - 사용자 보안 정보 관리 스크립트 (PowerShell)
# Version: 2.0.0
# Description: 서비스별 보안 정보(API 키, 패스워드 등) 안전 관리

param(
  [Parameter(Mandatory=$true)][ValidateSet('add','update','delete','view','generate','backup')]$action,
  [string]$service,
  [string]$key,
  [string]$value,
  [switch]$encrypt,
  [switch]$force
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

# 임의 문자열 생성 함수
function Generate-RandomString {
    param([int]$Length = 32)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $random = ""
    1..$Length | ForEach { $random += $chars[(Get-Random -Maximum $chars.Length)] }
    return $random
}

# 보안 정보 암호화 (기본적인 예시, 실제로는 더 강력한 암호화 필요)
function Encrypt-Value {
    param([string]$Value, [string]$Key)
    # 실제 환경에서는 더 강력한 암호화 구현 필요
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value))
}

function Decrypt-Value {
    param([string]$EncryptedValue, [string]$Key)
    try {
        return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($EncryptedValue))
    } catch {
        return $EncryptedValue  # 암호화되지 않은 경우
    }
}

$secretsPath = "../../config/user-secrets.json"

if (!(Test-Path $secretsPath)) {
    Write-Error "user-secrets.json 파일이 존재하지 않습니다: $secretsPath"
    exit 1
}

try {
    $secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "설정 파일 파싱 오류: $_"
    exit 1
}

switch ($action) {
    'add' {
        if ($service -and $key -and $value) {
            if (!$secrets.services.$service) {
                $secrets.services | Add-Member -MemberType NoteProperty -Name $service -Value @{}
                Write-Info "새 서비스 추가: $service"
            }
            
            if ($secrets.services.$service.$key -and !$force) {
                Write-Warn "키가 이미 존재합니다. 덮어쓰려면 -force 옵션을 사용하세요"
                exit 1
            }
            
            $finalValue = if ($encrypt) { Encrypt-Value $value $secrets.encryption_key } else { $value }
            $secrets.services.$service | Add-Member -MemberType NoteProperty -Name $key -Value $finalValue -Force
            
            try {
                $secrets | ConvertTo-Json -Depth 4 | Set-Content $secretsPath
                Write-Info "[$service] $key 추가/수정 완료"
            } catch {
                Write-Error "파일 저장 오류: $_"
            }
        } else {
            Write-Error "서비스, 키, 값을 모두 입력하세요"
        }
    }
    
    'update' {
        if ($service -and $key -and $value) {
            if ($secrets.services.$service -and $secrets.services.$service.$key) {
                $finalValue = if ($encrypt) { Encrypt-Value $value $secrets.encryption_key } else { $value }
                $secrets.services.$service.$key = $finalValue
                
                try {
                    $secrets | ConvertTo-Json -Depth 4 | Set-Content $secretsPath
                    Write-Info "[$service] $key 수정 완료"
                } catch {
                    Write-Error "파일 저장 오류: $_"
                }
            } else {
                Write-Error "지정된 서비스 또는 키를 찾을 수 없습니다"
            }
        } else {
            Write-Error "서비스, 키, 값을 모두 입력하세요"
        }
    }
    
    'delete' {
        if ($service -and $key) {
            if ($secrets.services.$service -and $secrets.services.$service.$key) {
                $secrets.services.$service.PSObject.Properties.Remove($key)
                
                try {
                    $secrets | ConvertTo-Json -Depth 4 | Set-Content $secretsPath
                    Write-Info "[$service] $key 삭제 완료"
                } catch {
                    Write-Error "파일 저장 오류: $_"
                }
            } else {
                Write-Error "지정된 서비스 또는 키를 찾을 수 없습니다"
            }
        } else {
            Write-Error "서비스와 키를 모두 입력하세요"
        }
    }
    
    'view' {
        if ($service) {
            if ($secrets.services.$service) {
                Write-Step "서비스 보안 정보: $service"
                # 보안상 실제 값은 마스킹하여 표시
                $maskedSecrets = @{}
                foreach ($prop in $secrets.services.$service.PSObject.Properties) {
                    $maskedSecrets[$prop.Name] = if ($prop.Value.Length -gt 8) { 
                        $prop.Value.Substring(0,4) + "****" + $prop.Value.Substring($prop.Value.Length-4)
                    } else { 
                        "****" 
                    }
                }
                $maskedSecrets | ConvertTo-Json | Write-Host
            } else {
                Write-Error "서비스를 찾을 수 없습니다: $service"
            }
        } else {
            Write-Step "등록된 서비스 목록:"
            $secrets.services.PSObject.Properties.Name | ForEach-Object {
                Write-Info "  - $_"
            }
        }
    }
    
    'generate' {
        if ($service -and $key) {
            $generatedValue = Generate-RandomString -Length 32
            
            if (!$secrets.services.$service) {
                $secrets.services | Add-Member -MemberType NoteProperty -Name $service -Value @{}
            }
            
            $finalValue = if ($encrypt) { Encrypt-Value $generatedValue $secrets.encryption_key } else { $generatedValue }
            $secrets.services.$service | Add-Member -MemberType NoteProperty -Name $key -Value $finalValue -Force
            
            try {
                $secrets | ConvertTo-Json -Depth 4 | Set-Content $secretsPath
                Write-Info "[$service] $key 에 대한 임의 값 생성 완료"
                Write-Warn "생성된 값: $generatedValue"
                Write-Warn "위 값을 안전한 곳에 기록해 두세요!"
            } catch {
                Write-Error "파일 저장 오류: $_"
            }
        } else {
            Write-Error "서비스와 키를 입력하세요"
        }
    }
    
    'backup' {
        $backupPath = "../../backup/secrets-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        try {
            Copy-Item $secretsPath $backupPath
            Write-Info "보안 정보 백업 완료: $backupPath"
        } catch {
            Write-Error "백업 오류: $_"
        }
    }
}