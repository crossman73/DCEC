$folders = @("src", "src/agents", "src/config", "logs", ".vscode")
foreach ($dir in $folders) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
        Write-Host "[INFO] $dir 디렉토리 생성됨" -ForegroundColor Green
    }
}
