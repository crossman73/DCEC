# CPSE Scripts Directory

시놀로지 NAS 서브도메인 관리 시스템(CPSE)의 스크립트 모음입니다.

## 📁 디렉토리 구조

```
scripts/
├── setup/                 # 초기 설정 및 환경 구성
├── services/             # 서비스 관리 스크립트
├── security/            # 보안 관련 스크립트
├── maintenance/         # 유지보수 및 모니터링
├── path-config-guide.md # 경로 설정 가이드
└── README.md           # 이 파일
```

## 🔧 스크립트 분류

### Setup (초기 설정)
- **environment.sh** - Bash 기반 환경 설정 스크립트
- **path-sync.ps1** - Windows/NAS 간 경로 동기화 (PowerShell)
- **env-manager.ps1** - 환경 정보 관리 (PowerShell)

### Services (서비스 관리)
- **mcp-server.sh** - MCP 서버 관리 스크립트

### Security (보안)
- **approval.sh** - 승인 시스템 관리 (Bash)
- **secrets-manager.ps1** - 보안 정보 관리 (PowerShell)

### Maintenance (유지보수)
- **backup.sh** - 백업 관리 스크립트
- **restore.sh** - 복원 관리 스크립트
- **cleanup.sh** - 시스템 정리 스크립트
- **status.sh** - 시스템 상태 확인
- **update.sh** - 시스템 업데이트
- **network-diagnostics.ps1** - 네트워크 진단 (PowerShell)

## 🚀 사용법

### PowerShell 스크립트 실행 (Windows)

```powershell
# 경로 동기화
.\scripts\setup\path-sync.ps1 -action detect

# 환경 정보 확인
.\scripts\setup\env-manager.ps1 -action view

# 보안 정보 관리
.\scripts\security\secrets-manager.ps1 -action view

# 네트워크 진단
.\scripts\maintenance\network-diagnostics.ps1 -action check
```

### Bash 스크립트 실행 (NAS/Linux)

```bash
# 환경 설정
./scripts/setup/environment.sh

# 서비스 관리
./scripts/services/mcp-server.sh

# 백업 실행
./scripts/maintenance/backup.sh

# 시스템 상태 확인
./scripts/maintenance/status.sh
```

## 🔗 연동 구조

### Windows (개발 환경) ↔ NAS (운영 환경)

1. **Windows PowerShell 스크립트**
   - 로컬 개발 환경 관리
   - 설정 파일 동기화
   - 원격 진단 및 모니터링

2. **NAS Bash 스크립트**
   - 서비스 실제 운영
   - 시스템 백업/복원
   - 자동화된 유지보수

### 설정 파일 연동

- `config/path-config.json` - 경로 설정
- `config/env-info.json` - 환경 정보
- `config/user-secrets.json` - 보안 정보

### 로그 시스템

- `logs/` 디렉토리에 모든 스크립트 실행 로그 저장
- PowerShell과 Bash 스크립트 모두 통일된 로그 형식 사용

## 📋 체크리스트

### 스크립트 실행 전 확인사항
- [ ] 필요한 설정 파일이 `config/` 디렉토리에 존재
- [ ] PowerShell 실행 정책 설정 (`Set-ExecutionPolicy RemoteSigned`)
- [ ] NAS SSH 접근 권한 확보
- [ ] 로그 디렉토리 쓰기 권한 확인

### 정기 실행 권장 스크립트
- [ ] `network-diagnostics.ps1` - 주간 네트워크 상태 점검
- [ ] `backup.sh` - 일일 백업 (cron 설정)
- [ ] `status.sh` - 서비스 상태 모니터링
- [ ] `cleanup.sh` - 월간 시스템 정리

## 🛠️ 문제 해결

### PowerShell 스크립트 실행 오류
```powershell
# 실행 정책 확인
Get-ExecutionPolicy

# 실행 정책 설정
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 경로 오류 해결
- `path-config-guide.md` 파일 참조
- `path-sync.ps1 -action detect`로 자동 감지

### 네트워크 연결 문제
- VPN 연결 상태 확인
- `network-diagnostics.ps1 -action check`로 진단

## 📚 추가 문서

- [`path-config-guide.md`](path-config-guide.md) - 경로 설정 상세 가이드
- [`../config/README.md`](../config/README.md) - 설정 파일 가이드
- [`../README.md`](../README.md) - 프로젝트 전체 가이드
