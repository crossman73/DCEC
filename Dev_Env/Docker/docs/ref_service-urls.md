# NAS Docker Services URLs

## 내부 네트워크 접속 (포트 직접 접속)
- **n8n**: http://192.168.0.5:31001
- **MCP Server**: http://192.168.0.5:31002
- **VS Code**: http://192.168.0.5:8484
- **Gitea**: http://192.168.0.5:3000
- **Uptime Kuma**: http://192.168.0.5:31003
- **Portainer**: http://192.168.0.5:9000

## 외부 서브도메인 접속 (DSM 리버스 프록시 설정 후)
- **n8n**: https://n8n.crossman.synology.me
- **MCP Server**: https://mcp.crossman.synology.me
- **VS Code**: https://code.crossman.synology.me
- **Gitea**: https://git.crossman.synology.me
- **Uptime Kuma**: https://uptime.crossman.synology.me
- **Portainer**: https://portainer.crossman.synology.me

## 관리자 정보
- **기본 사용자명**: admin
- **기본 비밀번호**: changeme123
- **Gitea SSH 포트**: 2222

## 다음 단계
1. DSM 리버스 프록시에서 각 서비스 규칙 추가
2. SSL 인증서 설정
3. 방화벽 및 포트포워딩 설정
4. 서비스별 초기 설정 완료

생성 시간: 07/07/2025 00:43:14
