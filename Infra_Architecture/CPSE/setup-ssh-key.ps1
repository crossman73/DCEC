# 시놀로지 NAS SSH 키 등록 스크립트

param(
    [string]$NasIP = "192.168.0.5",
    [int]$SshPort = 22022,
    [string]$Username = "crossman"
)

$PublicKeyPath = "$env:USERPROFILE\.ssh\id_ed25519.pub"

Write-Host "=== 시놀로지 NAS SSH 키 등록 ===" -ForegroundColor Magenta

# 공개 키 확인
if (-not (Test-Path $PublicKeyPath)) {
    Write-Host "❌ SSH 공개 키가 없습니다: $PublicKeyPath" -ForegroundColor Red
    exit 1
}

$PublicKey = Get-Content $PublicKeyPath -Raw
Write-Host "✅ 공개 키 확인: $PublicKeyPath" -ForegroundColor Green

# SSH 명령어 생성
$SshCommands = @"
# .ssh 디렉토리 생성
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# authorized_keys 파일에 공개 키 추가
echo '$PublicKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 권한 확인
ls -la ~/.ssh/
echo "SSH 키 등록 완료!"
"@

Write-Host "🔧 다음 명령을 실행합니다:" -ForegroundColor Yellow
Write-Host $SshCommands -ForegroundColor Cyan

Write-Host "`n📋 수동 등록 절차:" -ForegroundColor Yellow
Write-Host "1. SSH로 NAS에 접속: ssh -p $SshPort $Username@$NasIP" -ForegroundColor White
Write-Host "2. 위의 명령어들을 순서대로 실행" -ForegroundColor White
Write-Host "3. 키 등록 후 새 터미널에서 키 인증 테스트" -ForegroundColor White

# 자동 실행 시도
$Response = Read-Host "`n자동으로 SSH 키를 등록하시겠습니까? (y/n)"
if ($Response -eq "y" -or $Response -eq "Y") {
    Write-Host "🚀 SSH 키 자동 등록 시작..." -ForegroundColor Green
    
    # SSH 키 등록 명령 실행
    $TempScript = [System.IO.Path]::GetTempFileName() + ".sh"
    $SshCommands | Set-Content $TempScript -Encoding UTF8
    
    try {
        Write-Host "📤 SSH를 통해 키 등록 중..." -ForegroundColor Yellow
        $Result = Get-Content $TempScript | ssh -p $SshPort "$Username@$NasIP" "bash -s"
        Write-Host "✅ SSH 키 등록 성공!" -ForegroundColor Green
        Write-Host $Result -ForegroundColor Cyan
    } catch {
        Write-Host "❌ SSH 키 등록 실패: $_" -ForegroundColor Red
        Write-Host "수동으로 등록해주세요." -ForegroundColor Yellow
    } finally {
        Remove-Item $TempScript -ErrorAction SilentlyContinue
    }
}

Write-Host "`n🧪 키 인증 테스트:" -ForegroundColor Yellow
Write-Host "ssh -p $SshPort $Username@$NasIP 'echo SSH 키 인증 성공!'" -ForegroundColor Cyan
