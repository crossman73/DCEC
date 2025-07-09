#!/bin/bash
set -e

# psql 명령어를 사용하여 데이터베이스와 사용자를 생성합니다.
# 이 스크립트는 docker-compose.yml에 정의된 환경 변수들을 사용합니다.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Gitea용 사용자 및 데이터베이스 생성
    CREATE USER $GITEA_DB_USER WITH PASSWORD '$GITEA_DB_PASSWORD';
    CREATE DATABASE gitea;
    GRANT ALL PRIVILEGES ON DATABASE gitea TO $GITEA_DB_USER;

    -- n8n용 사용자 및 데이터베이스 생성
    CREATE USER $N8N_DB_USER WITH PASSWORD '$N8N_DB_PASSWORD';
    CREATE DATABASE n8n;
    GRANT ALL PRIVILEGES ON DATABASE n8n TO $N8N_DB_USER;
EOSQL
