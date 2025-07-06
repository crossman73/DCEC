# 프로젝트 템플릿 사용 가이드

## 개요
이 디렉토리에는 다양한 프로젝트 유형에 대한 재사용 가능한 템플릿이 포함되어 있습니다.

## 기본 템플릿 (default_template)

기본 템플릿은 다음과 같은 구조를 제공합니다:
- 표준화된 디렉토리 구조
- 로깅 및 문제 추적 시스템
- 환경 설정 관리
- 문서 템플릿

### 사용 방법

1. 템플릿 복사:
   ```powershell
   Copy-Item -Path ".\default_template\*" -Destination "새프로젝트경로" -Recurse
   ```

2. 프로젝트 초기화:
   ```powershell
   cd "새프로젝트경로"
   .\init.ps1 -ProjectName "프로젝트이름" -Description "프로젝트 설명" -LogLevel "INFO"
   ```

### 디렉토리 구조
- src/: 소스 코드
- docs/: 문서
- tests/: 테스트
- logs/: 로그 파일
- config/: 설정 파일

### 설정 파일
project_config.json에서 다음을 설정할 수 있습니다:
- 필요한 모듈
- 기본 디렉토리 구조
- 기본 파일 템플릿
- 설정 프롬프트

## 새 템플릿 추가
1. default_template을 복사하여 새 템플릿 디렉토리 생성
2. project_config.json 수정하여 필요한 구조 정의
3. init.ps1 스크립트 수정하여 특화된 초기화 로직 추가
4. readme_template.md 업데이트하여 템플릿 사용법 문서화
