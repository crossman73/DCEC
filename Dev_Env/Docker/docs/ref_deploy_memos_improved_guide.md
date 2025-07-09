
# 📘 NAS용 PostgreSQL + pgAdmin + Memos Docker CLI 배포 자동화 스크립트 (PowerShell)

이 문서는 Synology NAS DSM 7.2 환경에서 PowerShell 기반으로 PostgreSQL, pgAdmin, Memos를 자동으로 배포하는 CLI 스크립트 개선안입니다.

---

## 📂 디렉토리 구조 자동 생성

```powershell
mkdir -p /volume1/docker/postgresql
mkdir -p /volume1/docker/pgadmin
mkdir -p /volume1/docker/memos/db
mkdir -p /volume1/docker/memos/data
```

---

## 🐘 PostgreSQL 컨테이너 배포

```powershell
docker run -d `
  --name postgresql `
  -e POSTGRES_USER=root `
  -e POSTGRES_PASSWORD=ChangeMe123 `
  -e POSTGRES_DB=my_database `
  -v /volume1/docker/postgresql:/var/lib/postgresql/data `
  -p 5432:5432 `
  --restart unless-stopped `
  postgres:16
```

- 사용자: `root`
- 포트: `5432`

---

## 🖥️ pgAdmin 컨테이너 배포

```powershell
docker run -d `
  --name pgadmin `
  -e PGADMIN_DEFAULT_EMAIL=you@example.com `
  -e PGADMIN_DEFAULT_PASSWORD=AdminPass123 `
  -v /volume1/docker/pgadmin:/var/lib/pgadmin `
  -p 5050:5050 `
  --restart unless-stopped `
  dpage/pgadmin4
```

- 접속: `http://<NAS_IP>:5050`

---

## 📝 Memos 전용 PostgreSQL 및 앱 배포

### Memos-DB

```powershell
docker run -d `
  --name memos-db `
  -e POSTGRES_USER=memosuser `
  -e POSTGRES_PASSWORD=memospass `
  -e POSTGRES_DB=memos `
  -v /volume1/docker/memos/db:/var/lib/postgresql/data `
  -p 5440:5432 `
  --restart unless-stopped `
  postgres:16
```

### Memos 컨테이너

```powershell
docker run -d `
  --name memos `
  -e MEMOS_DRIVER=postgres `
  -e MEMOS_DSN="postgresql://memosuser:memospass@memos-db:5432/memos?sslmode=disable" `
  -v /volume1/docker/memos/data:/var/opt/memos `
  -p 5235:5230 `
  --restart unless-stopped `
  ghcr.io/usememos/memos:latest
```

- 접속: `http://<NAS_IP>:5235`

---

## 📦 자동 로그 기록 및 상태 출력

- 로그 파일: `/volume1/dev/logs/YYYYMMDDHHMMSS_deploy-memos.log`
- 실행 결과, 컨테이너 상태, 포트 정보 자동 기록

---

## ✅ 통합된 컨테이너 구성 요약

| 서비스       | 컨테이너명  | 포트   | 설명           |
|--------------|--------------|--------|----------------|
| PostgreSQL   | postgresql   | 5432   | 일반 DB        |
| pgAdmin      | pgadmin      | 5050   | GUI 관리 도구  |
| Memos-DB     | memos-db     | 5440   | Memos 전용 DB  |
| Memos        | memos        | 5235   | 메모 웹 앱     |

---

## 🧪 사용 방법

```powershell
# PowerShell 실행
pwsh

# 스크립트 실행
./deploy-nas-final.ps1
```

---

## 🧱 디렉토리 구조

```bash
/volume1/docker/
├── postgresql/         # PostgreSQL 데이터
├── pgadmin/            # pgAdmin 설정
└── memos/
    ├── db/             # Memos용 DB
    └── data/           # Memos 앱 데이터
```

---

## 📌 참고 링크

- https://mariushosting.com/how-to-install-postgresql-on-your-synology-nas/
- https://mariushosting.com/how-to-install-memos-with-postgresql-on-your-synology-nas/
- https://jh-industry.tistory.com/25
- https://jh-industry.tistory.com/177
