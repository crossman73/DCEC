# GPM-ECO v2.6 :: 지피 기반 AI 협업 생태계 구축 및 ASUS 공유기 + NAS 연동 최적 설정 가이드

## 1. 생태계 구축 흐름 개요 (전체 흐름)

1. ChatGPT 앱 설치 및 지피 기본 환경 구성
2. 지피 전용 프롬프트 및 시스템 설정값 입력 → 지속적 메모리 설정
3. MCP 기반 개발 환경 구성 (n8n, code-server, NAS 연계)
4. VPN + NAS 구성 확인 → 로컬-원격 통합 운영
5. 오류 감지 및 자가진단 루틴 포함 → 어디서든 복구 가능한 구조 구축
6. Git 기반 버전 관리 및 `.devcontainer`, `.env` 기반 재현성 확보
7. 동기화 기반 멀티 디바이스 운영 환경 확립 (노트북 ↔ NAS 간 실시간/예약 동기화)
8. 지속적 LLM 연동 및 커뮤니티 중심 협업 생태계 확대

---

## 2. 네트워크 환경 정보 요약 (무무님 기준)

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

## 3. 지피 앱 환경 최적 설정 (ChatGPT App)

### System Instruction

```
You are GPT-DevOps Assistant partnered with a human named Moomoo. You must:
- Ask clarifying questions before proceeding
- Maintain persistent memory of rules and actions
- Always document and version changes
- Automate all repeatable tasks (via n8n/MCP)
- Align responses in structured bullet format, no emoji
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

---

## 4. MCP 기반 DevOps 환경 초기 구축

- `n8n`, `code-server`, `mcp`, `uptime-kuma`는 각각 포트포워딩 완료
- NAS 내부 모든 컨테이너는 `/volume1/dev/` 하위에 데이터/설정 저장
- 외부 접속 도메인 예시:
  - `https://crossman.synology.me:31001` → n8n
  - `https://crossman.synology.me:31002` → mcp
  - `https://crossman.synology.me:8484` → code-server

---

## 5. VPN + NAS 구성 연동 점검

- OpenVPN 활성화 (포트 1194 UDP)
- `.ovpn` 또는 `wg.conf` 생성 후 노트북/모바일에 배포
- VPN 연결 후 `192.168.0.5` 대역의 NAS 서비스 접근 확인
- 공유기 방화벽 예외 및 포트 충돌 점검 필수

---

## 6. 동기화 기반 멀티 디바이스 운영 환경 (신규)

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

## 9. 결론 및 향후 실행 제안 (네트워크 및 동기화 기반 강화)

- 포트 구조 및 VPN 구성 기준에 맞춰 자동화 도구 및 컨테이너 구조 최적화
- 모든 데이터/설정은 NAS 기준 `/volume1/dev/`에 고정 → 어디서든 재현 가능
- 동기화 기반 운영으로 로컬/원격 간 차이 최소화
- GPT 프롬프트, 자동화 플로우(n8n), 코드 서버 환경까지 모두 통합 관리
- 향후 `.devcontainer`, `.env.template`, `start-dev.sh`, `guide/`, `sync-dev.sh` 템플릿으로 생태계 복제 및 확산 가능

**본 문서 버전: GPM-ECO v2.6**

