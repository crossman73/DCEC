# CPSE 프로젝트 - 스크립트 사용 가이드

## 개요

CPSE (NAS-SubDomain-Manager) 프로젝트는 Windows/PowerShell과 Linux/Bash 환경을 모두 지원하는 통합 관리 시스템입니다.

## 스크립트 구조

```
scripts/
├── setup/                    # 초기 설정 및 환경 구성
│   ├── environment.sh        # 리눅스/NAS 환경 설정
│   ├── path-sync.ps1         # Windows 경로 동기화
│   └── env-manager.ps1       # 환경 정보 관리
├── services/                 # 서비스 관리
│   └── mcp-server.sh         # MCP 서버 관리
├── security/                 # 보안 및 인증
│   ├── approval.sh           # 승인 시스템
│   └── secrets-manager.ps1   # 보안 정보 관리
└── maintenance/              # 유지보수 및 모니터링
    ├── backup.sh             # 백업 관리
    ├── cleanup.sh            # 시스템 정리
    ├── restore.sh            # 복원 관리
    ├── status.sh             # 상태 확인
    ├── update.sh             # 업데이트 관리
    └── network-diagnostics.ps1 # 네트워크 진단
```

## Windows 환경에서 사용법

### 1. 경로 동기화 관리 (path-sync.ps1)

NAS와 로컬 환경 간 프로젝트 파일 동기화:

```powershell
# NAS 경로 자동 감지
.\setup\path-sync.ps1 -action detect

# 현재 경로 설정
.\setup\path-sync.ps1 -action set -root "C:\dev\CPSE"

# NAS↔로컬 동기화
.\setup\path-sync.ps1 -action sync

# 동기화 상태 확인
.\setup\path-sync.ps1 -action status

# 설정 정보 보기
.\setup\path-sync.ps1 -action view

# Dry Run (실제 복사 없이 테스트)
.\setup\path-sync.ps1 -action sync -dryRun
```

### 2. 환경 정보 관리 (env-manager.ps1)

NAS 및 서비스 환경 정보 관리:

```powershell
# 전체 환경 정보 보기
.\setup\env-manager.ps1 -action view

# 특정 서비스 정보 보기
.\setup\env-manager.ps1 -action view -service n8n

# NAS 정보 업데이트
.\setup\env-manager.ps1 -action update -key hostname -value crossman.synology.me

# 서비스 정보 업데이트
.\setup\env-manager.ps1 -action update -service mcp -key port -value 31002

# 환경 정보 내보내기
.\setup\env-manager.ps1 -action export

# 유효성 검사
.\setup\env-manager.ps1 -action validate
```

### 3. 보안 정보 관리 (secrets-manager.ps1)

서비스별 API 키, 패스워드 등 보안 정보 관리:

```powershell
# API 키 추가
.\security\secrets-manager.ps1 -action add -service mcp -key api_key -value "your-api-key"

# 패스워드 업데이트 (암호화)
.\security\secrets-manager.ps1 -action update -service n8n -key admin_password -value "new-password" -encrypt

# 임의 보안 키 생성
.\security\secrets-manager.ps1 -action generate -service gitea -key secret_key

# 서비스별 보안 정보 보기 (마스킹됨)
.\security\secrets-manager.ps1 -action view -service uptime_kuma

# 보안 정보 백업
.\security\secrets-manager.ps1 -action backup

# 보안 정보 삭제
.\security\secrets-manager.ps1 -action delete -service old_service -key old_key
```

### 4. 네트워크 진단 (network-diagnostics.ps1)

VPN 및 서비스 연결 상태 점검:

```powershell
# 기본 연결 테스트
.\maintenance\network-diagnostics.ps1 -action check

# 상세 정보와 함께 테스트
.\maintenance\network-diagnostics.ps1 -action check -verbose

# 지속적 모니터링 (60초 간격)
.\maintenance\network-diagnostics.ps1 -action monitor

# 사용자 정의 간격으로 모니터링
.\maintenance\network-diagnostics.ps1 -action monitor -interval 30

# 진단 보고서 생성
.\maintenance\network-diagnostics.ps1 -action report

# 네트워크 문제 자동 복구 시도
.\maintenance\network-diagnostics.ps1 -action fix

# 로그 파일 지정
.\maintenance\network-diagnostics.ps1 -action check -logFile "C:\temp\network.log"
```

## Linux/NAS 환경에서 사용법

### 메인 스크립트 (main.sh)

```bash
# 전체 시스템 설치
./main.sh install

# 서비스 관리
./main.sh start      # 모든 서비스 시작
./main.sh stop       # 모든 서비스 중지
./main.sh restart    # 모든 서비스 재시작
./main.sh status     # 서비스 상태 확인

# 백업 및 복원
./main.sh backup     # 시스템 백업
./main.sh restore    # 백업에서 복원

# 시스템 관리
./main.sh update     # 시스템 업데이트
./main.sh clean      # 시스템 정리
./main.sh health     # 헬스체크 실행
```

## 통합 워크플로우

### 개발 환경 설정

1. **Windows에서 초기 설정**:
   ```powershell
   # 환경 정보 확인 및 설정
   .\setup\env-manager.ps1 -action validate
   
   # NAS 경로 감지
   .\setup\path-sync.ps1 -action detect
   
   # 네트워크 연결 확인
   .\maintenance\network-diagnostics.ps1 -action check
   ```

2. **NAS로 동기화**:
   ```powershell
   # 로컬에서 NAS로 동기화
   .\setup\path-sync.ps1 -action sync
   ```

3. **NAS에서 배포**:
   ```bash
   # NAS에서 서비스 시작
   ./main.sh start
   
   # 상태 확인
   ./main.sh status
   ```

### 보안 관리 워크플로우

1. **초기 보안 설정**:
   ```powershell
   # 모든 서비스에 대한 임의 키 생성
   .\security\secrets-manager.ps1 -action generate -service n8n -key encryption_key
   .\security\secrets-manager.ps1 -action generate -service mcp -key api_key
   .\security\secrets-manager.ps1 -action generate -service gitea -key secret_key
   ```

2. **백업**:
   ```powershell
   .\security\secrets-manager.ps1 -action backup
   ```

### 모니터링 워크플로우

1. **일일 점검**:
   ```powershell
   .\maintenance\network-diagnostics.ps1 -action report
   ```

2. **문제 발생시**:
   ```powershell
   .\maintenance\network-diagnostics.ps1 -action fix
   ```

## 설정 파일

### config/path-config.json
경로 동기화 설정 및 환경별 도구 설정

### config/env-info.json  
NAS 및 서비스 환경 정보

### config/user-secrets.json
서비스별 보안 정보 (암호화 권장)

## 보안 고려사항

1. **보안 정보 관리**:
   - `user-secrets.json` 파일은 적절한 권한으로 보호
   - 중요한 키는 `-encrypt` 옵션 사용
   - 정기적인 백업 수행

2. **네트워크 보안**:
   - VPN을 통한 접근 권장
   - 방화벽 규칙 적용
   - 정기적인 연결 상태 점검

3. **동기화 보안**:
   - 민감한 파일은 제외 패턴에 추가
   - DRY RUN으로 사전 확인
   - 동기화 로그 모니터링

## 문제 해결

### 일반적인 문제들

1. **경로 접근 오류**:
   ```powershell
   # 네트워크 드라이브 연결 확인
   .\setup\path-sync.ps1 -action detect
   ```

2. **서비스 연결 실패**:
   ```powershell
   # 네트워크 진단 실행
   .\maintenance\network-diagnostics.ps1 -action check -verbose
   ```

3. **설정 파일 오류**:
   ```powershell
   # 환경 설정 유효성 검사
   .\setup\env-manager.ps1 -action validate
   ```
