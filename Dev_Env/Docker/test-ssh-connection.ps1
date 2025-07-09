$NasIP = "192.168.0.5"
$NasPort = "22022"
$NasUser = "crossman"
$SshKeyPath = "$env:USERPROFILE\.ssh\id_rsa"

Write-Host "Attempting SSH connection to $NasUser@${NasIP}:${NasPort} using key $SshKeyPath"

try {
    # Test SSH connection by running a simple command on the remote host
    $result = ssh -i $SshKeyPath -p $NasPort "${NasUser}@${NasIP}" "echo 'SSH connection successful'"
    if ($LASTEXITCODE -eq 0 -and $result -like "*SSH connection successful*") {
        Write-Host "SSH connection successful!" -ForegroundColor Green
    } else {
        Write-Host "SSH connection failed. Result: $result" -ForegroundColor Red
        Write-Host "Error Code: $LASTEXITCODE" -ForegroundColor Red
    }
} catch {
    Write-Host "An error occurred during SSH connection: $($_.Exception.Message)" -ForegroundColor Red
}
