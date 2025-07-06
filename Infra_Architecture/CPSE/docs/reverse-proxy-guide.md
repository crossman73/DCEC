# 시놀로지 NAS 리버스 프록시 서브도메인 관리 가이드

## 🌐 개요

시놀로지 NAS의 리버스 프록시 기능을 활용하여 `crossman.synology.me` 도메인의 서브도메인을 자동으로 관리하는 통합 시스템입니다.

## 📋 지원 서비스

| 서비스 | 서브도메인 | 외부포트 | 내부포트 | 설명 |
|--------|------------|----------|----------|------|
| n8n | n8n.crossman.synology.me | 31001 | 5678 | 워크플로우 자동화 |
| mcp | mcp.crossman.synology.me | 31002 | 31002 | 모델 컨텍스트 프로토콜 |
| uptime | uptime.crossman.synology.me | 31003 | 31003 | 모니터링 서비스 |
| code | code.crossman.synology.me | 8484 | 8484 | VSCode 웹 환경 |
| gitea | git.crossman.synology.me | 3000 | 3000 | Git 저장소 |
| dsm | dsm.crossman.synology.me | 5001 | 5001 | NAS 관리 패널 |

## 🚀 사용법

### 1. 대화형 모드 (권장)

```bash
# 통합 관리 시스템 실행
./subdomain-manager.sh
```

대화형 메뉴에서 다음 기능을 사용할 수 있습니다:
- 기존 리버스 프록시 규칙 조회
- 특정 서비스 서브도메인 추가
- 모든 서브도메인 자동 설정
- 서브도메인 접속 상태 확인
- 리버스 프록시 규칙 삭제
- 서비스 목록 보기
- 네트워크 환경 재확인

### 2. 직접 명령 실행

```bash
# 네트워크 및 DSM 연결 확인
./subdomain-manager.sh check

# 기존 규칙 조회
./subdomain-manager.sh list

# 특정 서비스 추가
./subdomain-manager.sh add n8n

# 모든 서브도메인 설정
./subdomain-manager.sh setup-all

# 접속 상태 확인
./subdomain-manager.sh status

# 규칙 삭제
./subdomain-manager.sh delete 1
```

### 3. Windows PowerShell에서 사용

```powershell
# 특정 서비스 추가
.\reverse-proxy-manager.ps1 -Command add -Parameter n8n

# 모든 서브도메인 설정
.\reverse-proxy-manager.ps1 -Command setup-all

# 규칙 조회
.\reverse-proxy-manager.ps1 -Command list

# 상태 확인
.\reverse-proxy-manager.ps1 -Command status
```

## 🔧 환경 설정

### 환경변수

다음 환경변수를 설정하여 기본값을 변경할 수 있습니다:

```bash
export DSM_HOST="192.168.0.5"      # DSM 호스트 주소
export DSM_PORT="5001"             # DSM 포트 번호
export DSM_USER="crossman"         # DSM 사용자명
export DSM_PASS="your_password"    # DSM 비밀번호 (선택사항)
```

### 네트워크 요구사항

1. **내부 네트워크 (192.168.0.x)**: 직접 접속 가능
2. **외부 네트워크**: OpenVPN 연결 필수

```bash
# 네트워크 환경 확인
./network-check.sh check

# OpenVPN 연결 가이드
./network-check.sh vpn
```

## 🔒 보안 고려사항

### SSL/TLS 설정

모든 서브도메인은 HTTPS(포트 443)를 통해 접속하도록 설정됩니다:
- 소스: `https://서브도메인:443`
- 대상: `http://localhost:내부포트`

### 방화벽 설정

DSM에서 다음 포트들이 열려있어야 합니다:
- 5001 (HTTPS DSM 접속)
- 31001, 31002, 31003 (외부 서비스 포트)
- 8484, 3000 (코드서버, Git)

### 접근 제어

- VPN을 통한 내부 네트워크 접근 권장
- 외부 직접 접속은 보안상 권장하지 않음
- 각 서비스별 개별 인증 설정 권장

## 🛠️ 트러블슈팅

### 1. DSM 로그인 실패

```bash
# DSM 연결 상태 확인
curl -k https://192.168.0.5:5001

# 사용자 계정 및 권한 확인
# DSM > 제어판 > 사용자 계정에서 관리자 권한 확인
```

### 2. 서브도메인 접속 불가

```bash
# 내부 서비스 동작 확인
curl http://localhost:5678  # n8n 예시

# DNS 설정 확인
nslookup n8n.crossman.synology.me

# 리버스 프록시 규칙 확인
./subdomain-manager.sh list
```

### 3. 네트워크 연결 문제

```bash
# 네트워크 환경 재확인
./network-check.sh check

# OpenVPN 연결 확인
ip link show | grep tun

# NAS 연결 테스트
ping 192.168.0.5
```

### 4. API 호출 실패

- DSM 관리자 권한 확인
- API 제한 설정 확인 (DSM > 제어판 > 보안 > 계정)
- 세션 타임아웃 확인

## 📁 파일 구조

```
CPSE/
├── subdomain-manager.sh           # 통합 관리 스크립트
├── reverse-proxy-manager.sh       # 리버스 프록시 관리 (Bash)
├── reverse-proxy-manager.ps1      # 리버스 프록시 관리 (PowerShell)
├── network-check.sh               # 네트워크 환경 체크
├── nas-connect.sh                 # NAS 연결 도우미
└── docs/
    └── reverse-proxy-guide.md     # 이 문서
```

## 🔄 워크플로우

1. **환경 체크**: 네트워크 환경 및 NAS 연결 상태 확인
2. **DSM 로그인**: API 인증을 위한 세션 생성
3. **서비스 관리**: 리버스 프록시 규칙 추가/삭제/조회
4. **상태 확인**: 서브도메인 접속 및 내부 서비스 동작 확인
5. **로그아웃**: 보안을 위한 세션 종료

## 📚 참고 자료

- [Synology DSM API Guide](https://global.download.synology.com/download/Document/Software/DeveloperGuide/Package/FileStation/All/enu/Synology_File_Station_API_Guide.pdf)
- [DSM Reverse Proxy 설정](https://kb.synology.com/en-us/DSM/help/DSM/AdminCenter/connection_network_reverseproxy)
- [OpenVPN 설정 가이드](../../Vpn/README.md)

## 🆘 지원

문제 발생 시:
1. 로그 확인: DSM > 로그 센터
2. 네트워크 설정 확인: `./network-check.sh check`
3. 서비스 상태 확인: `./subdomain-manager.sh status`
4. GitHub Issues에 문제 보고
