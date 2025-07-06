# DCEC 실행 명령어 가이드

## 1. 환경 설정 명령어

### 1.1 초기 설정
```powershell
# 로깅 시스템 초기화
Initialize-Logging -Type "DCEC" -BaseDir "./Dev_Env/ClI"

# 작업 컨텍스트 초기화
Initialize-WorkContext -BasePath "./Dev_Env/ClI" -Description "작업설명"

# 디렉토리 구조 초기화
Initialize-DirectoryStructure -BasePath "./Dev_Env/ClI" -Force
```

### 1.2 상태 확인
```powershell
# 디렉토리 구조 검증
Test-DirectoryStructure -BasePath "./Dev_Env/ClI"

# 상태 보고서 생성
Get-DirectoryStatus -BasePath "./Dev_Env/ClI" -GenerateReport
```

## 2. 파일 및 디렉토리 관리

### 2.1 파일 백업
```powershell
# 기존 파일 백업
Backup-ExistingFile -FilePath "path/to/file.txt"
# 결과: file_old_20250706145600.txt
```

### 2.2 디렉토리 생성
```powershell
# 서비스 디렉토리 생성
New-ServiceDirectory -BasePath "./Dev_Env/ClI" -ServiceName "NewService"
```

## 3. 로깅 및 문제 해결

### 3.1 로그 작성
```powershell
# 정보 로그
Write-Log -Level INFO -Message "작업 시작" -Category "초기화"

# 경고 로그
Write-Log -Level WARNING -Message "주의 필요" -Category "검증"

# 오류 로그
Write-Log -Level ERROR -Message "오류 발생" -Category "실행" -Result "실패"

# 디버그 로그
Write-Log -Level DEBUG -Message "상세 정보" -Category "처리"
```

### 3.2 문제 추적
```powershell
# 문제 추적 시작
Start-ProblemTracking -ProblemId "PROB-001" -Description "문제 설명"

# 상태 업데이트
Update-ProblemStatus -ProblemId "PROB-001" -Status "진행중"

# 문제 해결
Update-ProblemStatus -ProblemId "PROB-001" -Status "해결됨" -Resolution "해결 방법"
```

## 4. 보고서 생성

### 4.1 HTML 보고서
```powershell
Get-DirectoryStatus -BasePath "./Dev_Env/ClI" -GenerateReport
# docs/directory_report.html 생성
```

### 4.2 Markdown 요약
```powershell
New-ProjectManual -BasePath "./Dev_Env/ClI" -ProjectName "DCEC"
# docs/manual/*.md 파일들 생성
```
