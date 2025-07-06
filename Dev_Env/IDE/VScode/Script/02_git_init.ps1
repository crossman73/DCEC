@"
node_modules/
dist/
.env
logs/
"@ | Out-File ".gitignore" -Encoding utf8

if (-not (Test-Path ".git")) {
    git init
    git add .
    git commit -m "초기 구조 세팅"
    Write-Host "[INFO] Git 저장소 초기화 완료" -ForegroundColor Green
}
