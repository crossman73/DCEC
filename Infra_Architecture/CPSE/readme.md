<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# 시놀로지 NAS 서브도메인 관리 시스템

시놀로지 NAS의 crossman.synology.me 도메인을 기반으로 한 완전한 서브도메인 관리 시스템을 개발했습니다. **NAS-SubDomain-Manager**라는 프로젝트명으로 VSCode 환경에서 개발 가능하며, SSH를 통해 권한 충돌 없이 설치할 수 있는 모듈화된 스크립트 시스템입니다.

## 🔒 안전 기능 (Security Features)

### 요청/승인 시스템
- **모든 중요한 작업에 대해 사용자 승인 요구**
- **파괴적 작업은 특별한 확인 문구 요구**
- **모든 승인 요청과 결과가 로그에 기록**
- **테스트 모드에서는 자동 승인 지원**

### 백업/복원 시스템
- **자동 백업 생성 (설정, 스크립트, Docker 볼륨)**
- **업데이트 전 안전 백업 자동 생성**
- **원클릭 복원 기능**
- **백업 검증 및 메타데이터 관리**

## 프로젝트 개요

### 프로젝트명 제안

**NAS-SubDomain-Manager** - 시놀로지 NAS용 서브도메인 관리 시스템으로, 다음과 같은 특징을 가집니다:

- **모듈화된 구조**: 기능별로 분리된 스크립트
- **자동화 지원**: Docker 기반 서비스 관리
- **보안 강화**: 방화벽 및 SSL 인증서 자동 설정
- **요청/승인 워크플로우**: 안전한 운영을 위한 승인 시스템
- **백업/복원 자동화**: 실패 시 빠른 복구 지원
- **모니터링 통합**: 헬스체크 및 백업 자동화
- **VSCode 호환**: 개발 환경 완벽 지원

![시놀로지 NAS 서브도메인 아키텍처 및 포트 매핑](https://pplx-res.cloudinary.com/image/upload/v1751441072/pplx_code_interpreter/d63a1b90_sxi5fo.jpg)

시놀로지 NAS 서브도메인 아키텍처 및 포트 매핑

### 주요 서비스 및 포트 매핑

제공해주신 포트포워드 정보를 기반으로 다음 서비스들의 서브도메인을 관리합니다:


| 서비스 | 서브도메인 | 외부 포트 | 내부 포트 | 용도 |
| :-- | :-- | :-- | :-- | :-- |
| n8n | n8n.crossman.synology.me | 31001 | 5678 | 워크플로우 자동화 |
| MCP | mcp.crossman.synology.me | 31002 | 31002 | 모델 컨텍스트 프로토콜 |
| Uptime Kuma | uptime.crossman.synology.me | 31003 | 31003 | 모니터링 |
| Code Server | code.crossman.synology.me | 8484 | 8484 | VSCode 웹 환경 |
| Gitea | git.crossman.synology.me | 3000 | 3000 | Git 저장소 |
| DSM | dsm.crossman.synology.me | 5001 | 5001 | NAS 관리 |

## 프로젝트 구조

모듈화된 구조로 각 기능별로 명확히 분리되어 있어 유지보수가 용이합니다.

![NAS-SubDomain-Manager 프로젝트 디렉토리 구조](https://pplx-res.cloudinary.com/image/upload/v1751441264/pplx_code_interpreter/758190ca_fhssjv.jpg)

NAS-SubDomain-Manager 프로젝트 디렉토리 구조

### 디렉토리 구성

```
/volume1/dev/NAS-SubDomain-Manager/
├── main.sh                    # 메인 실행 스크립트
├── .env                       # 환경 변수 설정
├── docker-compose.yml         # Docker 서비스 정의
├── config/                    # 설정 파일들
├── scripts/                   # 기능별 스크립트
│   ├── setup/                # 초기 설정 스크립트
│   ├── services/             # 서비스 관리 스크립트
│   ├── security/             # 보안 관련 스크립트
│   └── maintenance/          # 유지보수 스크립트
├── docker/                   # Docker 데이터 및 설정
├── logs/                     # 로그 파일들
├── backup/                   # 백업 디렉토리
└── docs/                     # 문서
```


## 기능별 모듈 구성

### 1. 기초 구조 모듈

**색상 로그 시스템**: 직관적이고 깔끔한 로그 출력을 제공합니다.

```bash
log_info()    # 녹색 - 정보 메시지
log_warn()    # 노란색 - 경고 메시지
log_error()   # 빨간색 - 에러 메시지
log_step()    # 파란색 - 진행 단계
log_success() # 보라색 - 성공 메시지
```

**환경 변수 관리**: 배열 구조로 포트 및 서브도메인을 체계적으로 관리합니다.

**사전 검사 기능**:

- DSM 7.0 이상 버전 확인
- Docker 서비스 상태 검사
- 포트 사용 현황 검증
- Root 권한 방지


### 2. 디렉토리 및 설정 파일 모듈

**자동 디렉토리 생성**: 프로젝트, Docker, 백업 디렉토리를 체계적으로 구성합니다.

**설정 파일 자동 생성**:

- `.env` 파일: 메인 환경 변수
- `n8n/.env`: n8n 전용 설정
- `config.json`: MCP 서버 설정 (allowedIPs, CORS, API_KEY 포함)


### 3. 방화벽 보안 모듈

**포트 보안 관리**: 기본 포트 오픈 규칙을 제공하며 VPN 접근을 우선시합니다.

**설정 가이드**: `firewall-rules.txt` 파일로 수동 설정 안내를 제공합니다.

### 4. DNS \& DDNS 관리 모듈

**DNS 설정 자동화**:

- `dns-config.txt`: 서브도메인 설정 가이드
- `update-dns.sh`: nslookup 기반 DNS 확인
- Synology DDNS 서비스 자동 재시작


### 5. Docker Compose 서비스 모듈

**컨테이너 구성**:

- nginx-proxy: 리버스 프록시
- n8n: 워크플로우 자동화
- mcp-server: Node.js 기반 임베디드 웹서버
- uptime-kuma: 모니터링
- watchtower: 자동 업데이트

**자동 설정**:

- 서브도메인별 VIRTUAL_HOST 설정
- Let's Encrypt SSL 인증서 준비
- Docker 네트워크 (172.20.0.0/16) 구성


### 6. 백업 \& 헬스체크 모듈

**자동 백업 시스템**:

- n8n 데이터 및 설정 백업
- Docker 볼륨 백업
- 설정 파일 백업
- 30일 보관 정책

**헬스체크 모니터링**:

- Docker 컨테이너 상태 확인
- HTTP 연결 상태 점검
- Uptime Kuma 알림 통합
- 5분마다 자동 점검


## 설치 및 사용법

### 기본 설치 명령어

```bash
# 전체 시스템 설치
./main.sh install

# 개별 설정
./main.sh setup      # 초기 설정만
./main.sh start      # 서비스 시작
./main.sh status     # 상태 확인
./main.sh backup     # 백업 실행
```


### VSCode 개발 환경 설정

1. **프로젝트 클론**: SSH를 통해 NAS에 접속하여 프로젝트를 설정합니다.
2. **Dev Container**: VSCode의 Remote Development 확장을 사용하여 NAS 환경에서 직접 개발 가능합니다[^25][^26].
3. **Code Server**: `code.crossman.synology.me`를 통해 웹 기반 VSCode 환경을 제공합니다.

## 보안 고려사항

### 네트워크 보안

- **VPN 우선 접근**: 외부 접근은 OpenVPN(포트 1194)을 통해서만 권장
- **방화벽 규칙**: 내부 네트워크(192.168.0.0/24) 및 Docker 네트워크(172.20.0.0/16)만 허용
- **포트 제한**: 필요한 포트만 개방하여 공격 표면 최소화


### SSL 인증서

- **와일드카드 인증서**: `*.crossman.synology.me` 지원
- **자동 갱신**: Let's Encrypt를 통한 90일 자동 갱신
- **HTTPS 강제**: 모든 서비스에 HTTPS 적용


## 모니터링 및 유지보수

### 자동화된 백업

- **일일 백업**: 매일 02:00에 자동 실행
- **보관 정책**: 30일간 보관 후 자동 삭제
- **알림 시스템**: Uptime Kuma를 통한 백업 성공/실패 알림


### 헬스체크 시스템

- **서비스 상태**: Docker 컨테이너 상태 실시간 모니터링
- **네트워크 연결**: HTTP 엔드포인트 상태 확인
- **자동 복구**: 서비스 재시작 및 복구 로직


## 확장 가능성

### 추가 서비스 통합

시스템은 모듈화되어 있어 새로운 서비스를 쉽게 추가할 수 있습니다:

- Home Assistant (포트 8123)
- Mi Connector (포트 30000)
- MySQL 데이터베이스 (포트 3306)


### API 통합

MCP 서버를 통해 다양한 외부 서비스와 연동 가능하며, n8n 워크플로우를 통한 자동화 확장이 용이합니다[^9][^12][^15].

이 시스템은 시놀로지 NAS의 강력한 기능을 활용하여 안전하고 확장 가능한 서브도메인 관리 환경을 제공합니다. VSCode 환경에서의 개발부터 운영까지 모든 단계를 자동화하여 DevOps 워크플로우를 완성할 수 있습니다.

<div style="text-align: center">⁂</div>

[^1]: https://www.youtube.com/watch?v=7-L3wuMaLqk

[^2]: https://docs.n8n.io/hosting/installation/docker/

[^3]: https://chochol.io/en/hardware/synology-free-ports-80-443-for-nginx-proxy-manager/

[^4]: https://deployn.de/en/guides/synology-nas/

[^5]: https://docs.n8n.io/hosting/installation/server-setups/docker-compose/

[^6]: https://www.blackvoid.club/nginx-proxy-manager/

[^7]: https://mariushosting.com/synology-huge-docker-container-updates-june-2025/

[^8]: https://docs.n8n.io/hosting/configuration/configuration-methods/

[^9]: https://docs.anthropic.com/en/docs/claude-code/mcp

[^10]: https://jarrodstech.net/how-to-set-up-multiple-domains-or-sub-domains-on-synology-nas/

[^11]: https://www.youtube.com/watch?v=H2nDut-1wGM

[^12]: https://devblogs.microsoft.com/dotnet/build-a-model-context-protocol-mcp-server-in-csharp/

[^13]: https://stackoverflow.com/questions/45260719/synology-port-forwardding-according-to-subdomain

[^14]: https://www.reddit.com/r/synology/comments/yowkw6/wildcard_ddns_for_custom_domains/

[^15]: https://towardsdatascience.com/model-context-protocol-mcp-tutorial-build-your-first-mcp-server-in-6-steps/

[^16]: https://superuser.com/questions/1519112/how-to-create-and-connect-subdomain-to-synology

[^17]: https://dev-pages.info/backup-docker-volumes-to-the-nas/

[^18]: https://www.youtube.com/watch?v=eCTjLTJcogQ

[^19]: https://www.tskamath.com/🛠️-synology-nas-how-to-get-a-wildcard-lets-encrypt-certificate-for-any-domain/

[^20]: https://www.reddit.com/r/synology/comments/1gnonnb/is_it_possible_to_automate_the_backup_of_docker/

[^21]: https://mariushosting.com/synology-how-to-correctly-set-up-firewall-on-dsm-7/

[^22]: https://mariushosting.com/synology-how-to-add-wildcard-certificate/

[^23]: https://www.youtube.com/watch?v=9RUk9uEpvOg

[^24]: https://kb.synology.com/DSM/tutorial/What_network_ports_are_used_by_Synology_services

[^25]: https://www.docker.com/blog/master-docker-vs-code-supercharge-your-dev-workflow/

[^26]: https://code.visualstudio.com/docs/devcontainers/containers

[^27]: https://www.cloudpanel.io/tutorial/cloudpanel-subdomains/

[^28]: https://www.reddit.com/r/dotnet/comments/1bhkbuw/how_to_organize_domains_in_a_clean_architecture/

[^29]: https://nz.hostadvice.com/subdomain/

[^30]: https://domaindrivendesign.org/project-structure/

[^31]: https://1grid.co.za/blog/subdomains-vs-subdirectories-best-practices-for-2025/

[^32]: https://stackoverflow.com/questions/75805314/what-is-the-better-approach-for-creating-folder-structure-on-a-ddd-project

[^33]: https://mariushosting.com/how-to-install-nginx-proxy-manager-on-your-synology-nas/

[^34]: https://mariushosting.com/synology-huge-docker-container-updates-may-2025/

[^35]: https://docs.cursor.com/context/model-context-protocol

[^36]: https://github.com/JessThrysoee/synology-letsencrypt

[^37]: https://www.youtube.com/watch?v=dLCEqp2Vn9I

[^38]: https://code.visualstudio.com/docs/devcontainers/create-dev-container

[^39]: https://gbhackers.com/dns-management-tools/

[^40]: https://ppl-ai-code-interpreter-files.s3.amazonaws.com/web/direct-files/8a641717e615de089a3cd2f37672c3d5/964be9dd-a41f-4d4d-af3e-6d93bac9c7b2/f121df8f.sh

[^41]: https://ppl-ai-code-interpreter-files.s3.amazonaws.com/web/direct-files/8a641717e615de089a3cd2f37672c3d5/adaf0077-1382-4395-8075-fc11d332f75c/77393d4e.json

[^42]: https://ppl-ai-code-interpreter-files.s3.amazonaws.com/web/direct-files/8a641717e615de089a3cd2f37672c3d5/adaf0077-1382-4395-8075-fc11d332f75c/210461fc.json

<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# 시놀로지 NAS 서브도메인 관리 시스템

시놀로지 NAS의 crossman.synology.me 도메인을 기반으로 한 완전한 서브도메인 관리 시스템을 개발했습니다. **NAS-SubDomain-Manager**라는 프로젝트명으로 VSCode 환경에서 개발 가능하며, SSH를 통해 권한 충돌 없이 설치할 수 있는 모듈화된 스크립트 시스템입니다.

## 🔒 안전 기능 (Security Features)

### 요청/승인 시스템
- **모든 중요한 작업에 대해 사용자 승인 요구**
- **파괴적 작업은 특별한 확인 문구 요구**
- **모든 승인 요청과 결과가 로그에 기록**
- **테스트 모드에서는 자동 승인 지원**

### 백업/복원 시스템
- **자동 백업 생성 (설정, 스크립트, Docker 볼륨)**
- **업데이트 전 안전 백업 자동 생성**
- **원클릭 복원 기능**
- **백업 검증 및 메타데이터 관리**

## 프로젝트 개요

### 프로젝트명 제안

**NAS-SubDomain-Manager** - 시놀로지 NAS용 서브도메인 관리 시스템으로, 다음과 같은 특징을 가집니다:

- **모듈화된 구조**: 기능별로 분리된 스크립트
- **자동화 지원**: Docker 기반 서비스 관리
- **보안 강화**: 방화벽 및 SSL 인증서 자동 설정
- **요청/승인 워크플로우**: 안전한 운영을 위한 승인 시스템
- **백업/복원 자동화**: 실패 시 빠른 복구 지원
- **모니터링 통합**: 헬스체크 및 백업 자동화
- **VSCode 호환**: 개발 환경 완벽 지원

![시놀로지 NAS 서브도메인 아키텍처 및 포트 매핑](https://pplx-res.cloudinary.com/image/upload/v1751441072/pplx_code_interpreter/d63a1b90_sxi5fo.jpg)

시놀로지 NAS 서브도메인 아키텍처 및 포트 매핑

### 주요 서비스 및 포트 매핑

제공해주신 포트포워드 정보를 기반으로 다음 서비스들의 서브도메인을 관리합니다:


| 서비스 | 서브도메인 | 외부 포트 | 내부 포트 | 용도 |
| :-- | :-- | :-- | :-- | :-- |
| n8n | n8n.crossman.synology.me | 31001 | 5678 | 워크플로우 자동화 |
| MCP | mcp.crossman.synology.me | 31002 | 31002 | 모델 컨텍스트 프로토콜 |
| Uptime Kuma | uptime.crossman.synology.me | 31003 | 31003 | 모니터링 |
| Code Server | code.crossman.synology.me | 8484 | 8484 | VSCode 웹 환경 |
| Gitea | git.crossman.synology.me | 3000 | 3000 | Git 저장소 |
| DSM | dsm.crossman.synology.me | 5001 | 5001 | NAS 관리 |

## 프로젝트 구조

모듈화된 구조로 각 기능별로 명확히 분리되어 있어 유지보수가 용이합니다.

![NAS-SubDomain-Manager 프로젝트 디렉토리 구조](https://pplx-res.cloudinary.com/image/upload/v1751441264/pplx_code_interpreter/758190ca_fhssjv.jpg)

NAS-SubDomain-Manager 프로젝트 디렉토리 구조

### 디렉토리 구성

```
/volume1/dev/NAS-SubDomain-Manager/
├── main.sh                    # 메인 실행 스크립트
├── .env                       # 환경 변수 설정
├── docker-compose.yml         # Docker 서비스 정의
├── config/                    # 설정 파일들
├── scripts/                   # 기능별 스크립트
│   ├── setup/                # 초기 설정 스크립트
│   ├── services/             # 서비스 관리 스크립트
│   ├── security/             # 보안 관련 스크립트
│   └── maintenance/          # 유지보수 스크립트
├── docker/                   # Docker 데이터 및 설정
├── logs/                     # 로그 파일들
├── backup/                   # 백업 디렉토리
└── docs/                     # 문서
```


## 기능별 모듈 구성

### 1. 기초 구조 모듈

**색상 로그 시스템**: 직관적이고 깔끔한 로그 출력을 제공합니다.

```bash
log_info()    # 녹색 - 정보 메시지
log_warn()    # 노란색 - 경고 메시지
log_error()   # 빨간색 - 에러 메시지
log_step()    # 파란색 - 진행 단계
log_success() # 보라색 - 성공 메시지
```

**환경 변수 관리**: 배열 구조로 포트 및 서브도메인을 체계적으로 관리합니다.

**사전 검사 기능**:

- DSM 7.0 이상 버전 확인
- Docker 서비스 상태 검사
- 포트 사용 현황 검증
- Root 권한 방지


### 2. 디렉토리 및 설정 파일 모듈

**자동 디렉토리 생성**: 프로젝트, Docker, 백업 디렉토리를 체계적으로 구성합니다.

**설정 파일 자동 생성**:

- `.env` 파일: 메인 환경 변수
- `n8n/.env`: n8n 전용 설정
- `config.json`: MCP 서버 설정 (allowedIPs, CORS, API_KEY 포함)


### 3. 방화벽 보안 모듈

**포트 보안 관리**: 기본 포트 오픈 규칙을 제공하며 VPN 접근을 우선시합니다.

**설정 가이드**: `firewall-rules.txt` 파일로 수동 설정 안내를 제공합니다.

### 4. DNS \& DDNS 관리 모듈

**DNS 설정 자동화**:

- `dns-config.txt`: 서브도메인 설정 가이드
- `update-dns.sh`: nslookup 기반 DNS 확인
- Synology DDNS 서비스 자동 재시작


### 5. Docker Compose 서비스 모듈

**컨테이너 구성**:

- nginx-proxy: 리버스 프록시
- n8n: 워크플로우 자동화
- mcp-server: Node.js 기반 임베디드 웹서버
- uptime-kuma: 모니터링
- watchtower: 자동 업데이트

**자동 설정**:

- 서브도메인별 VIRTUAL_HOST 설정
- Let's Encrypt SSL 인증서 준비
- Docker 네트워크 (172.20.0.0/16) 구성


### 6. 백업 \& 헬스체크 모듈

**자동 백업 시스템**:

- n8n 데이터 및 설정 백업
- Docker 볼륨 백업
- 설정 파일 백업
- 30일 보관 정책

**헬스체크 모니터링**:

- Docker 컨테이너 상태 확인
- HTTP 연결 상태 점검
- Uptime Kuma 알림 통합
- 5분마다 자동 점검


## 설치 및 사용법

### 기본 설치 명령어

```bash
# 전체 시스템 설치
./main.sh install

# 개별 설정
./main.sh setup      # 초기 설정만
./main.sh start      # 서비스 시작
./main.sh status     # 상태 확인
./main.sh backup     # 백업 실행
```


### VSCode 개발 환경 설정

1. **프로젝트 클론**: SSH를 통해 NAS에 접속하여 프로젝트를 설정합니다.
2. **Dev Container**: VSCode의 Remote Development 확장을 사용하여 NAS 환경에서 직접 개발 가능합니다[^25][^26].
3. **Code Server**: `code.crossman.synology.me`를 통해 웹 기반 VSCode 환경을 제공합니다.

## 보안 고려사항

### 네트워크 보안

- **VPN 우선 접근**: 외부 접근은 OpenVPN(포트 1194)을 통해서만 권장
- **방화벽 규칙**: 내부 네트워크(192.168.0.0/24) 및 Docker 네트워크(172.20.0.0/16)만 허용
- **포트 제한**: 필요한 포트만 개방하여 공격 표면 최소화


### SSL 인증서

- **와일드카드 인증서**: `*.crossman.synology.me` 지원
- **자동 갱신**: Let's Encrypt를 통한 90일 자동 갱신
- **HTTPS 강제**: 모든 서비스에 HTTPS 적용


## 모니터링 및 유지보수

### 자동화된 백업

- **일일 백업**: 매일 02:00에 자동 실행
- **보관 정책**: 30일간 보관 후 자동 삭제
- **알림 시스템**: Uptime Kuma를 통한 백업 성공/실패 알림


### 헬스체크 시스템

- **서비스 상태**: Docker 컨테이너 상태 실시간 모니터링
- **네트워크 연결**: HTTP 엔드포인트 상태 확인
- **자동 복구**: 서비스 재시작 및 복구 로직


## 확장 가능성

### 추가 서비스 통합

시스템은 모듈화되어 있어 새로운 서비스를 쉽게 추가할 수 있습니다:

- Home Assistant (포트 8123)
- Mi Connector (포트 30000)
- MySQL 데이터베이스 (포트 3306)


### API 통합

MCP 서버를 통해 다양한 외부 서비스와 연동 가능하며, n8n 워크플로우를 통한 자동화 확장이 용이합니다[^9][^12][^15].

이 시스템은 시놀로지 NAS의 강력한 기능을 활용하여 안전하고 확장 가능한 서브도메인 관리 환경을 제공합니다. VSCode 환경에서의 개발부터 운영까지 모든 단계를 자동화하여 DevOps 워크플로우를 완성할 수 있습니다.

<div style="text-align: center">⁂</div>

[^1]: https://www.youtube.com/watch?v=7-L3wuMaLqk

[^2]: https://docs.n8n.io/hosting/installation/docker/

[^3]: https://chochol.io/en/hardware/synology-free-ports-80-443-for-nginx-proxy-manager/

[^4]: https://deployn.de/en/guides/synology-nas/

[^5]: https://docs.n8n.io/hosting/installation/server-setups/docker-compose/

[^6]: https://www.blackvoid.club/nginx-proxy-manager/

[^7]: https://mariushosting.com/synology-huge-docker-container-updates-june-2025/

[^8]: https://docs.n8n.io/hosting/configuration/configuration-methods/

[^9]: https://docs.anthropic.com/en/docs/claude-code/mcp

[^10]: https://jarrodstech.net/how-to-set-up-multiple-domains-or-sub-domains-on-synology-nas/

[^11]: https://www.youtube.com/watch?v=H2nDut-1wGM

[^12]: https://devblogs.microsoft.com/dotnet/build-a-model-context-protocol-mcp-server-in-csharp/

[^13]: https://stackoverflow.com/questions/45260719/synology-port-forwardding-according-to-subdomain

[^14]: https://www.reddit.com/r/synology/comments/yowkw6/wildcard_ddns_for_custom_domains/

[^15]: https://towardsdatascience.com/model-context-protocol-mcp-tutorial-build-your-first-mcp-server-in-6-steps/

[^16]: https://superuser.com/questions/1519112/how-to-create-and-connect-subdomain-to-synology

[^17]: https://dev-pages.info/backup-docker-volumes-to-the-nas/

[^18]: https://www.youtube.com/watch?v=eCTjLTJcogQ

[^19]: https://www.tskamath.com/🛠️-synology-nas-how-to-get-a-wildcard-lets-encrypt-certificate-for-any-domain/

[^20]: https://www.reddit.com/r/synology/comments/1gnonnb/is_it_possible_to_automate_the_backup_of_docker/

[^21]: https://mariushosting.com/synology-how-to-correctly-set-up-firewall-on-dsm-7/

[^22]: https://mariushosting.com/synology-how-to-add-wildcard-certificate/

[^23]: https://www.youtube.com/watch?v=9RUk9uEpvOg

[^24]: https://kb.synology.com/DSM/tutorial/What_network_ports_are_used_by_Synology_services

[^25]: https://www.docker.com/blog/master-docker-vs-code-supercharge-your-dev-workflow/

[^26]: https://code.visualstudio.com/docs/devcontainers/containers

[^27]: https://www.cloudpanel.io/tutorial/cloudpanel-subdomains/

[^28]: https://www.reddit.com/r/dotnet/comments/1bhkbuw/how_to_organize_domains_in_a_clean_architecture/

[^29]: https://nz.hostadvice.com/subdomain/

[^30]: https://domaindrivendesign.org/project-structure/

[^31]: https://1grid.co.za/blog/subdomains-vs-subdirectories-best-practices-for-2025/

[^32]: https://stackoverflow.com/questions/75805314/what-is-the-better-approach-for-creating-folder-structure-on-a-ddd-project

[^33]: https://mariushosting.com/how-to-install-nginx-proxy-manager-on-your-synology-nas/

[^34]: https://mariushosting.com/synology-huge-docker-container-updates-may-2025/

[^35]: https://docs.cursor.com/context/model-context-protocol

[^36]: https://github.com/JessThrysoee/synology-letsencrypt

[^37]: https://www.youtube.com/watch?v=dLCEqp2Vn9I

[^38]: https://code.visualstudio.com/docs/devcontainers/create-dev-container

[^39]: https://gbhackers.com/dns-management-tools/

[^40]: https://ppl-ai-code-interpreter-files.s3.amazonaws.com/web/direct-files/8a641717e615de089a3cd2f37672c3d5/964be9dd-a41f-4d4d-af3e-6d93bac9c7b2/f121df8f.sh

[^41]: https://ppl-ai-code-interpreter-files.s3.amazonaws.com/web/direct-files/8a641717e615de089a3cd2f37672c3d5/adaf0077-1382-4395-8075-fc11d332f75c/77393d4e.json

[^42]: https://ppl-ai-code-interpreter-files.s3.amazonaws.com/web/direct-files/8a641717e615de089a3cd2f37672c3d5/adaf0077-1382-4395-8075-fc11d332f75c/210461fc.json

## 🚀 사용법 (Usage)

### 기본 명령어

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
./main.sh backup-list   # 백업 목록 확인
./main.sh backup-info   # 백업 정보 확인

# 시스템 관리
./main.sh update     # 시스템 업데이트
./main.sh clean      # 시스템 정리
./main.sh health     # 헬스체크 실행
./main.sh logs       # 로그 확인
```

### 승인 시스템 명령어

```bash
# 승인 로그 및 통계
./main.sh approval-log     # 최근 승인 로그 확인
./main.sh approval-stats   # 승인 통계 보기

# 테스트 모드 (자동 승인)
./main.sh test-mode-on     # 테스트 모드 활성화
./main.sh test-mode-off    # 테스트 모드 비활성화
```

## 🔐 승인 시스템 가이드

### 위험 등급별 승인 프로세스

#### 1. 낮은 위험 (Low Risk)
- **승인 문구**: `yes`
- **예시**: 서비스 시작, 상태 확인, 로그 정리
- **자동 승인**: 테스트 모드에서 가능

#### 2. 보통 위험 (Medium Risk)
- **승인 문구**: 작업별 고유 문구
- **예시**: 서비스 재시작, 업데이트, 백업 복원
- **확인 필요**: 서비스 중단 경고 포함

#### 3. 높은 위험 (High/Critical Risk)
- **승인 문구**: `I_UNDERSTAND_THE_RISKS`
- **예시**: 시스템 정리, 볼륨 삭제, 전체 복원
- **특별 확인**: 데이터 손실 가능성 경고

### 승인 시스템 예시

```bash
# 서비스 중지 시 승인 요청
$ ./main.sh stop

===============================================
  🔒 승인 요청 (Approval Request)
===============================================
작업 (Action): STOP_SERVICES
설명 (Description): 모든 Docker 서비스 중지 - 웹 접근이 일시적으로 중단됩니다
위험 등급 (Risk Level): medium
시간 (Time): 2025-01-06 15:30:45

⚠️  서비스 중단 경고 (SERVICE INTERRUPTION WARNING)
⚠️  다음 서비스들이 일시적으로 중단될 수 있습니다:
⚠️  MCP Server, Uptime Kuma, Code Server, Gitea, DSM Proxy, Portainer

이 작업을 승인하시겠습니까?
계속 진행하려면 'PROCEED_WITH_INTERRUPTION'를 입력하세요 (취소하려면 Enter 또는 다른 값):
> PROCEED_WITH_INTERRUPTION

✅ 승인되었습니다. 작업을 계속 진행합니다.
```

## 🔧 고급 설정

### 환경 변수 사용자 정의

```bash
# 백업 보관 기간 설정 (기본: 7일)
export BACKUP_RETENTION_DAYS=14

# 로그 보관 기간 설정 (기본: 30일)
export LOG_RETENTION_DAYS=60

# 테스트 모드 활성화
export NAS_APPROVAL_TEST_MODE=true
```

### 백업 스케줄링

```bash
# 매일 새벽 2시 자동 백업
echo "0 2 * * * cd /path/to/nas-subdomain && ./main.sh backup" >> /etc/crontab
```

## 🆘 문제 해결

### 승인 요청이 무시되는 경우
1. 테스트 모드 확인: `echo $NAS_APPROVAL_TEST_MODE`
2. 로그 확인: `./main.sh approval-log`
3. 권한 확인: 스크립트 실행 권한 확인

### 백업 실패 시
1. 디스크 공간 확인: `df -h`
2. Docker 상태 확인: `docker info`
3. 권한 확인: `ls -la backup/`

### 서비스 복원 실패 시
1. 백업 파일 검증: `./main.sh backup-info`
2. Docker 볼륨 확인: `docker volume ls`
3. 안전 백업에서 복원 고려

## 📋 체크리스트

### 설치 전 확인사항
- [ ] 시놀로지 DSM 7.0 이상
- [ ] Docker 서비스 실행 중
- [ ] SSH 접근 권한 확보
- [ ] 충분한 디스크 공간 (최소 5GB)

### 운영 시 주의사항
- [ ] 중요 작업 전 백업 생성
- [ ] 승인 요청 신중히 검토
- [ ] 정기적인 로그 모니터링
- [ ] 백업 파일 정기 검증

## 📞 지원

문제가 발생하거나 개선사항이 있다면:
1. 로그 파일 확인: `./main.sh logs`
2. 승인 로그 확인: `./main.sh approval-log`
3. 시스템 상태 확인: `./main.sh status`

