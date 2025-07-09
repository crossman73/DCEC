# NAS Docker Services Manual Setup Guide
# NAS에서 직접 실행하는 Docker 서비스 설정 가이드

## 1. NAS SSH 접속
```bash
ssh -p 22022 crossman@192.168.0.5
```

## 2. Docker Compose 설치 확인 및 설치
```bash
# Docker Compose 버전 확인
docker-compose --version

# 설치되지 않은 경우 설치
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

## 3. 작업 디렉토리 생성
```bash
sudo mkdir -p /volume1/dev/docker
sudo chown -R crossman:users /volume1/dev/docker
cd /volume1/dev/docker
```

## 4. Docker Compose 파일 생성
```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

networks:
  nas-subdomain-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  postgres_data:
  gitea_data:
  uptime_data:
  portainer_data:
  n8n_data:
  vscode_config:

services:
  # PostgreSQL Database for n8n and Gitea
  postgres:
    image: postgres:16
    container_name: nas-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: n8n
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: changeme123
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - nas-subdomain-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n -d n8n"]
      interval: 10s
      timeout: 5s
      retries: 5

  # n8n Workflow Automation
  n8n:
    image: docker.n8n.io/n8nio/n8n:latest
    container_name: nas-n8n
    restart: unless-stopped
    ports:
      - "31001:5678"
    environment:
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: postgres
      DB_POSTGRESDB_PORT: 5432
      DB_POSTGRESDB_DATABASE: n8n
      DB_POSTGRESDB_USER: n8n
      DB_POSTGRESDB_PASSWORD: changeme123
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_BASIC_AUTH_USER: admin
      N8N_BASIC_AUTH_PASSWORD: changeme123
      WEBHOOK_URL: https://n8n.crossman.synology.me
      N8N_BASE_URL: https://n8n.crossman.synology.me
      N8N_SECURE_COOKIE: "false"
      GENERIC_TIMEZONE: Asia/Seoul
      N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE: "true"
      N8N_METRICS: "true"
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - nas-subdomain-network
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

  # MCP Server for n8n integration
  mcp-server:
    image: leonardsellem/n8n-mcp-server:latest
    container_name: nas-mcp-server
    restart: unless-stopped
    ports:
      - "31002:31002"
    environment:
      N8N_API_URL: http://n8n:5678/api/v1
      N8N_API_KEY: "default-api-key"
      MCP_PORT: 31002
      MCP_HOST: "0.0.0.0"
      NODE_ENV: production
      DEBUG: "mcp:*"
    depends_on:
      n8n:
        condition: service_healthy
    networks:
      - nas-subdomain-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:31002/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # VS Code Server (Web IDE)
  code-server:
    image: codercom/code-server:latest
    container_name: nas-code-server
    restart: unless-stopped
    ports:
      - "8484:8080"
    environment:
      PASSWORD: changeme123
      SUDO_PASSWORD: changeme123
    volumes:
      - /volume1/dev:/home/coder/workspace
      - vscode_config:/home/coder/.config
    user: "1000:1000"
    networks:
      - nas-subdomain-network
    command: >
      --bind-addr 0.0.0.0:8080
      --auth password
      --disable-telemetry
      --disable-update-check
      /home/coder/workspace

  # Gitea Git Server
  gitea:
    image: gitea/gitea:latest
    container_name: nas-gitea
    restart: unless-stopped
    ports:
      - "3000:3000"
      - "2222:22"
    environment:
      USER_UID: 1000
      USER_GID: 1000
      GITEA__database__DB_TYPE: postgres
      GITEA__database__HOST: postgres:5432
      GITEA__database__NAME: gitea
      GITEA__database__USER: gitea
      GITEA__database__PASSWD: changeme123
      GITEA__server__DOMAIN: git.crossman.synology.me
      GITEA__server__SSH_DOMAIN: git.crossman.synology.me
      GITEA__server__ROOT_URL: https://git.crossman.synology.me
    volumes:
      - gitea_data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    networks:
      - nas-subdomain-network
    depends_on:
      - postgres

  # Uptime Kuma Monitoring
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: nas-uptime-kuma
    restart: unless-stopped
    ports:
      - "31003:3001"
    volumes:
      - uptime_data:/app/data
    networks:
      - nas-subdomain-network

  # Portainer Container Management
  portainer:
    image: portainer/portainer-ce:latest
    container_name: nas-portainer
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    networks:
      - nas-subdomain-network

  # Watchtower for Auto Updates
  watchtower:
    image: containrrr/watchtower:latest
    container_name: nas-watchtower
    restart: unless-stopped
    environment:
      WATCHTOWER_POLL_INTERVAL: 3600
      WATCHTOWER_CLEANUP: "true"
      WATCHTOWER_INCLUDE_RESTARTING: "true"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - nas-subdomain-network
EOF
```

## 5. 환경 설정 파일 생성
```bash
cat > .env << 'EOF'
# Docker Services Environment Configuration
BASE_DOMAIN=crossman.synology.me
DOCKER_NETWORK_NAME=nas-subdomain-network
DOCKER_SUBNET=172.20.0.0/16
N8N_API_KEY=your-n8n-api-key-here
N8N_PASSWORD=changeme123
VSCODE_PASSWORD=changeme123
POSTGRES_PASSWORD=changeme123
SSL_EMAIL=admin@crossman.synology.me
EOF
```

## 6. Docker 서비스 시작
```bash
# 이미지 다운로드
docker-compose pull

# 서비스 시작
docker-compose up -d

# 서비스 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs -f
```

## 7. 서비스 상태 확인
```bash
# 개별 서비스 확인
curl -I http://localhost:31001  # n8n
curl -I http://localhost:31002  # MCP Server
curl -I http://localhost:8484   # VS Code
curl -I http://localhost:3000   # Gitea
curl -I http://localhost:31003  # Uptime Kuma
curl -I http://localhost:9000   # Portainer
```

## 8. 외부 접속 테스트
- **n8n**: http://192.168.0.5:31001
- **MCP Server**: http://192.168.0.5:31002
- **VS Code**: http://192.168.0.5:8484
- **Gitea**: http://192.168.0.5:3000
- **Uptime Kuma**: http://192.168.0.5:31003
- **Portainer**: http://192.168.0.5:9000

## 9. 문제 해결 명령어
```bash
# 서비스 재시작
docker-compose restart

# 특정 서비스 재시작
docker-compose restart n8n

# 로그 확인
docker-compose logs service-name

# 컨테이너 상태 확인
docker ps -a

# 네트워크 확인
docker network ls

# 볼륨 확인
docker volume ls
```

## 10. 다음 단계
1. 모든 서비스가 정상 동작하는지 확인
2. DSM 리버스 프록시에 서브도메인 규칙 추가
3. SSL 인증서 설정
4. 외부 접속 테스트
