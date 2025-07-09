#requires -Version 7.0
<#
.SYNOPSIS
    DCEC Project Continuity Manager - 프로젝트 연속성 및 컨텍스트 관리 시스템
.DESCRIPTION
    IDE 재시작, 개발 중단 시에도 프로젝트 진행 상황과 룰을 유지하는 시스템
    - 현재 작업 상태 자동 저장
    - 프로젝트 룰과 가이드라인 지속 관리  
    - 개발 컨텍스트 복원
    - 다중 서브프로젝트 연속성 관리
.EXAMPLE
    .\Project-Continuity-Manager.ps1 -Action Initialize -Project "CPSE_n8n_Deployment"
    .\Project-Continuity-Manager.ps1 -Action SaveState -Message "n8n Docker 설정 완료"
    .\Project-Continuity-Manager.ps1 -Action RestoreContext
.NOTES
    Author: DCEC Development Team
    Date: 2025-07-07
    Version: 1.0
    Dependencies: DCECCore 모듈
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Initialize', 'SaveState', 'RestoreContext', 'ShowStatus', 'SetRule', 'GetRules', 'CreateDoc', 'UpdateDoc', 'ListDocs')]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$Project = "",
    
    [Parameter(Mandatory=$false)]
    [string]$SubProject = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Message = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Rule = "",
    
    [Parameter(Mandatory=$false)]
    [string]$DocType = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Version = ""
)

# 기본 경로 설정 (DCEC 네이밍 표준 적용)
$Script:DCEC_Root_Path = "c:\dev\DCEC"
$Script:DCEC_Global_LogsPath = Join-Path $DCEC_Root_Path "logs"
$Script:DCEC_Global_ChatPath = Join-Path $DCEC_Root_Path "chat"
$Script:DCEC_Global_DocsPath = Join-Path $DCEC_Root_Path "docs"

# DCEC 색상 로깅 함수 (충돌 방지를 위한 접두사 적용)
function Write-DCECColorLog {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Step')]
        [string]$Type = 'Info'
    )
    
    $DCEC_LogColors = @{
        'Info' = 'Cyan'
        'Success' = 'Green' 
        'Warning' = 'Yellow'
        'Error' = 'Red'
        'Step' = 'Magenta'
    }
    
    $DCEC_LogPrefixes = @{
        'Info' = '[INFO]'
        'Success' = '[✅]'
        'Warning' = '[⚠️]'
        'Error' = '[❌]'
        'Step' = '[🔄]'
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $($DCEC_LogPrefixes[$Type]) $Message"
    
    Write-Host $logMessage -ForegroundColor $DCEC_LogColors[$Type]
    
    # 로그 파일에도 기록
    $logFile = Join-Path $DCEC_Global_LogsPath "dcec_continuity_$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
}

# DCEC 프로젝트 상태 파일 경로 (네이밍 표준 적용)
function Get-DCECProjectStatePath {
    param([string]$ProjectName, [string]$SubProjectName = "")
    
    if ($SubProjectName) {
        return Join-Path $DCEC_Global_DocsPath "dcec_project_state_${ProjectName}_${SubProjectName}.json"
    } else {
        return Join-Path $DCEC_Global_DocsPath "dcec_project_state_${ProjectName}.json"
    }
}

# DCEC 현재 작업 상태 저장 (네이밍 표준 적용)
function Save-DCECProjectState {
    param(
        [string]$ProjectName,
        [string]$SubProjectName = "",
        [string]$Message,
        [string]$WorkingDirectory = $PWD.Path
    )
    
    $dcecStatePath = Get-DCECProjectStatePath -ProjectName $ProjectName -SubProjectName $SubProjectName
    
    $dcecState = @{
        Project = $ProjectName
        SubProject = $SubProjectName
        LastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Message = $Message
        WorkingDirectory = $WorkingDirectory
        Rules = @()
        Guidelines = @()
        CurrentTasks = @()
        CompletedTasks = @()
        NextSteps = @()
        Environment = @{
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            OSVersion = [System.Environment]::OSVersion.ToString()
            UserName = $env:USERNAME
            ComputerName = $env:COMPUTERNAME
        }
    }
    
    # 기존 상태가 있으면 병합
    if (Test-Path $dcecStatePath) {
        try {
            $existingState = Get-Content $dcecStatePath -Raw | ConvertFrom-Json
            $dcecState.Rules = $existingState.Rules
            $dcecState.Guidelines = $existingState.Guidelines
            $dcecState.CompletedTasks = $existingState.CompletedTasks
        } catch {
            Write-DCECColorLog "기존 상태 파일 읽기 실패, 새로 생성합니다." "Warning"
        }
    }
    
    $dcecState | ConvertTo-Json -Depth 10 | Set-Content $dcecStatePath -Encoding UTF8
    Write-DCECColorLog "프로젝트 상태 저장 완료: $dcecStatePath" "Success"
}

# 프로젝트 컨텍스트 복원
function Restore-ProjectContext {
    param(
        [string]$ProjectName = "",
        [string]$SubProjectName = ""
    )
    
    # 최근 상태 파일 찾기
    $stateFiles = Get-ChildItem -Path $GlobalDocsPath -Filter "project_state_*.json" | Sort-Object LastWriteTime -Descending
    
    if (-not $stateFiles) {
        Write-ColorLog "저장된 프로젝트 상태가 없습니다." "Warning"
        return
    }
    
    $stateFile = $stateFiles[0]
    if ($ProjectName) {
        $targetFile = $stateFiles | Where-Object { $_.Name -like "*$ProjectName*" } | Select-Object -First 1
        if ($targetFile) { $stateFile = $targetFile }
    }
    
    try {
        $state = Get-Content $stateFile.FullName -Raw | ConvertFrom-Json
        
        Write-ColorLog "=== 프로젝트 컨텍스트 복원 ===" "Step"
        Write-ColorLog "프로젝트: $($state.Project)" "Info"
        if ($state.SubProject) { Write-ColorLog "서브프로젝트: $($state.SubProject)" "Info" }
        Write-ColorLog "마지막 업데이트: $($state.LastUpdate)" "Info"
        Write-ColorLog "마지막 메시지: $($state.Message)" "Info"
        Write-ColorLog "작업 디렉토리: $($state.WorkingDirectory)" "Info"
        
        # 작업 디렉토리 변경
        if ($state.WorkingDirectory -and (Test-Path $state.WorkingDirectory)) {
            Set-Location $state.WorkingDirectory
            Write-ColorLog "작업 디렉토리로 이동: $($state.WorkingDirectory)" "Success"
        }
        
        # 룰과 가이드라인 표시
        if ($state.Rules.Count -gt 0) {
            Write-ColorLog "=== 프로젝트 룰 ===" "Step"
            $state.Rules | ForEach-Object { Write-ColorLog "• $_" "Info" }
        }
        
        if ($state.Guidelines.Count -gt 0) {
            Write-ColorLog "=== 가이드라인 ===" "Step"
            $state.Guidelines | ForEach-Object { Write-ColorLog "• $_" "Info" }
        }
        
        if ($state.NextSteps.Count -gt 0) {
            Write-ColorLog "=== 다음 단계 ===" "Step"
            $state.NextSteps | ForEach-Object { Write-ColorLog "• $_" "Info" }
        }
        
        return $state
        
    } catch {
        Write-ColorLog "상태 파일 복원 실패: $_" "Error"
        return $null
    }
}

# 프로젝트 룰 설정
function Set-ProjectRule {
    param(
        [string]$ProjectName,
        [string]$SubProjectName = "",
        [string]$Rule
    )
    
    $statePath = Get-ProjectStatePath -ProjectName $ProjectName -SubProjectName $SubProjectName
    
    if (Test-Path $statePath) {
        $state = Get-Content $statePath -Raw | ConvertFrom-Json
    } else {
        Write-ColorLog "프로젝트 상태가 없습니다. 먼저 Initialize를 실행하세요." "Error"
        return
    }
    
    if ($state.Rules -notcontains $Rule) {
        $state.Rules += $Rule
        $state | ConvertTo-Json -Depth 10 | Set-Content $statePath -Encoding UTF8
        Write-ColorLog "룰 추가 완료: $Rule" "Success"
    } else {
        Write-ColorLog "이미 존재하는 룰입니다." "Warning"
    }
}

# 문서 버전 관리 시스템
function Get-DocumentVersion {
    param([string]$ProjectName, [string]$DocType)
    
    $versionFile = Join-Path $GlobalDocsPath "document_versions.json"
    
    if (Test-Path $versionFile) {
        $versions = Get-Content $versionFile -Raw | ConvertFrom-Json
        $key = "${ProjectName}_${DocType}"
        if ($versions.$key) {
            return $versions.$key.Version
        }
    }
    
    return "1.0"
}

function Update-DocumentVersion {
    param([string]$ProjectName, [string]$DocType, [string]$FilePath, [string]$ChangeDescription = "")
    
    $versionFile = Join-Path $GlobalDocsPath "document_versions.json"
    
    # 기존 버전 정보 로드
    if (Test-Path $versionFile) {
        $versions = Get-Content $versionFile -Raw | ConvertFrom-Json
    } else {
        $versions = @{}
    }
    
    $key = "${ProjectName}_${DocType}"
    $currentVersion = if ($versions.$key) { $versions.$key.Version } else { "1.0" }
    
    # 버전 증가
    $versionParts = $currentVersion.Split('.')
    $majorVersion = [int]$versionParts[0]
    $minorVersion = [int]$versionParts[1]
    $minorVersion++
    $newVersion = "$majorVersion.$minorVersion"
    
    # 새 버전 정보 저장
    $versions.$key = @{
        Version = $newVersion
        LastUpdate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        FilePath = $FilePath
        ChangeDescription = $ChangeDescription
        History = if ($versions.$key.History) { $versions.$key.History } else { @() }
    }
    
    # 이전 버전을 히스토리에 추가
    if ($versions.$key.History) {
        $versions.$key.History += @{
            Version = $currentVersion
            Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Description = $ChangeDescription
        }
    }
    
    $versions | ConvertTo-Json -Depth 10 | Set-Content $versionFile -Encoding UTF8
    
    Write-ColorLog "문서 버전 업데이트: $DocType v$newVersion" "Success"
    return $newVersion
}

function Create-VersionedDocument {
    param([string]$ProjectName, [string]$DocType, [string]$Content)
    
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $version = Get-DocumentVersion -ProjectName $ProjectName -DocType $DocType
    $fileName = "${ProjectName}_${DocType}_v${version}_${timestamp}.md"
    $filePath = Join-Path $GlobalDocsPath $fileName
    
    # 버전 헤더 추가
    $versionHeader = @"
<!-- 
Document Version: $version
Project: $ProjectName
Type: $DocType
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Auto-generated by DCEC Project Continuity Manager
-->

"@
    
    $fullContent = $versionHeader + $Content
    Set-Content -Path $filePath -Value $fullContent -Encoding UTF8
    
    # 버전 정보 업데이트
    Update-DocumentVersion -ProjectName $ProjectName -DocType $DocType -FilePath $filePath -ChangeDescription "새 문서 생성"
    
    Write-ColorLog "버전 관리 문서 생성: $fileName" "Success"
    return $filePath
}

# 메인 로직
switch ($Action) {
    'Initialize' {
        Write-DCECColorLog "=== DCEC 프로젝트 연속성 시스템 초기화 ===" "Step"
        
        if (-not $Project) {
            $Project = Read-Host "프로젝트 이름을 입력하세요"
        }
        
        # 기본 디렉토리 생성 확인
        @($DCEC_Global_LogsPath, $DCEC_Global_ChatPath, $DCEC_Global_DocsPath) | ForEach-Object {
            if (-not (Test-Path $_)) {
                New-Item -ItemType Directory -Path $_ -Force | Out-Null
                Write-DCECColorLog "디렉토리 생성: $_" "Success"
            }
        }
        
        # 초기 상태 저장
        Save-DCECProjectState -ProjectName $Project -SubProjectName $SubProject -Message "프로젝트 초기화"
        
        # 기본 룰 설정
        $defaultRules = @(
            "모든 작업은 로그를 남겨 디버깅과 추적이 가능해야 함"
            "문서 업데이트는 작업과 동시에 진행"
            "각 단계별 테스트와 검증 수행"
            "IDE 재시작 전 반드시 상태 저장"
            "오류 발생 시 즉시 로깅 및 문제 추적"
        )
        
        foreach ($rule in $defaultRules) {
            Set-ProjectRule -ProjectName $Project -SubProjectName $SubProject -Rule $rule
        }
        
        Write-ColorLog "프로젝트 '$Project' 초기화 완료" "Success"
    }
    
    'SaveState' {
        if (-not $Project) {
            Write-DCECColorLog "프로젝트 이름이 필요합니다." "Error"
            return
        }
        
        Save-DCECProjectState -ProjectName $Project -SubProjectName $SubProject -Message $Message
    }
    
    'RestoreContext' {
        $restoredState = Restore-ProjectContext -ProjectName $Project -SubProjectName $SubProject
        return $restoredState
    }
    
    'ShowStatus' {
        $stateFiles = Get-ChildItem -Path $GlobalDocsPath -Filter "project_state_*.json" | Sort-Object LastWriteTime -Descending
        
        if (-not $stateFiles) {
            Write-ColorLog "저장된 프로젝트가 없습니다." "Warning"
            return
        }
        
        Write-ColorLog "=== 저장된 프로젝트 목록 ===" "Step"
        foreach ($file in $stateFiles) {
            try {
                $state = Get-Content $file.FullName -Raw | ConvertFrom-Json
                Write-ColorLog "• $($state.Project)$(if($state.SubProject){' → '+$state.SubProject}) (마지막: $($state.LastUpdate))" "Info"
                Write-ColorLog "  메시지: $($state.Message)" "Info"
            } catch {
                Write-ColorLog "• $($file.Name) (파일 읽기 오류)" "Warning"
            }
        }
    }
    
    'SetRule' {
        if (-not $Project -or -not $Rule) {
            Write-ColorLog "프로젝트 이름과 룰이 필요합니다." "Error"
            return
        }
        
        Set-ProjectRule -ProjectName $Project -SubProjectName $SubProject -Rule $Rule
    }
    
    'GetRules' {
        if (-not $Project) {
            Write-ColorLog "프로젝트 이름이 필요합니다." "Error"
            return
        }
        
        $statePath = Get-ProjectStatePath -ProjectName $Project -SubProjectName $SubProject
        if (Test-Path $statePath) {
            $state = Get-Content $statePath -Raw | ConvertFrom-Json
            Write-ColorLog "=== $Project 프로젝트 룰 ===" "Step"
            $state.Rules | ForEach-Object { Write-ColorLog "• $_" "Info" }
        } else {
            Write-ColorLog "프로젝트 상태 파일이 없습니다." "Warning"
        }
    }
    
    'CreateDoc' {
        if (-not $Project -or -not $DocType) {
            Write-ColorLog "프로젝트 이름과 문서 타입이 필요합니다." "Error"
            return
        }
        
        $template = switch ($DocType) {
            "guide" {
                @"
# $Project 프로젝트 가이드

## 📋 프로젝트 개요
- **프로젝트명**: $Project
- **생성일**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## 🎯 프로젝트 목표
[프로젝트 목표 작성]

## 🏗️ 시스템 아키텍처
[아키텍처 설명]

## 🔧 기술 스택
[기술 스택 나열]

## 📁 프로젝트 구조
[프로젝트 구조 설명]

## 🔄 개발 프로세스
[개발 프로세스 설명]

---
**작성자**: DCEC Development Team  
**최종 수정**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
            }
            "manual" {
                @"
# $Project 운영 매뉴얼

## 📋 매뉴얼 정보
- **서비스명**: $Project
- **생성일**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## 🚀 서비스 시작 및 중지
[서비스 관리 명령어]

## 🔧 설치 절차
[설치 단계별 설명]

## 📊 모니터링 및 로그 관리
[모니터링 방법]

## 💾 백업 및 복구
[백업/복구 절차]

## 🚨 문제 해결
[문제 해결 가이드]

---
**작성자**: DCEC Development Team  
**최종 수정**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
            }
            "deployment" {
                @"
# $Project 배포 가이드

## 📋 배포 정보
- **프로젝트명**: $Project
- **생성일**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## 🚀 배포 단계
### 1단계: 환경 준비
### 2단계: 서비스 배포
### 3단계: 검증 및 테스트

## 🔧 배포 스크립트
[배포 명령어 및 스크립트]

## ✅ 배포 체크리스트
- [ ] 환경 변수 설정
- [ ] 서비스 시작 확인
- [ ] 접속 테스트

---
**작성자**: DCEC Development Team  
**최종 수정**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
            }
        }
        
        $createdFile = Create-VersionedDocument -ProjectName $Project -DocType $DocType -Content $template
        Write-ColorLog "새 문서 생성 완료: $createdFile" "Success"
    }
    
    'UpdateDoc' {
        if (-not $Project -or -not $DocType) {
            Write-ColorLog "프로젝트 이름과 문서 타입이 필요합니다." "Error"
            return
        }
        
        $newVersion = Update-DocumentVersion -ProjectName $Project -DocType $DocType -FilePath "" -ChangeDescription $Message
        Write-ColorLog "문서 버전 업데이트 완료: $DocType v$newVersion" "Success"
    }
    
    'ListDocs' {
        $versionFile = Join-Path $GlobalDocsPath "document_versions.json"
        
        if (Test-Path $versionFile) {
            $versions = Get-Content $versionFile -Raw | ConvertFrom-Json
            Write-ColorLog "=== 문서 버전 관리 목록 ===" "Step"
            
            $versions.PSObject.Properties | ForEach-Object {
                $key = $_.Name
                $info = $_.Value
                Write-ColorLog "• $key v$($info.Version) (마지막: $($info.LastUpdate))" "Info"
                if ($info.ChangeDescription) {
                    Write-ColorLog "  변경사항: $($info.ChangeDescription)" "Info"
                }
            }
        } else {
            Write-ColorLog "저장된 문서 버전 정보가 없습니다." "Warning"
        }
    }
}
