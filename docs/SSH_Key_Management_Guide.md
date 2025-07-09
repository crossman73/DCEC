# DCEC SSH Key Management System

## 📋 개요
DCEC 프로젝트 내에서 SSH 키와 접속 설정을 중앙 집중식으로 관리하는 시스템입니다.

## 📁 폴더 구조
```
c:\dev\DCEC\
├── keys\
│   ├── ssh\
│   │   ├── dcec_nas_id_rsa      # NAS 접속용 private key
│   │   └── dcec_nas_id_rsa.pub  # NAS 접속용 public key
│   └── config\
│       ├── ssh_config           # DCEC 전용 SSH 설정
│       └── known_hosts          # 알려진 호스트 목록
├── DCEC-SSH-Manager.ps1         # SSH 관리 스크립트
└── docs\                        # 문서들
```

## 🔑 SSH 키 정보
- **생성일**: 2025-07-07
- **키 타입**: RSA
- **대상 NAS**: 192.168.0.5:22022
- **사용자**: crossman

## 🛠️ 사용 방법

### 1. SSH 키 설정
```powershell
.\DCEC-SSH-Manager.ps1 -Action SetupKeys
```

### 2. NAS 접속
```powershell
# 간단한 접속
.\DCEC-SSH-Manager.ps1 -Action ConnectNAS

# 특정 호스트 별칭으로 접속
.\DCEC-SSH-Manager.ps1 -Action ConnectNAS -Host synology-nas
```

### 3. 연결 테스트
```powershell
.\DCEC-SSH-Manager.ps1 -Action TestConnection
```

### 4. 설정 확인
```powershell
.\DCEC-SSH-Manager.ps1 -Action ShowConfig
```

## 🌐 호스트 별칭
SSH 설정에 정의된 호스트 별칭들:

- **dcec-nas**: 기본 NAS 접속
- **synology-nas**: 시놀로지 NAS 접속

## 🔧 수동 SSH 접속
DCEC 설정을 사용한 수동 접속:
```powershell
ssh -F "c:\dev\DCEC\keys\config\ssh_config" dcec-nas
```

## 📝 다른 프로젝트에서 사용
다른 DCEC 서브프로젝트에서 이 키를 사용할 때:

```powershell
# 환경 변수 설정
$env:DCEC_SSH_KEY = "c:\dev\DCEC\keys\ssh\dcec_nas_id_rsa"
$env:DCEC_SSH_CONFIG = "c:\dev\DCEC\keys\config\ssh_config"

# 사용 예시
ssh -F $env:DCEC_SSH_CONFIG dcec-nas
```

## 🔒 보안 고려사항
1. **키 파일 권한**: Windows에서 가능한 한 제한적 권한 설정
2. **백업**: 키 파일을 안전한 위치에 별도 백업
3. **접근 제어**: DCEC 프로젝트 폴더에 대한 접근 권한 관리
4. **버전 관리**: 키 파일은 Git에 포함하지 않음 (.gitignore 적용)

## 🚀 자동화 활용
다른 스크립트에서 NAS 작업 자동화:

```powershell
# 예시: NAS에서 Docker 상태 확인
function Get-NASDockerStatus {
    ssh -F "c:\dev\DCEC\keys\config\ssh_config" dcec-nas "docker ps"
}

# 예시: NAS에 파일 업로드
function Deploy-ToNAS {
    param([string]$LocalPath, [string]$RemotePath)
    scp -F "c:\dev\DCEC\keys\config\ssh_config" $LocalPath dcec-nas:$RemotePath
}
```

## 📋 트러블슈팅
1. **권한 오류**: 키 파일 권한 확인
2. **연결 실패**: SSH 설정 및 네트워크 상태 확인
3. **키 인식 실패**: IdentitiesOnly=yes 설정 확인

---
**생성일**: 2025-07-07  
**작성자**: DCEC Development Team  
**버전**: 1.0
