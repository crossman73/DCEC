# NAS Docker 환경 설정 가이드
# \\192.168.0.5\docker 공유 폴더 활용

## 1. NAS 공유 폴더 구조
```
\\192.168.0.5\docker          # Windows 네트워크 드라이브
↓
/volume1/docker               # NAS 내부 경로
├── dev/                      # 개발 환경
│   ├── docker-compose.yml    # 메인 컴포즈 파일
│   ├── .env                  # 환경 변수
│   ├── config/               # 설정 파일들
│   ├── data/                 # 데이터 볼륨
│   └── logs/                 # 로그 파일들
├── production/               # 운영 환경 (나중에)
└── backup/                   # 백업 파일
```

## 2. 권장 디렉토리 구조
```
/volume1/docker/dev/
├── docker-compose.yml       # 메인 서비스 정의
├── .env                     # 환경 변수
├── config/
│   ├── n8n/                # n8n 설정
│   ├── gitea/              # gitea 설정
│   ├── code-server/        # VS Code 설정
│   ├── nginx/              # 리버스 프록시 설정
│   └── ssl/                # SSL 인증서
├── data/                   # 퍼시스턴트 데이터
│   ├── postgres/           # DB 데이터
│   ├── n8n/               # n8n 워크플로우
│   ├── gitea/             # Git 저장소
│   ├── uptime/            # 모니터링 데이터
│   └── portainer/         # 컨테이너 관리 데이터
├── logs/                  # 로그 파일
│   ├── n8n/
│   ├── gitea/
│   └── nginx/
└── scripts/               # 관리 스크립트
    ├── start.sh
    ├── stop.sh
    ├── backup.sh
    └── restore.sh
```

## 3. Docker Compose 구성 전략

### A. 볼륨 매핑 전략
- **Config**: `/volume1/docker/dev/config:/app/config`
- **Data**: `/volume1/docker/dev/data:/app/data`
- **Logs**: `/volume1/docker/dev/logs:/app/logs`

### B. 네트워크 구성
- **내부 통신**: `nas-dev-network` (bridge)
- **외부 접속**: 포트 매핑 + DSM 리버스 프록시

### C. 보안 고려사항
- 환경 변수로 민감 정보 관리
- Docker secrets 활용
- 네트워크 격리

## 4. 환경별 분리
- **dev/**: 개발/테스트 환경
- **staging/**: 스테이징 환경 (선택)
- **production/**: 운영 환경 (나중에)

## 5. 백업 전략
- **설정 백업**: config/ 폴더 Git 관리
- **데이터 백업**: data/ 폴더 스냅샷
- **자동 백업**: 스크립트 + cron job

이 구조로 설정하면 Windows에서 네트워크 드라이브로 쉽게 접근하면서도 NAS에서 체계적으로 Docker 환경을 관리할 수 있습니다.
