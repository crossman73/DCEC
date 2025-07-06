# PowerShell 네이밍 가이드 & 표준화 보고서
생성일시: 2025-07-06

## 📋 PowerShell 네이밍 규칙 적용 현황

### ✅ 적용된 네이밍 규칙

#### 1. **승인된 동사 사용 (Approved Verbs)**
- `New-MarkdownReport` → `Export-DCECMarkdownReport` (Export는 Data 그룹의 승인된 동사)
- `New-JsonReport` → `Export-DCECJsonReport`
- `New-ProjectManual` → `New-DCECProjectManual` (New는 Common 그룹의 승인된 동사)
- `Backup-ExistingFile` → `Backup-DCECFile` (Backup은 Data 그룹의 승인된 동사)

#### 2. **단수형 명사 사용 (Singular Nouns)**
```powershell
# PowerShell 규칙: 함수명은 단수형 명사 사용
✅ Export-DCECMarkdownReport (Report - 단수형)
✅ New-DCECServiceDirectory (Directory - 단수형)
✅ Backup-DCECFile (File - 단수형)
```

#### 3. **네임스페이스 적용 (Namespace Prefix)**
```powershell
# DCEC 프로젝트 전용 접두사로 내장 Cmdlet 충돌 방지
✅ Initialize-DCECWorkContext
✅ Test-DCECDirectoryStructure  
✅ Get-DCECDirectoryStatus
✅ Add-DCECDirectoryChange
✅ Write-DCECLog (Write-Log 내장 함수 충돌 해결)
```

### 📊 PowerShell 승인된 동사 분류

| 그룹 | 동사 | 용도 | 프로젝트 적용 |
|------|------|------|---------------|
| **Common** | New, Get, Set, Add, Remove | 기본 작업 | ✅ New-DCEC*, Get-DCEC*, Add-DCEC* |
| **Data** | Export, Import, Backup, Restore | 데이터 처리 | ✅ Export-DCEC*, Backup-DCEC* |
| **Lifecycle** | Initialize, Start, Stop, Enable | 생명주기 관리 | ✅ Initialize-DCEC* |
| **Diagnostic** | Test, Debug, Measure | 진단/테스트 | ✅ Test-DCEC* |

### 🔧 적용된 네이밍 변경사항

#### Before vs After
```powershell
# 기존 함수명 → 개선된 함수명
Initialize-WorkContext           → Initialize-DCECWorkContext
Add-DirectoryChange             → Add-DCECDirectoryChange  
Test-DirectoryStructure         → Test-DCECDirectoryStructure
New-ServiceDirectory            → New-DCECServiceDirectory
Initialize-DirectoryStructure   → Initialize-DCECDirectoryStructure
Get-DirectoryStatus             → Get-DCECDirectoryStatus
New-MarkdownReport              → Export-DCECMarkdownReport
New-JsonReport                  → Export-DCECJsonReport
Backup-ExistingFile             → Backup-DCECFile
New-ProjectManual               → New-DCECProjectManual
Write-Log                       → Write-DCECLog
```

### 🎯 PowerShell 모범 사례 적용

#### 1. **함수명 패턴**
```powershell
# 표준 패턴: 동사-네임스페이스접두사명사
Verb-DCECNoun
├── Initialize-DCECWorkContext
├── Test-DCECDirectoryStructure
└── Export-DCECMarkdownReport
```

#### 2. **매개변수 네이밍**
```powershell
# PascalCase 사용
[Parameter(Mandatory=$true)]
[string]$BasePath,

[Parameter(Mandatory=$true)]  
[hashtable]$Status
```

#### 3. **변수 네이밍**
```powershell
# script: 스코프 변수는 descriptive naming
$script:ServiceDirectories
$script:CommonDirectories  
$script:DirectoryHistory
$script:EnvironmentInfo
$script:WorkContext
```

### 📈 충돌 방지 효과

#### Before (충돌 위험)
```powershell
# PowerShell 7.1+ 내장 Write-Log와 충돌
function Write-Log { ... }

# 일반적인 함수명으로 다른 모듈과 충돌 가능
function New-MarkdownReport { ... }
```

#### After (충돌 해결)
```powershell
# DCEC 네임스페이스로 고유성 보장
function Write-DCECLog { ... }
function Export-DCECMarkdownReport { ... }
```

### 🔧 Fallback 메커니즘

```powershell
# logging.ps1 모듈이 로드되지 않은 경우를 위한 fallback
if (-not (Get-Command Write-DCECLog -ErrorAction SilentlyContinue)) {
    function Write-DCECLog {
        param([string]$Level, [string]$Message, [string]$Result = "", 
              [string]$Category = "", [string]$ProblemId = "")
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logLine = "[$timestamp] [$Level] [$Category] $Message"
        if ($Result) { $logLine += " | Result: $Result" }
        if ($ProblemId) { $logLine += " | Problem: $ProblemId" }
        Write-Host $logLine
    }
}
```

### 📋 Export-ModuleMember 정리

```powershell
# 명확한 공개 함수 정의
Export-ModuleMember -Function Initialize-DCECWorkContext, 
    Initialize-DCECDirectoryStructure, Test-DCECDirectoryStructure, 
    Get-DCECDirectoryStatus, Backup-DCECFile, New-DCECProjectManual,
    Export-DCECMarkdownReport, Export-DCECJsonReport, Add-DCECDirectoryChange
```

## 🎯 향후 적용 가이드라인

### 1. **새 함수 작성 시**
- DCEC 네임스페이스 접두사 필수
- PowerShell 승인된 동사만 사용
- 단수형 명사 사용
- PascalCase 적용

### 2. **기존 함수 리팩터링 시**  
- 순차적으로 DCEC 네임스페이스 적용
- 하위 호환성을 위한 별칭 고려
- 모듈 import 시점에서 충돌 검사

### 3. **모듈 설계 시**
- 명확한 Export-ModuleMember 정의
- Fallback 메커니즘 구현
- 의존성 순환 방지

## 📊 품질 지표

- **네이밍 규칙 준수율**: 100% (9개 함수 모두 적용)
- **내장 Cmdlet 충돌**: 0건 (Write-Log 충돌 해결)
- **승인된 동사 사용**: 100%
- **네임스페이스 적용**: 100%

---
*이 가이드는 PowerShell 공식 네이밍 가이드 및 모범 사례를 기반으로 작성되었습니다.*
