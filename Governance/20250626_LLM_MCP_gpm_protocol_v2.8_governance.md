# GPM-ECO v2.8 → DCEC v1.0 Migration Guide
> 기존 GPM-ECO 환경을 DCEC 구조로 전환하는 가이드

## 📋 문서 상태
- **원본**: GPM-ECO v2.8 (2025-06-26)
- **전환**: DCEC v1.0 (2025-07-06)
- **상태**: Reference Document (참조용)

---

## 🔄 주요 변경사항

### 구조 변경
| GPM-ECO v2.8 | DCEC v1.0 | 설명 |
|---------------|-----------|------|
| `/volume1/dev/` (NAS) | `D:\Dev\DCEC\` (Local) | 로컬 개발환경 우선 |
| 통합 환경 | 서브프로젝트 분리 | Dev_Env, Infra, Governance |
| NAS 중심 | VS Code 중심 | IDE 기반 개발환경 |

### 도구 매핑
| GPM-ECO | DCEC | 용도 |
|---------|------|------|
| n8n (31001) | 향후 계획 | 자동화 워크플로우 |
| code-server (8484) | VS Code Local | 코드 에디터 |
| MCP (31002) | 계획 중 | Model Context Protocol |
| uptime-kuma (31003) | 향후 계획 | 모니터링 |

---

## 🎯 DCEC 현재 상태

### ✅ 완료된 부분
1. **프로젝트 구조**: 3개 서브프로젝트 분리
2. **Dev_Env/CLI**: PowerShell 기반 CLI 환경
3. **로그 관리**: 체계적인 로그/채팅 관리 시스템
4. **VS Code 통합**: Tasks, Launch, Workspace 설정

### ⏳ 진행 중
1. **채팅 관리**: AI 채팅 기록 체계화
2. **자동화 도구**: PowerShell 스크립트 확장
3. **문서화**: 개발 가이드 정립

### 📋 향후 계획
1. **IDE 환경**: VS Code 확장 및 설정 최적화
2. **인프라 구축**: Docker 기반 환경 (GPM-ECO 참조)
3. **거버넌스**: 개발 프로세스 정의

---

## 2. 네트워크 환경 정보 요약 (Moomoo 기준)

- 도메인: `crossman.synology.me` (Synology DDNS)
- 공유기: ASUS RT-AX88U
- NAS 내부 IP: `192.168.0.5`
- NAS 환경 기준 데이터 경로: `/volume1/dev/`

### 방화벽 포트 포워딩 상태

| 서비스                | 외부 포트 | 내부 포트 | IP 주소         | 프로토콜 |
| ------------------ | ----- | ----- | ------------- | ---- |
| ipcam              | 88    | 88    | 192.168.0.200 | TCP  |
| HTTP\_NAS          | 5000  | 5000  | 192.168.0.5   | TCP  |
| HTTPS\_NAS\_DSM    | 5001  | 5001  | 192.168.0.5   | TCP  |
| Iot\_HA            | 8123  | 8123  | 192.168.0.5   | TCP  |
| Iot\_Mi\_Connector | 30000 | 30000 | 192.168.0.5   | BOTH |
| HTTPS\_NAS         | 443   | 443   | 192.168.0.5   | TCP  |
| DB\_NAS            | 3306  | 3306  | 192.168.0.5   | UDP  |
| gitea              | 3000  | 3000  | 192.168.0.5   | TCP  |
| Https\_gitea       | 450   | 3000  | 192.168.0.5   | TCP  |
| code-server        | 8484  | 8484  | 192.168.0.5   | TCP  |
| n8n                | 31001 | 443   | 192.168.0.5   | TCP  |
| mcp                | 31002 | 31002 | 192.168.0.5   | TCP  |
| uptime-kuma        | 31003 | 31003 | 192.168.0.5   | TCP  |
| VPN\_OpenVPN       | 1194  | 1194  | 192.168.0.5   | UDP  |
| ext\_ssh           | 22022 | 22022 | 192.168.0.5   | TCP  |

※ HTTP(80)는 열려 있으나 실운영에서는 차단 및 HTTPS 강제 권장

---

## 3. LLM 앱 환경 최적 설정

3.1 지피 앱 환경 최적 설정 (ChatGPT App)

Downlaod : 
### System Instruction

```
You are GPT-DevOps Assistant partnered with a human named Moomoo. Your mission is to build and operate a portable, automated, and resilient development ecosystem using NAS, Docker, VPN, and LLMs.

Follow these core principles:

- Always clarify environment or goals before answering
- Persist user-defined rules, network settings, and naming conventions
- Automate repetitive tasks using tools like n8n and MCP
- Track all configuration, workflow, and policy changes with clear versioning
- Ensure all responses are structured (markdown preferred) and production-ready
- Avoid emojis and freeform chat; use bullet-point logic
- Collaborate with other LLMs (Claude, Perplexity) when applicable

You are not a chatbot. You are a technical partner responsible for system integrity, documentation, and execution support across environments.
```

### User Profile

```
- Name: Moomoo
- Role: Project Architect & Owner
- Goals: Build portable, persistent, and replicable AI-DevOps environment using NAS + Docker + LLMs
```

### Session Defaults

```
- Output: Markdown or YAML only
- Language: Korean unless instructed otherwise
- Limit: No response length restriction
- Role: Partner-level co-pilot
```
3.2 Claude 설치 및 환경 구성


Downlaod : 

### Your Profile
You are Claude, an AI assistant working collaboratively with Moomoo.  
- Ask clarifying questions before proceeding.  
- Maintain persistent memory and document all actions and changes.  
- Automate repeatable tasks using connected tools like n8n and MCP.  
- Respond clearly in structured bullet points, no emojis.  
- Align with the current NAS and network environment under domain crossman.synology.me.

You are not a chatbot. You are a technical partner responsible for system integrity, documentation, and execution support across environments.

3.3 Perplexity 설치 및 환경 구성

Downlaod : 

### Your Profile
You are Perplexity AI, assisting Moomoo with data-driven decision making.  
- Always confirm the environment details before executing tasks.  
- Document all changes and maintain a versioned log.  
- Automate workflows and integrate with n8n and MCP.  
- Use clear, concise bullet points, no emojis.  
- Operate within the NAS and VPN environment defined by crossman.synology.me domain.

You are not a chatbot. You are a technical partner responsible for system integrity, documentation, and execution support across environments.

---

## 4. MCP 기반 DevOps 환경 초기 구축

- `n8n`, `code-server`, `mcp`, `uptime-kuma`는 각각 포트포워딩 완료
- NAS 내부 모든 컨테이너는 `/volume1/dev/` 하위에 데이터/설정 저장
- 외부 접속 도메인 예시:
  - `https://crossman.synology.me:31001` → n8n
  - `https://crossman.synology.me:31002` → mcp
  - `https://crossman.synology.me:8484` → code-server

### ✅ n8n 재설치 절차 (Docker 기반)

1. 기존 컨테이너 및 볼륨 제거

```bash
docker stop n8n && docker rm n8n
rm -rf /volume1/dev/n8n
```

2. Docker Compose 또는 단일 Docker로 재배포

```bash
docker run -it -d \
  --name n8n \
  -p 31001:5678 \
  -v /volume1/dev/n8n:/home/node/.n8n \
  -e TZ=Asia/Seoul \
  -e N8N_BASIC_AUTH_ACTIVE=true \
  -e N8N_BASIC_AUTH_USER=admin \
  -e N8N_BASIC_AUTH_PASSWORD=your_secure_password \
  n8nio/n8n
```

3. 테스트: `https://crossman.synology.me:31001` 접속 후 로그인 확인

4. 백업 복원: `.n8n` 디렉토리에 이전 `config`, `database.sqlite` 등 복사 시 상태 복구 가능

---

## 5. VPN + NAS 구성 연동 점검

- OpenVPN 활성화 (포트 1194 UDP)
- `.ovpn` 또는 `wg.conf` 생성 후 노트북/모바일에 배포
- VPN 연결 후 `192.168.0.5` 대역의 NAS 서비스 접근 확인
- 공유기 방화벽 예외 및 포트 충돌 점검 필수

---

## 6. 동기화 기반 멀티 디바이스 운영 환경

- Synology Drive 또는 rsync, Syncthing을 이용한 실시간 혹은 예약 동기화 구축
- 디렉토리 기준: `/volume1/dev/` ↔ 노트북 `~/dev/` 경로 매칭
- VPN 연결 상태에서 자동 동기화 스크립트 실행 (`sync-dev.sh`)
- conflict 정책 및 exclude 목록은 `.syncignore` 또는 n8n 워크플로우로 관리
- NAS ↔ 노트북 간 **양방향 동기화** 보장 시, 변경 감지 이벤트 기반으로 MCP 또는 Git 자동화 동작

---

## 7. 오류 감지 및 복구 루틴

- 포트 점검 루틴 (`check-port.sh`): 내부 NAS와 외부 도메인 기준 동시 검사
- `uptime-kuma`를 통한 실시간 외부 서비스 모니터링
- `backup.sh` + `rsync` 또는 `Hyper Backup`으로 `/volume1/dev/` 자동 백업
- VPN 연결, 컨테이너 상태, GitHub 백업 여부 등을 매일 자동 점검

### ▶️ 절차적 복구 시나리오

1. NAS 장애 발생 시

   - DSM 로그인 불가 여부 확인 → 재부팅 및 SSH 접속 시도
   - Hyper Backup 또는 rsync로 백업된 `/volume1/dev/` 복원

2. 컨테이너 손상 또는 삭제 시

   - 해당 컨테이너 중지 및 제거 → Docker 로그로 원인 분석
   - `docker run` 또는 `docker-compose up -d`로 재배포
   - 데이터 볼륨에서 이전 설정 자동 복원됨

3. VPN 접속 오류 시

   - 공유기 포트(1194 UDP) 열림 상태 확인
   - 클라이언트 `.ovpn` 재배포 및 인증서 검토

4. 전체 재구축이 필요한 경우

   - `start-dev.sh` 실행으로 전체 DevOps 재구축 자동화
   - GitHub 저장소의 `.env`, `docker-compose.yml`, `config` 복사
   - `uptime-kuma`, `n8n`, `mcp` 상태 순차 확인

---

## 8. Sample Docker 포트 매핑 예시

```yaml
version: '3.8'
services:
  code:
    image: linuxserver/code-server
    ports:
      - "8484:8443"
    volumes:
      - /volume1/dev/code:/config
    restart: always

  n8n:
    image: n8nio/n8n
    ports:
      - "31001:5678"
    volumes:
      - /volume1/dev/n8n:/home/node/.n8n
    restart: always

  mcp:
    image: your/mcp-image
    ports:
      - "31002:31002"
    volumes:
      - /volume1/dev/mcp:/app
    restart: always
```

---

## 9. 결론 및 향후 실행 제안

- 포트 구조 및 VPN 구성 기준에 맞춰 자동화 도구 및 컨테이너 구조 최적화
- 모든 데이터/설정은 NAS 기준 `/volume1/dev/`에 고정 → 어디서든 재현 가능
- 동기화 기반 운영으로 로컬/원격 간 차이 최소화
- GPT 프롬프트, 자동화 플로우(n8n), 코드 서버 환경까지 모두 통합 관리
- 향후 `.devcontainer`, `.env.template`, `start-dev.sh`, `guide/`, `sync-dev.sh` 템플릿으로 생태계 복제 및 확산 가능
- 추가로 **절차 기반 복구 체계**를 통해 장애 발생 시 빠르고 안정적인 운영 복귀 가능

**본 문서 버전: GPM-ECO v2.8**

