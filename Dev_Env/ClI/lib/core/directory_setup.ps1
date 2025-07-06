# 디렉토리 구조 설정 모듈
using module '.\logging.ps1'
# Fallback 로깅 함수 - logging.ps1에서 Write-Log가 로드되지 않은 경우 사용
if (-not (Get-Command Write-DCECLog -ErrorAction SilentlyContinue)) {
    function Write-DCECLog {
        param(
            [string]$Level,
            [string]$Message,
            [string]$Result = "",
            [string]$Category = "",
            [string]$ProblemId = ""
        )
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logLine = "[$timestamp] [$Level] [$Category] $Message"
        if ($Result) { $logLine += " | Result: $Result" }
        if ($ProblemId) { $logLine += " | Problem: $ProblemId" }
        Write-Information $logLine -InformationAction Continue
    }
}
# 스크립트 전역 변수
$script:ServiceDirectories = @(
    'ClaudeCodeService',
    'UtilsService',
    'GeminiService',
    'BackupService'
)
$script:CommonDirectories = @(
    'lib',
    'bin',
    'docs',
    'config'
)
# 작업 컨텍스트 및 이력 추적
$script:DirectoryHistory = @()
$script:EnvironmentInfo = $null
$script:WorkContext = $null
function Initialize-DCECWorkContext {
    <#
    .SYNOPSIS
    DCEC 프로젝트의 작업 컨텍스트를 초기화합니다.
    .DESCRIPTION
    지정된 기본 경로에서 DCEC 프로젝트의 작업 컨텍스트를 초기화하고
    환경 정보를 수집하여 전역 변수에 저장합니다.
    .PARAMETER BasePath
    초기화할 프로젝트의 기본 경로입니다.
    .PARAMETER Description
    작업 컨텍스트에 대한 설명입니다. (선택사항)
    .PARAMETER ProblemId
    문제 추적을 위한 문제 ID입니다. (선택사항)
    .EXAMPLE
    Initialize-DCECWorkContext -BasePath "D:\Dev\MyProject" -Description "새 프로젝트 초기화"
    .NOTES
    이 함수는 DCEC 네임스페이스를 사용합니다.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [string]$Description = "",
        [string]$ProblemId = ""
    )
    try {
        # 환경 정보 수집
        $script:EnvironmentInfo = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            PowerShell = $PSVersionTable.PSVersion.ToString()
            Username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            ComputerName = $env:COMPUTERNAME
            WorkingDirectory = (Get-Location).Path
            ExecutionPolicy = (Get-ExecutionPolicy).ToString()
        }
        # 작업 컨텍스트 초기화
        $script:WorkContext = @{
            SessionId = $script:SessionId  # logging.ps1에서 설정된 세션 ID 사용
            BasePath = $BasePath
            Description = $Description
            ProblemId = $ProblemId
            StartTime = Get-Date
            Changes = @()
        }
        # 작업 시작 로그
        $logMessage = @"
작업 컨텍스트 초기화:
- 세션 ID: $($script:SessionId)
- 작업 경로: $BasePath
- 설명: $Description
- 문제 ID: $($ProblemId ? $ProblemId : "N/A")
"@
        Write-DCECLog -Level INFO -Message $logMessage -Category "작업컨텍스트" -ProblemId $ProblemId
        # 환경 정보 로깅
        $envInfo = $script:EnvironmentInfo | ConvertTo-Json
        Write-DCECLog -Level INFO -Message "환경 정보:`n$envInfo" -Category "환경" -ProblemId $ProblemId
    }
    catch {
        Write-DCECLog -Level ERROR -Message "작업 컨텍스트 초기화 실패" -Result $_.Exception.Message -Category "작업컨텍스트"
        throw
    }
}
function Add-DCECDirectoryChange {
    <#
    .SYNOPSIS
    DCEC 프로젝트의 디렉토리 변경 사항을 추적합니다.
    .DESCRIPTION
    디렉토리 생성, 삭제, 수정 등의 변경 사항을 작업 컨텍스트에 기록하여
    변경 이력을 추적할 수 있도록 합니다.
    .PARAMETER Action
    수행된 작업의 유형 (예: Create, Delete, Modify)
    .PARAMETER Path
    변경된 디렉토리의 경로
    .PARAMETER Details
    변경에 대한 추가 세부사항 (선택사항)
    .PARAMETER Result
    작업 결과 (기본값: Success)
    .EXAMPLE
    Add-DCECDirectoryChange -Action "Create" -Path "D:\Dev\MyProject\lib" -Details "라이브러리 디렉토리 생성"
    .NOTES
    이 함수는 Initialize-DCECWorkContext가 먼저 호출되어야 합니다.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$Action,
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string]$Details = "",
        [string]$Result = "Success"
    )
    if (!$script:WorkContext) {
        Write-DCECLog -Level ERROR -Message "작업 컨텍스트가 초기화되지 않았습니다." -Category "작업컨텍스트"
        return
    }
    $change = @{
        Timestamp = Get-Date
        Action = $Action
        Path = $Path
        Details = $Details
        Result = $Result
    }
    $script:WorkContext.Changes += $change
    $script:DirectoryHistory += $change
}
function Test-DCECDirectoryStructure {
    <#
    .SYNOPSIS
    DCEC 프로젝트의 디렉토리 구조를 검증합니다.
    
    .DESCRIPTION
    지정된 기본 경로에서 필요한 서비스 디렉토리와 공통 디렉토리가 모두 존재하는지 확인합니다.
    
    .PARAMETER BasePath
    검증할 프로젝트의 기본 경로
    
    .EXAMPLE
    Test-DCECDirectoryStructure -BasePath "D:\Dev\MyProject"
    
    .OUTPUTS
    IsValid: 구조가 유효한지 여부
    MissingDirs: 누락된 디렉토리 목록
    
    .NOTES
    이 함수는 DCEC 네임스페이스를 사용합니다.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath
    )
    try {
        $allDirs = $script:ServiceDirectories + $script:CommonDirectories
        $missing = @()
        foreach ($dir in $allDirs) {
            $path = Join-Path $BasePath $dir
            if (!(Test-Path $path)) {
                $missing += $dir
            }
        }
        return @{
            IsValid = ($missing.Count -eq 0)
            MissingDirs = $missing
        }
    }
    catch {
        Write-DCECLog -Level ERROR -Message "디렉토리 구조 검증 실패" -Result $_.Exception.Message
        throw
    }
}
function New-DCECServiceDirectory {
    <#
    .SYNOPSIS
    DCEC 프로젝트에 새로운 서비스 디렉토리를 생성합니다.
    .DESCRIPTION
    지정된 기본 경로에 서비스 디렉토리와 표준 하위 디렉토리들(src, tests, docs, config)을 생성합니다.
    .PARAMETER BasePath
    서비스 디렉토리를 생성할 기본 경로
    .PARAMETER ServiceName
    생성할 서비스의 이름
    .EXAMPLE
    New-DCECServiceDirectory -BasePath "D:\Dev\MyProject" -ServiceName "UserService"
    .NOTES
    이 함수는 DCEC 네임스페이스를 사용합니다.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )
    try {
        $servicePath = Join-Path $BasePath $ServiceName
        if (!(Test-Path $servicePath)) {
            Write-DCECLog -Level INFO -Message "서비스 디렉토리 생성: $ServiceName" -Category "디렉토리"
            New-Item -Path $servicePath -ItemType Directory -Force | Out-Null
            Add-DCECDirectoryChange -Action "Create" -Path $servicePath -Details "서비스 디렉토리 생성"
            # 서비스별 하위 디렉토리 생성
            @('src', 'tests', 'docs', 'config') | ForEach-Object {
                $subDir = Join-Path $servicePath $_
                New-Item -Path $subDir -ItemType Directory -Force | Out-Null
                Add-DCECDirectoryChange -Action "Create" -Path $subDir -Details "서비스 하위 디렉토리 생성"
            }
            Write-DCECLog -Level INFO -Message "서비스 디렉토리 생성 완료" -Result "Success" -Category "디렉토리"
        }
        else {
            Write-DCECLog -Level WARNING -Message "이미 존재하는 서비스 디렉토리: $ServiceName" -Category "디렉토리"
            Add-DCECDirectoryChange -Action "Skip" -Path $servicePath -Details "이미 존재하는 디렉토리" -Result "Skipped"
        }
    }
    catch {
        Write-DCECLog -Level ERROR -Message "서비스 디렉토리 생성 실패: $ServiceName" -Result $_.Exception.Message -Category "디렉토리"
        Add-DCECDirectoryChange -Action "Error" -Path $servicePath -Details $_.Exception.Message -Result "Failed"
        throw
    }
}
function Initialize-DCECDirectoryStructure {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [switch]$Force
    )
    try {
        # 기본 디렉토리 구조 검증
        $structureCheck = Test-DCECDirectoryStructure -BasePath $BasePath
        if (!$structureCheck.IsValid -or $Force) {
            Write-DCECLog -Level INFO -Message "디렉토리 구조 초기화 시작"
            # 서비스 디렉토리 생성
            foreach ($service in $script:ServiceDirectories) {
                New-DCECServiceDirectory -BasePath $BasePath -ServiceName $service
            }
            # 공통 디렉토리 생성
            foreach ($dir in $script:CommonDirectories) {
                $path = Join-Path $BasePath $dir
                if (!(Test-Path $path)) {
                    New-Item -Path $path -ItemType Directory -Force | Out-Null
                    Write-DCECLog -Level INFO -Message "공통 디렉토리 생성: $dir"
                }
            }
            Write-DCECLog -Level INFO -Message "디렉토리 구조 초기화 완료" -Result "Success"
        }
        else {
            Write-DCECLog -Level INFO -Message "디렉토리 구조가 이미 올바르게 설정되어 있습니다."
        }
    }
    catch {
        Write-DCECLog -Level ERROR -Message "디렉토리 구조 초기화 실패" -Result $_.Exception.Message
        throw
    }
}
# 상태 보고서 생성
function Get-DCECDirectoryStatus {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [switch]$GenerateReport
    )
    try {
        $status = @{
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            BasePath = $BasePath
            Services = @{
                }
            Common = @{
                }
            WorkContext = $script:WorkContext
            EnvironmentInfo = $script:EnvironmentInfo
            History = $script:DirectoryHistory
        }
        # 서비스 디렉토리 상태 확인
        foreach ($service in $script:ServiceDirectories) {
            $path = Join-Path $BasePath $service
            $status.Services[$service] = @{
                Exists = Test-Path $path
                SubDirectories = if (Test-Path $path) {
                    Get-ChildItem -Path $path -Directory | Select-Object -ExpandProperty Name
                } else { @() }
            }
        }
        # 공통 디렉토리 상태 확인
        foreach ($dir in $script:CommonDirectories) {
            $path = Join-Path $BasePath $dir
            $status.Common[$dir] = @{
                Exists = Test-Path $path
                ItemCount = if (Test-Path $path) {
                    (Get-ChildItem -Path $path -Recurse).Count
                } else { 0 }
            }
        }
        if ($GenerateReport) {
            # HTML 보고서 생성
            $htmlReportPath = Join-Path $BasePath "docs/directory_report.html"
            $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>디렉토리 구조 보고서</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .section { margin: 20px 0; padding: 10px; border: 1px solid #ddd; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
        .timestamp { color: #666; font-size: 0.9em; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .header { background-color: #4a90e2; color: white; padding: 20px; margin-bottom: 20px; }
        .footer { margin-top: 30px; padding: 10px; border-top: 1px solid #ddd; }
    </style>
</head>
<body>
    <div class="header">
        <h1>디렉토리 구조 보고서</h1>
        <div class="timestamp">생성 시각: $($status.Timestamp)</div>
    </div>
    <div class="section">
        <h2>작업 정보</h2>
        <p>세션 ID: $($script:WorkContext.SessionId)</p>
        <p>시작 시간: $($script:WorkContext.StartTime)</p>
        <p>기본 경로: $($script:WorkContext.BasePath)</p>
        <p>설명: $($script:WorkContext.Description)</p>
        <p>문제 ID: $($script:WorkContext.ProblemId)</p>
    </div>
    <div class="section">
        <h2>환경 정보</h2>
        <table>
            <tr><th>항목</th><th>값</th></tr>
            $(
                $script:EnvironmentInfo.GetEnumerator() | ForEach-Object {
                    "<tr><td>$($_.Key)</td><td>$($_.Value)</td></tr>"
                }
            )
        </table>
    </div>
    <div class="section">
        <h2>서비스 디렉토리 상태</h2>
        <table>
            <tr><th>서비스</th><th>상태</th><th>하위 디렉토리</th></tr>
            $(
                $status.Services.GetEnumerator() | ForEach-Object {
                    $class = if ($_.Value.Exists) { "success" } else { "error" }
                    "<tr class='$class'>
                        <td>$($_.Key)</td>
                        <td>$($_.Value.Exists ? '존재' : '없음')</td>
                        <td>$($_.Value.SubDirectories -join ', ')</td>
                    </tr>"
                }
            )
        </table>
    </div>
    <div class="section">
        <h2>디렉토리 변경 이력</h2>
        <table>
            <tr><th>시간</th><th>작업</th><th>경로</th><th>상태</th><th>상세</th></tr>
            $(
                $script:DirectoryHistory | ForEach-Object {
                    $class = switch ($_.Result) {
                        "Success" { "success" }
                        "Failed" { "error" }
                        "Skipped" { "warning" }
                        default { "" }
                    }
                    "<tr class='$class'>
                        <td>$($_.Timestamp)</td>
                        <td>$($_.Action)</td>
                        <td>$($_.Path)</td>
                        <td>$($_.Result)</td>
                        <td>$($_.Details)</td>
                    </tr>"
                }
            )
        </table>
    </div>
    <div class="footer">
        <p>총 서비스 디렉토리: $($status.Services.Count)</p>
        <p>총 공통 디렉토리: $($status.Common.Count)</p>
        <p>총 변경 사항: $($script:DirectoryHistory.Count)</p>
    </div>
</body>
</html>
"@
            $htmlContent | Out-File -FilePath $htmlReportPath -Encoding UTF8
            Write-DCECLog -Level INFO -Message "HTML 보고서 생성 완료" -Result $htmlReportPath -Category "보고서"
            # Markdown 요약 보고서 생성
            $null = Export-DCECMarkdownReport -BasePath $BasePath -Status $status
            # JSON 상태 보고서 생성
            $null = Export-DCECJsonReport -BasePath $BasePath -Status $status
        }
        return $status
    }
    catch {
        Write-DCECLog -Level ERROR -Message "디렉토리 상태 보고서 생성 실패" -Result $_.Exception.Message -Category "보고서"
        throw
    }
}
# 보고서 관련 함수들 - DCEC 네임스페이스 적용
function Export-DCECMarkdownReport {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [Parameter(Mandatory=$true)]
        [hashtable]$Status
    )
    try {
        $reportPath = Join-Path $BasePath "docs/directory_summary.md"
        $markdown = @"
# 디렉토리 구조 요약 보고서
생성 시각: $($Status.Timestamp)
## 1. 작업 정보
- 세션 ID: $($script:WorkContext.SessionId)
- 시작 시간: $($script:WorkContext.StartTime)
- 작업 설명: $($script:WorkContext.Description)
- 문제 ID: $($script:WorkContext.ProblemId)
## 2. 환경 정보
| 항목 | 값 |
|------|-----|
$(
    $script:EnvironmentInfo.GetEnumerator() | ForEach-Object {
        "| $($_.Key) | $($_.Value) |"
    }
)
## 3. 서비스 디렉토리 상태
| 서비스 | 상태 | 하위 디렉토리 |
|--------|------|--------------|
$(
    $Status.Services.GetEnumerator() | ForEach-Object {
        $exists = if ($_.Value.Exists) { "✅" } else { "❌" }
        "| $($_.Key) | $exists | $($_.Value.SubDirectories -join ', ') |"
    }
)
## 4. 공통 디렉토리 상태
| 디렉토리 | 상태 | 항목 수 |
|----------|------|---------|
$(
    $Status.Common.GetEnumerator() | ForEach-Object {
        $exists = if ($_.Value.Exists) { "✅" } else { "❌" }
        "| $($_.Key) | $exists | $($_.Value.ItemCount) |"
    }
)
## 5. 변경 이력
$(
    $script:DirectoryHistory | ForEach-Object {
        "- [$($_.Timestamp.ToString('HH:mm:ss'))] $($_.Action): $($_.Path) [$($_.Result)]"
    }
)
## 6. 요약
- 총 서비스 디렉토리: $($Status.Services.Count)
- 총 공통 디렉토리: $($Status.Common.Count)
- 총 변경 사항: $($script:DirectoryHistory.Count)
"@
        $markdown | Out-File -FilePath $reportPath -Encoding UTF8
        Write-DCECLog -Level INFO -Message "Markdown 요약 보고서 생성 완료" -Result $reportPath -Category "보고서"
        return $reportPath
    }
    catch {
        Write-DCECLog -Level ERROR -Message "Markdown 보고서 생성 실패" -Result $_.Exception.Message -Category "보고서"
        throw
    }
}
function Export-DCECJsonReport {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [Parameter(Mandatory=$true)]
        [hashtable]$Status
    )
    try {
        $reportPath = Join-Path $BasePath "docs/directory_status.json"
        $jsonContent = $Status | ConvertTo-Json -Depth 10
        $jsonContent | Out-File -FilePath $reportPath -Encoding UTF8
        Write-DCECLog -Level INFO -Message "JSON 상태 보고서 생성 완료" -Result $reportPath -Category "보고서"
        return $reportPath
    }
    catch {
        Write-DCECLog -Level ERROR -Message "JSON 보고서 생성 실패" -Result $_.Exception.Message -Category "보고서"
        throw
    }
}
function Backup-DCECFile {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    if (Test-Path $FilePath) {
        try {
            $directory = Split-Path $FilePath -Parent
            $fileName = Split-Path $FilePath -Leaf
            $extension = [System.IO.Path]::GetExtension($fileName)
            $nameWithoutExt = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $timestamp = Get-Date -Format "yyyyMMddHHmmss"
            $backupName = "${nameWithoutExt}_old_${timestamp}${extension}"
            $backupPath = Join-Path $directory $backupName
            Move-Item -Path $FilePath -Destination $backupPath -Force
            Write-DCECLog -Level INFO -Message "파일 백업 생성" -Result "원본: $FilePath -> 백업: $backupPath" -Category "백업"
            return $backupPath
        }
        catch {
            Write-DCECLog -Level ERROR -Message "파일 백업 실패: $FilePath" -Result $_.Exception.Message -Category "백업"
            throw
        }
    }
    return $null
}
function New-DCECProjectManual {
    param (
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [string]$ProjectName = "DCEC"
    )
    try {
        $manualDir = Join-Path $BasePath "docs\manual"
        if (!(Test-Path $manualDir)) {
            New-Item -Path $manualDir -ItemType Directory -Force | Out-Null
        }
        # 프로젝트 구조 매뉴얼
        $structureManual = Join-Path $manualDir "01_project_structure.md"
        @"
# $ProjectName 프로젝트 구조 가이드
## 1. 디렉토리 구조 개요
### 1.1 서비스 디렉토리
$(
    $script:ServiceDirectories | ForEach-Object {
        "- **$_/**
  - src/ : 소스 코드
  - tests/ : 테스트 코드
  - docs/ : 서비스별 문서
  - config/ : 설정 파일"
    }
)
### 1.2 공통 디렉토리
$(
    $script:CommonDirectories | ForEach-Object {
        "- **$_/**"
    }
)
## 2. 주요 디렉토리 설명
### 2.1 서비스 디렉토리
각 서비스는 독립적인 기능 단위로 구성되며, 다음과 같은 구조를 가집니다:
- **ClaudeCodeService/**: Claude AI 관련 코드 서비스
- **UtilsService/**: 공통 유틸리티 서비스
- **GeminiService/**: Gemini AI 관련 코드 서비스
- **BackupService/**: 백업 관리 서비스
### 2.2 공통 디렉토리
- **lib/**: 공통 라이브러리 및 모듈
- **bin/**: 실행 파일 및 스크립트
- **docs/**: 프로젝트 문서
- **config/**: 전역 설정 파일
## 3. 명명 규칙
- 서비스 디렉토리: PascalCase (예: ClaudeCodeService)
- 소스 파일: snake_case (예: utility_functions.ps1)
- 설정 파일: lowercase (예: config.json)
"@ | Out-File -FilePath $structureManual -Encoding UTF8
        # 실행 명령어 매뉴얼
        $commandManual = Join-Path $manualDir "02_command_reference.md"
        @"
# $ProjectName 실행 명령어 가이드
## 1. 환경 설정 명령어
### 1.1 초기 설정
\`\`\`powershell
# 로깅 시스템 초기화
Initialize-Logging -Type "DCEC" -BaseDir "./Dev_Env/ClI"
# 작업 컨텍스트 초기화
Initialize-WorkContext -BasePath "./Dev_Env/ClI" -Description "작업설명"
# 디렉토리 구조 초기화
Initialize-DirectoryStructure -BasePath "./Dev_Env/ClI" -Force
\`\`\`
### 1.2 상태 확인
\`\`\`powershell
# 디렉토리 구조 검증
Test-DirectoryStructure -BasePath "./Dev_Env/ClI"
# 상태 보고서 생성
Get-DirectoryStatus -BasePath "./Dev_Env/ClI" -GenerateReport
\`\`\`
## 2. 서비스별 명령어
### 2.1 ClaudeCodeService
\`\`\`powershell
# 서비스 디렉토리 생성
New-ServiceDirectory -BasePath "./Dev_Env/ClI" -ServiceName "ClaudeCodeService"
\`\`\`
### 2.2 GeminiService
\`\`\`powershell
# 서비스 디렉토리 생성
New-ServiceDirectory -BasePath "./Dev_Env/ClI" -ServiceName "GeminiService"
\`\`\`
## 3. 로깅 및 문제 해결
### 3.1 로그 관리
\`\`\`powershell
# 로그 메시지 작성
Write-Log -Level INFO -Message "메시지" -Category "카테고리"
# 문제 추적 시작
Start-ProblemTracking -ProblemId "PROB-001" -Description "문제 설명"
# 문제 해결 상태 업데이트
Update-ProblemStatus -ProblemId "PROB-001" -Status "해결됨" -Resolution "해결 내용"
\`\`\`
"@ | Out-File -FilePath $commandManual -Encoding UTF8
        # 사용자 가이드
        $userGuide = Join-Path $manualDir "03_user_guide.md"
        @"
# $ProjectName 사용자 가이드
## 1. 시작하기
### 1.1 필수 요구사항
- PowerShell 7.0 이상
- 관리자 권한
- Git 설치
### 1.2 초기 설정
1. 프로젝트 클론
   \`\`\`powershell
   git clone <repository-url>
   cd $ProjectName
   \`\`\`
2. 환경 초기화
   \`\`\`powershell
   ./Dev_Env/ClI/Scripts/initialize.ps1
   \`\`\`
## 2. 기본 작업 흐름
### 2.1 새 작업 시작
1. 로깅 시스템 초기화
2. 작업 컨텍스트 설정
3. 필요한 디렉토리 생성
### 2.2 작업 진행
1. 변경사항 기록
2. 상태 확인
3. 문제 발생 시 추적 관리
### 2.3 작업 완료
1. 상태 보고서 생성
2. 변경사항 커밋
3. 문서 업데이트
## 3. 모범 사례
### 3.1 디렉토리 구성
- 각 서비스는 독립적으로 구성
- 공통 코드는 lib 디렉토리에 배치
- 설정 파일은 config 디렉토리에 중앙화
### 3.2 로깅 관리
- 적절한 로그 레벨 사용
- 문제 추적 ID 활용
- 정기적인 로그 검토
### 3.3 문제 해결
1. 문제 발견 시 즉시 추적 시작
2. 상세한 로그 기록 유지
3. 해결 과정 문서화
## 4. 주의사항
- 직접적인 파일 수정 대신 제공된 함수 사용
- 중요 파일 수정 전 백업 확인
- 로그 파일 정기적 관리
"@ | Out-File -FilePath $userGuide -Encoding UTF8
        Write-DCECLog -Level INFO -Message "프로젝트 매뉴얼 생성 완료" -Category "문서"
        return @{
            StructureManual = $structureManual
            CommandManual = $commandManual
            UserGuide = $userGuide
        }
    }
    catch {
        Write-DCECLog -Level ERROR -Message "매뉴얼 생성 실패" -Result $_.Exception.Message -Category "문서"
        throw
    }
}
# Export-ModuleMember에 DCEC 네임스페이스 함수들 추가
Export-ModuleMember -Function Initialize-DCECWorkContext, Initialize-DCECDirectoryStructure,
    Test-DCECDirectoryStructure, Get-DCECDirectoryStatus, Backup-DCECFile, New-DCECProjectManual,
    Export-DCECMarkdownReport, Export-DCECJsonReport, Add-DCECDirectoryChange
