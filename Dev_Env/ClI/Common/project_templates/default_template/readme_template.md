# ${projectName}

## 개요
${description}

## 설치 방법

1. 필수 조건:
   - PowerShell 5.1 이상
   - 필요한 PowerShell 모듈

2. 설치:
   ```powershell
   .\init.ps1 -ProjectName "프로젝트이름" -Description "프로젝트 설명"
   ```

## 프로젝트 구조

```
project_root/
├── src/           # 소스 코드
├── docs/          # 문서
├── tests/         # 테스트
├── logs/          # 로그 파일
└── config/        # 설정 파일
    └── settings.json
```

## 설정

`config/settings.json` 파일에서 다음 설정을 변경할 수 있습니다:

- `environment`: 환경 (development/production)
- `logLevel`: 로깅 레벨 (DEBUG/INFO/WARN/ERROR)
- `enableChatLogging`: 채팅 로깅 활성화
- `enableProblemTracking`: 문제 추적 활성화

## 로깅

로그는 `logs` 디렉토리에 저장되며, 다음과 같은 형식으로 생성됩니다:
- `YYYYMMDD_session_[세션ID].log`: 일반 로그
- `YYYYMMDD_chat_[세션ID].log`: 채팅 로그
- `YYYYMMDD_problems_[세션ID].json`: 문제 추적
