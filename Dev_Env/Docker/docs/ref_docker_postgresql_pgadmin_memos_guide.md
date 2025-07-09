# Synology NAS DSM 7.2 PostgreSQL + pgAdmin + Memos Docker CLI 배포 메뉴얼

> 본 메뉴얼은 Synology NAS DSM 7.2 환경에서 Portainer 없이 순수 Docker CLI로 PostgreSQL, pgAdmin, Memos를 설치하고 연동하는 초심자 가이드입니다.

---

## 📁 1. 디렉토리 구조 준비

```bash
mkdir -p /volume1/docker/postgresql
mkdir -p /volume1/docker/pgadmin
mkdir -p /volume1/docker/memos/db
mkdir -p /volume1/docker/memos/data
```

---

## 🐘 2. PostgreSQL 설치

```bash
docker run -d \
  --name postgresql \
  -e POSTGRES_USER=root \
  -e POSTGRES_PASSWORD=ChangeMe123 \
  -e POSTGRES_DB=my_database \
  -v /volume1/docker/postgresql:/var/lib/postgresql/data \
  -p 5432:5432 \
  --restart unless-stopped \
  postgres:16
```

- 사용자: `root`
- 비밀번호: `ChangeMe123`
- 데이터 볼륨: `/volume1/docker/postgresql`

---

## 🖥️ 3. pgAdmin 설치

```bash
docker run -d \
  --name pgadmin \
  -e PGADMIN_DEFAULT_EMAIL=you@example.com \
  -e PGADMIN_DEFAULT_PASSWORD=AdminPass123 \
  -v /volume1/docker/pgadmin:/var/lib/pgadmin \
  -p 5050:5050 \
  --restart unless-stopped \
  dpage/pgadmin4
```

- 접속 주소: `http://<NAS_IP>:5050`
- 로그인 후 PostgreSQL 서버 등록 필요

---

## 📝 4. Memos + PostgreSQL 연동

### 4.1 Memos용 PostgreSQL

```bash
docker run -d \
  --name memos-db \
  -e POSTGRES_USER=memosuser \
  -e POSTGRES_PASSWORD=memospass \
  -e POSTGRES_DB=memos \
  -v /volume1/docker/memos/db:/var/lib/postgresql/data \
  -p 5440:5432 \
  --restart unless-stopped \
  postgres:16
```

### 4.2 Memos 컨테이너

```bash
docker run -d \
  --name memos \
  -e MEMOS_DRIVER=postgres \
  -e MEMOS_DSN="postgresql://memosuser:memospass@memos-db:5432/memos?sslmode=disable" \
  -v /volume1/docker/memos/data:/var/opt/memos \
  -p 5235:5230 \
  --restart unless-stopped \
  ghcr.io/usememos/memos:latest
```

- 접속 주소: `http://<NAS_IP>:5235`
- 최초 접속 시 관리자 계정 생성

---

## 🔍 상태 확인 및 관리 명령어

```bash
docker ps                            # 실행중 컨테이너 목록
docker logs -f memos                 # Memos 로그 보기
docker exec -it postgresql bash      # PostgreSQL 쉘 접근
docker exec -it postgresql psql -U root -d my_database   # DB 접속
```

---

## 📦 백업 및 복원

### PostgreSQL 백업

```bash
docker exec postgresql pg_dump -U root my_database > /volume1/docker/postgresql/mydb_$(date +%Y%m%d).sql
```

### PostgreSQL 복원

```bash
cat /volume1/docker/postgresql/mydb_20250709.sql | docker exec -i postgresql psql -U root -d my_database
```

---

## 🧱 디렉토리 구조 요약

```bash
/volume1/docker/
├── postgresql/         # PostgreSQL 데이터
├── pgadmin/            # pgAdmin 설정
└── memos/
    ├── db/             # Memos DB
    └── data/           # Memos 노트 데이터
```

---

## ✅ 구성 요약

| 서비스 | 컨테이너명 | 포트 | 설명 |
|--------|------------|------|------|
| PostgreSQL | postgresql | 5432 | 일반 DB |
| pgAdmin | pgadmin | 5050 | DB GUI |
| Memos DB | memos-db | 5440 | Memos 전용 DB |
| Memos | memos | 5235 | 메모 웹앱 |

---

## 🔐 보안 권장 사항

- NAS 방화벽 활성화 및 포트 제한
- 외부 접속 시 VPN 사용 권장
- pgAdmin은 NAS 내부에서만 접근 권장
- 자동 백업 스크립트 설정 권장 (cron 사용)

---

## 📌 참고 자료

- https://mariushosting.com/how-to-install-postgresql-on-your-synology-nas/
- https://mariushosting.com/how-to-install-memos-with-postgresql-on-your-synology-nas/
- https://jh-industry.tistory.com/25
- https://jh-industry.tistory.com/177
