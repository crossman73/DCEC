# DCEC (Development & Cloud Environment Configuration)

개발 환경 및 클라우드 인프라 설정을 위한 통합 프로젝트입니다.

## 📁 프로젝트 구조

```
DCEC/
├── Dev_Env/                    # 개발 환경 설정
│   ├── ClI/                   # CLI 도구 및 가이드
│   ├── Fonts/                 # 개발용 폰트
│   ├── IDE/VScode/           # VSCode 설정 및 스크립트
│   ├── MCP/                  # Model Context Protocol 설정
│   ├── n8n/                  # n8n 워크플로우 자동화
│   └── Powershell/           # PowerShell 환경 설정
├── Governance/                # 프로젝트 거버넌스 및 프로토콜
├── Infra_Architecture/        # 인프라 아키텍처
│   ├── NAS_Synology_DS920_Plus/ # 시놀로지 NAS 설정
│   ├── Router_ASUS_RT-AX88u/    # ASUS 공유기 설정
│   ├── Sub_Domain/              # 서브도메인 관리 (기존)
│   ├── CPSE/                    # 통합 서브도메인 관리 시스템 ✨
│   └── Vpn/                     # VPN 설정
└── README.md                  # 이 파일
```

## 🎯 주요 프로젝트

### CPSE (Crossman Project SubDomain Environment)
시놀로지 NAS 기반 서브도메인 관리 시스템

**위치**: `Infra_Architecture/CPSE/`

**주요 기능**:
- 🔧 시놀로지 DSM CLI를 통한 서브도메인 자동 설정
- 🔒 OpenVPN 기반 보안 접속 환경
- 🐳 Docker 컨테이너 서비스 관리
- 📝 PowerShell/Bash 통합 스크립트 시스템
- 🛡️ 승인 시스템 및 백업/복원 자동화

**네트워크 보안 정책**:
- 내부 네트워크 (ASUS RT-AX88u): 직접 접속 가능
- 외부 접속: OpenVPN을 통한 내부 IP 접속만 허용

**서비스 목록**:
| 서비스 | 서브도메인 | 포트 | 용도 |
|--------|-----------|------|-----|
| n8n | n8n.crossman.synology.me | 31001 | 워크플로우 자동화 |
| MCP | mcp.crossman.synology.me | 31002 | 모델 컨텍스트 프로토콜 |
| Uptime Kuma | uptime.crossman.synology.me | 31003 | 모니터링 |
| Code Server | code.crossman.synology.me | 8484 | VSCode 웹 환경 |
| Gitea | git.crossman.synology.me | 3000 | Git 저장소 |
| DSM | dsm.crossman.synology.me | 5001 | NAS 관리 |

## 🚀 빠른 시작

### CPSE 서브도메인 관리
```bash
cd Infra_Architecture/CPSE

# NAS 연결 테스트
./nas-connect.sh test

# 서브도메인 설정
./dsm-subdomain-cli.sh setup mcp 31002 "MCP Server"
```

### PowerShell 환경 (Windows)
```powershell
cd Infra_Architecture\CPSE

# 실행 권한 설정
.\scripts\setup-permissions.ps1

# 통합 스크립트 실행
.\scripts\run-script.ps1 -Category setup -Script path-sync -Action detect
```

## 🌐 네트워크 구성

### 하드웨어
- **NAS**: 시놀로지 DS920+ (192.168.0.5:22022)
- **공유기**: ASUS RT-AX88u
- **도메인**: crossman.synology.me

### 보안 정책
- **내부 접속**: 공유기 할당 IP (192.168.0.x)에서 직접 접속
- **외부 접속**: OpenVPN 연결 → 내부 IP로 접속
- **SSH 포트**: 22022 (기본 22번 포트 변경)
- **사용자**: crossman

## 📚 상세 문서

각 프로젝트별 상세한 설명은 해당 디렉토리의 README.md를 참조하세요:

- [CPSE 서브도메인 관리](Infra_Architecture/CPSE/README.md)
- [VSCode 개발환경](Dev_Env/IDE/VScode/README.md)
- [MCP 서버 설정](Dev_Env/MCP/README.md)

## 🔧 개발 환경

- **OS**: Windows 11
- **Shell**: PowerShell 7.x
- **Git**: Git for Windows
- **IDE**: Visual Studio Code
- **Container**: Docker Desktop

## 📈 프로젝트 현황

- ✅ CPSE 서브도메인 관리 시스템 완성
- ✅ PowerShell/Bash 스크립트 통합
- ✅ 보안 정책 및 접속 환경 구성
- 🔄 실제 NAS 환경 테스트 진행 중
- 📋 추가 서비스 확장 계획 중

## 🤝 기여

이 프로젝트는 개인 인프라 관리를 위한 것이지만, 유용한 스크립트나 설정이 있다면 이슈나 PR로 공유해주세요!

## 📄 라이선스

MIT License - 자유롭게 사용하세요!

---

**⚡ 빠른 접속**: `ssh -p 22022 crossman@192.168.0.5` (OpenVPN 연결 후)
