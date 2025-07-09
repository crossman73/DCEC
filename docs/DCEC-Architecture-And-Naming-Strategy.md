# DCEC 프로젝트 아키텍처 및 확장 가능한 네이밍 규칙

## 🏗️ DCEC 프로젝트 계층 구조

```
DCEC/ (메인 프로젝트)
├── Dev_Env/                    # 개발환경 프로젝트 (현재 진행)
│   ├── CLI/
│   ├── Docker/
│   ├── Fonts/
│   ├── IDE/
│   ├── Powershell/
│   └── Python/
│
├── Infra_Architecture/         # 인프라 아키텍처 프로젝트 (현재 진행)
│   ├── CPSE/                  # crossman.synology.me 도메인 서비스
│   │   └── [도커 서비스들의 서브도메인]
│   ├── NAS_Synology_DS920_Plus/
│   ├── Router_ASUS_RT-AX88u/
│   └── Vpn/
│
├── Governance/                 # 거버넌스 프로젝트 (후순위)
│   └── [Dev_Env + Infra_Architecture 통합 후 진행]
│   └── [키 값, 설정, 운영 정보 관장]
│
└── Common/                     # 공통 도구 (모든 프로젝트에서 사용)
    ├── Project-Continuity-Manager.ps1
    ├── DCEC-SSH-Manager.ps1
    └── [기타 공통 유틸리티]
```

## 🎯 프로젝트 우선순위 및 단계

### Phase 1: 기반 환경 구축 (현재)
1. **Dev_Env** - 개발환경 설정
2. **Infra_Architecture** - 인프라 구축
   - SSH 키 관리 ✅ 진행 중
   - CPSE 도커 서비스 배포
   - NAS/네트워크 설정

### Phase 2: 통합 및 거버넌스 (향후)
3. **Governance** - 통합 관리
   - Dev_Env + Infra_Architecture 통합
   - 키 값 및 설정 중앙 관리
   - 운영 정보 거버넌스

## 🏷️ 확장 가능한 네이밍 규칙

### 1. 프로젝트 레벨 접두사
```powershell
# 현재 프로젝트
DCEC_DevEnv_*          # 개발환경 관련
DCEC_InfraArch_*       # 인프라 아키텍처 관련
DCEC_Common_*          # 공통 도구

# 향후 프로젝트
DCEC_Governance_*      # 거버넌스 관련
DCEC_{NewProject}_*    # 추가 프로젝트 확장 가능
```

### 2. 함수 네이밍 패턴
```powershell
# 공통 도구 (모든 프로젝트에서 사용)
{Verb}-DCECCommon{Function}
예: Save-DCECCommonProjectState, Write-DCECCommonColorLog

# 프로젝트별 전용 함수
{Verb}-DCEC{Project}{Component}{Function}
예: 
- Deploy-DCECInfraArchCPSEService
- Configure-DCECDevEnvDockerEnvironment
- Manage-DCECGovernanceKeyRepository (향후)
```

### 3. 파일 네이밍 패턴
```powershell
# 공통 도구
DCEC-Common-{Purpose}.{ext}
예: DCEC-Common-Project-Continuity.ps1

# 프로젝트별 도구
DCEC-{Project}-{Component}-{Purpose}.{ext}
예:
- DCEC-InfraArch-SSH-KeyManager.ps1
- DCEC-InfraArch-CPSE-ServiceDeployer.ps1
- DCEC-DevEnv-Docker-ConfigManager.ps1
- DCEC-Governance-Config-CentralManager.ps1 (향후)
```

### 4. 변수 네이밍 (확장성 고려)
```powershell
# 전역 공통 변수
$DCEC_Common_RootPath
$DCEC_Common_LogsPath
$DCEC_Common_DocsPath

# 프로젝트별 변수
$DCEC_InfraArch_SSHKeysPath
$DCEC_InfraArch_CPSEConfigPath
$DCEC_DevEnv_DockerPath
$DCEC_Governance_ConfigPath (향후)
```

## 🔄 현재 작업 우선순위 매핑

### 1. SSH 키 관리 (진행 중)
- 분류: `DCEC_InfraArch_SSH`
- 파일: `DCEC-InfraArch-SSH-KeyManager.ps1`
- 함수: `Set-DCECInfraArchSSHKeys`

### 2. CPSE 도커 서비스 (다음 단계)
- 분류: `DCEC_InfraArch_CPSE`
- 파일: `DCEC-InfraArch-CPSE-ServiceManager.ps1`
- 도메인: `crossman.synology.me` 서브도메인 관리

### 3. 프로젝트 연속성 관리 (공통)
- 분류: `DCEC_Common_ProjectContinuity`
- 현재 파일: `Project-Continuity-Manager.ps1`
- 개선명: `DCEC-Common-Project-Continuity.ps1`

## 📈 확장성 고려사항

### 새 프로젝트 추가 시
1. **네이밍 패턴 준수**: `DCEC_{NewProject}_*`
2. **공통 도구 재사용**: `DCEC_Common_*` 활용
3. **문서화 표준**: 동일한 구조 적용

### 거버넌스 프로젝트 시작 시
1. **통합 관리**: Dev_Env + Infra_Architecture 결과물 통합
2. **중앙집중식 설정**: 모든 키/설정 중앙 관리
3. **운영 정보 거버넌스**: 표준화된 운영 절차

## ✅ 적용 우선순위

1. **즉시 적용**: 공통 도구 네이밍 개선
2. **단계별 적용**: 현재 SSH 작업에 InfraArch 접두사 적용
3. **향후 준비**: Governance 프로젝트 네이밍 구조 예약

---
**수립일**: 2025-07-07  
**작성자**: DCEC Development Team  
**상태**: 확장 가능한 구조 수립 완료
