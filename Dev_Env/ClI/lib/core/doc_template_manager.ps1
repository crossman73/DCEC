# 서비스 문서 템플릿 모듈
function New-ServiceDocumentation {
    param(
        [string]$Service,
        [string]$BaseDir = "/mnt/d/Dev/DCEC/Dev_Env",
        [hashtable]$Config,
        [string]$LogType
    )
    # README.md 생성
    $readmeContent = @"
# $Service
## 개요
${Config.Description}
## 디렉토리 구조
- config/: 설정 파일
- bin/: 실행 파일
- docs/: 문서
- logs/: 로그
## 환경 변수
환경 변수는 다음 위치에서 관리됩니다:
- $BaseDir/Env/Services/$Service/
  - api.env: API 관련 환경 변수
  - config.env: 설정 관련 환경 변수
## 로그
로그는 다음 위치에서 관리됩니다:
- $BaseDir/Logs/Services/$Service/
## 문서
상세 문서는 다음 위치에서 관리됩니다:
- $BaseDir/Docs/Services/$Service/
## 설치 및 설정
${Config.Setup}
## 사용법
${Config.Usage}
"@
    New-ServiceDoc -Service $Service -DocType "README" -Content $readmeContent -BaseDir $BaseDir -LogType $LogType
    # ARCHITECTURE.md 생성
    $archContent = @"
# $Service 아키텍처
## 컴포넌트
${Config.Components}
## 데이터 흐름
${Config.DataFlow}
## 통합 포인트
${Config.IntegrationPoints}
## 보안
${Config.Security}
"@
    New-ServiceDoc -Service $Service -DocType "ARCHITECTURE" -Content $archContent -BaseDir $BaseDir -LogType $LogType
}
Export-ModuleMember -Function New-ServiceDocumentation
