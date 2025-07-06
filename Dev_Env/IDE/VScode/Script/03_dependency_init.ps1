if (-not (Test-Path "./package.json")) {
    pnpm init
}
pnpm add typescript ts-node @types/node -D
pnpm exec tsc --init
Write-Host "[INFO] TypeScript 개발 환경 구성 완료" -ForegroundColor Green
