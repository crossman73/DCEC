# 간단한 NAS 배포 스크립트
Write-Host "NAS 배포 시작..." -ForegroundColor Green

# 설정
$NasIP = "192.168.0.5"
$NasPort = "22022"
$NasUser = "crossman"
$RemoteDir = "/volume1/docker/dev"

Write-Host "1. SSH 연결 테스트..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "echo 'SSH 연결 성공'"

Write-Host "2. 디렉토리 생성..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "sudo mkdir -p ${RemoteDir}/data ${RemoteDir}/config ${RemoteDir}/logs ${RemoteDir}/config/n8n"

Write-Host "3. 권한 설정..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "sudo chown -R ${NasUser}:users ${RemoteDir} && sudo chmod -R 755 ${RemoteDir}"

Write-Host "4. 파일 전송..." -ForegroundColor Yellow
scp -P $NasPort ".\.env" "${NasUser}@${NasIP}:${RemoteDir}/"
scp -P $NasPort ".\docker-compose.yml" "${NasUser}@${NasIP}:${RemoteDir}/"
scp -P $NasPort ".\nas-setup-complete.sh" "${NasUser}@${NasIP}:${RemoteDir}/"

Write-Host "5. 실행 권한 설정..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "chmod +x ${RemoteDir}/nas-setup-complete.sh"

Write-Host "6. Docker 서비스 시작..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker-compose down --remove-orphans"
ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker-compose up -d"

Write-Host "7. 서비스 상태 확인..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker-compose ps"

Write-Host "배포 완료!" -ForegroundColor Green
Write-Host "서비스 URL:" -ForegroundColor Cyan
Write-Host "n8n: http://192.168.0.5:31001" -ForegroundColor White
Write-Host "Gitea: http://192.168.0.5:8484" -ForegroundColor White
Write-Host "Code Server: http://192.168.0.5:3000" -ForegroundColor White
Write-Host "Uptime Kuma: http://192.168.0.5:31003" -ForegroundColor White
Write-Host "Portainer: http://192.168.0.5:9000" -ForegroundColor White
