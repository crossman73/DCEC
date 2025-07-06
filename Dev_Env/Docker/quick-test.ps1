#!/usr/bin/env pwsh
# Quick NAS deployment test

$NasIP = "192.168.0.5"
$NasPort = "22022"
$NasUser = "crossman"
$RemoteDir = "/volume1/docker/dev"

Write-Host "=== Quick NAS Deployment Test ===" -ForegroundColor Green

# Step 1: Test SSH connection
Write-Host "1. Testing SSH connection..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "echo 'SSH OK'"

# Step 2: Create base directory
Write-Host "2. Creating base directory as root..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "sudo -i mkdir -p ${RemoteDir}"

# Step 3: Set permissions
Write-Host "3. Setting permissions..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "sudo -i chown -R ${NasUser}:users ${RemoteDir}"
ssh -p $NasPort "${NasUser}@${NasIP}" "sudo -i chmod -R 755 ${RemoteDir}"

# Step 4: Verify
Write-Host "4. Verifying directory..." -ForegroundColor Yellow
ssh -p $NasPort "${NasUser}@${NasIP}" "ls -la /volume1/docker/"

Write-Host "=== Test Complete ===" -ForegroundColor Green
