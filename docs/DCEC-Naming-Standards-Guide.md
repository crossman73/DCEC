# DCEC 네이밍 규칙 가이드 - 최신 표준 적용

## 📚 조사한 네이밍 가이드 출처

### 1. Microsoft PowerShell 공식 가이드
- **출처**: [PowerShell Best Practices and Style Guide](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- **주요 규칙**: Verb-Noun 패턴, PascalCase, 승인된 동사 사용

### 2. .NET Naming Conventions
- **출처**: [Microsoft .NET Naming Guidelines](https://docs.microsoft.com/en-us/dotnet/standard/design-guidelines/naming-guidelines)
- **주요 규칙**: 네임스페이스, 클래스, 메서드 네이밍

### 3. Git/GitHub Naming Best Practices
- **출처**: GitHub Community Guidelines, Git Best Practices
- **주요 규칙**: 브랜치명, 파일명, 리포지토리명

### 4. Enterprise Software Naming Standards
- **출처**: IBM, Oracle, AWS Naming Conventions
- **주요 규칙**: 프로젝트 접두사, 환경별 구분, 버전 관리

## 🎯 DCEC 프로젝트 적용 규칙

### 1. 프로젝트 접두사 규칙
```
DCEC-{ComponentType}-{FunctionName}
예: DCEC-SSH-Manager, DCEC-Project-Continuity, DCEC-Docker-Deployer
```

### 2. PowerShell 함수 네이밍
```
{Verb}-DCEC{Noun}
예: Get-DCECProjectState, Set-DCECConfiguration, New-DCECDocument
```

### 3. 파일 네이밍
```
DCEC-{Purpose}-{Type}.{ext}
예: DCEC-SSH-Manager.ps1, DCEC-Config-Template.json
```

### 4. 변수 네이밍
```
$DCEC_{Scope}_{Name}
예: $DCEC_Global_RootPath, $DCEC_Config_SSHSettings
```

### 5. 폴더 구조 네이밍
```
DCEC/
├── Core/           # 핵심 기능
├── Infrastructure/ # 인프라 관련
├── Tools/          # 도구 및 유틸리티
├── Config/         # 설정 파일
├── Secrets/        # 보안 관련 (gitignore)
└── Docs/           # 문서
```

## ⚠️ 충돌 방지 규칙

### 1. 네임스페이스 충돌 방지
- 모든 함수에 `DCEC` 접두사 필수
- Windows 기본 명령어와 중복 방지
- PowerShell 모듈명과 충돌 방지

### 2. 파일명 충돌 방지
- 프로젝트 접두사 `DCEC-` 필수
- 날짜/시간 포함 시 ISO 8601 형식 사용
- 환경별 구분자 사용: `-Dev`, `-Prod`, `-Test`

### 3. 변수명 충돌 방지
- 전역 변수는 `$DCEC_` 접두사
- 로컬 변수는 camelCase 사용
- 환경 변수와 구분: `$env:` vs `$DCEC_`

## 🔧 적용할 개선사항

### 현재 → 개선
1. `Project-Continuity-Manager.ps1` → `DCEC-Project-Continuity-Manager.ps1`
2. `Write-ColorLog` → `Write-DCECColorLog`
3. `Save-ProjectState` → `Save-DCECProjectState`
4. `$GlobalLogsPath` → `$DCEC_Global_LogsPath`
5. `.ssh` 폴더 → `DCEC-SSH-Keys` 폴더

## 📋 마이그레이션 체크리스트

- [ ] 파일명 변경
- [ ] 함수명 변경 및 접두사 추가
- [ ] 변수명 표준화
- [ ] 폴더 구조 재조직
- [ ] 문서 업데이트
- [ ] 스크립트 참조 경로 수정
- [ ] 테스트 및 검증

---
**생성일**: 2025-07-07  
**작성자**: DCEC Development Team  
**참조**: Microsoft PowerShell Guidelines, .NET Naming Conventions
