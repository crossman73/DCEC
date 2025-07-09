# DCEC 종속/서브 프로젝트 구조 분석 및 네이밍 규칙 재정립

## 🏗️ DCEC 프로젝트 전체 구조

```
DCEC/ (메인 프로젝트)
├── Dev_Env/                    # 개발환경 서브프로젝트
│   ├── CLI/
│   ├── Docker/
│   ├── Fonts/
│   ├── IDE/
│   ├── Powershell/
│   └── Python/
├── Infra_Architecture/         # 인프라 아키텍처 서브프로젝트
│   ├── CPSE/                  # 핵심 플랫폼 서비스 환경
│   ├── NAS_Synology_DS920_Plus/
│   ├── Router_ASUS_RT-AX88u/
│   └── Vpn/
├── Governance/                 # 거버넌스 서브프로젝트
└── [공통 도구들]
    ├── Project-Continuity-Manager.ps1
    ├── DCEC-SSH-Manager.ps1
    └── etc...
```

## ⚠️ 기존 접근법의 문제점

### 1. 서브프로젝트 무시
- Dev_Env, Infra_Architecture, Governance 각각의 독립성 미고려
- 각 서브프로젝트별 고유한 네이밍 요구사항 무시

### 2. 계층구조 미반영
- DCEC → 서브프로젝트 → 컴포넌트 계층 구조 무시
- 단순한 DCEC 접두사로만 처리

### 3. 종속관계 미고려
- 서브프로젝트 간 의존성 관계 미분석
- 공통 모듈 vs 개별 모듈 구분 없음

## 🎯 개선된 네이밍 규칙

### 1. 계층적 네이밍 구조
```
{MainProject}_{SubProject}_{Component}_{Function}
예: DCEC_InfraArch_CPSE_DockerManager
```

### 2. 서브프로젝트별 접두사
```
DCEC_DevEnv_*     # 개발환경 관련
DCEC_InfraArch_*  # 인프라 아키텍처 관련  
DCEC_Governance_* # 거버넌스 관련
DCEC_Common_*     # 공통 도구
```

### 3. 함수 네이밍 패턴
```
{Verb}-DCEC{SubProject}{Component}{Noun}
예: 
- Get-DCECInfraArchCPSEStatus
- Set-DCECDevEnvDockerConfig
- Save-DCECCommonProjectState
```

### 4. 파일 네이밍 패턴
```
DCEC-{SubProject}-{Component}-{Purpose}.{ext}
예:
- DCEC-InfraArch-CPSE-Manager.ps1
- DCEC-DevEnv-Docker-Config.json
- DCEC-Common-Project-Continuity.ps1
```

## 📋 현재 파일들의 올바른 분류

### 공통 도구 (DCEC_Common)
- Project-Continuity-Manager.ps1 → DCEC-Common-Project-Continuity.ps1
- DCEC-SSH-Manager.ps1 → DCEC-Common-SSH-Manager.ps1

### 인프라 아키텍처 (DCEC_InfraArch)
- SSH 키 관리 → DCEC-InfraArch-SSH-KeyManager.ps1
- NAS 관리 → DCEC-InfraArch-NAS-Manager.ps1
- CPSE 관련 → DCEC-InfraArch-CPSE-*.ps1

### 개발환경 (DCEC_DevEnv)
- Docker 관련 → DCEC-DevEnv-Docker-*.ps1
- IDE 설정 → DCEC-DevEnv-IDE-Config.ps1

## 🔄 마이그레이션 계획

### 1단계: 서브프로젝트별 재분류
- 현재 파일들을 올바른 서브프로젝트로 이동
- 종속관계 명확화

### 2단계: 네이밍 규칙 적용
- 계층적 구조 반영
- 서브프로젝트별 접두사 적용

### 3단계: 참조 관계 업데이트
- 스크립트 간 호출 경로 수정
- 문서 링크 업데이트

## 🤝 사과 및 개선 약속
- 서브프로젝트 구조를 무시한 점 사과드립니다
- 앞으로는 전체 구조를 먼저 분석한 후 작업하겠습니다
- 각 서브프로젝트의 독립성과 종속관계를 고려하겠습니다

---
**분석일**: 2025-07-07  
**작성자**: DCEC Development Team  
**상태**: 구조 재분석 및 개선방안 수립 완료
