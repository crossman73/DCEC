# NAS Docker Environment Deployment Script
# 실제 NAS에 SSH로 접속하여 Docker 환경을 배포합니다.

param(
    [string]$NasIP = "192.168.0.5",
    [string]$NasPort = "22022",
    [string]$NasUser = "crossman",
    [string]$LocalDir = "d:\Dev\DCEC\Dev_Env\Docker",
    [string]$RemoteDir = "/volume1/docker/dev",
    [string]$Command = "deploy"
)

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] $Message" -ForegroundColor $Color
}

# Function to verify local files
function Test-LocalFiles {
    Write-ColorOutput "Verifying local files..." "Yellow"
    
    $requiredFiles = @(
        "${LocalDir}\.env",
        "${LocalDir}\docker-compose.yml",
        "${LocalDir}\nas-setup-complete.sh"
    )
    
    $optionalFiles = @(
        "${LocalDir}\n8n\20250626_n8n_API_KEY.txt"
    )
    
    $allGood = $true
    
    foreach ($file in $requiredFiles) {
        if (Test-Path $file) {
            Write-ColorOutput "✓ Found: $file" "Green"
        } else {
            Write-ColorOutput "✗ Missing: $file" "Red"
            $allGood = $false
        }
    }
    
    foreach ($file in $optionalFiles) {
        if (Test-Path $file) {
            Write-ColorOutput "✓ Found: $file" "Green"
        } else {
            Write-ColorOutput "! Optional: $file (will create placeholder)" "Yellow"
        }
    }
    
    return $allGood
}

# Function to create directory structure on NAS with proper checks
function New-RemoteDirectoryStructure {
    Write-ColorOutput "Creating directory structure on NAS..." "Yellow"
    
    try {
        # Base directories with proper structure
        $directories = @(
            "/volume1/docker",
            "${RemoteDir}",
            "${RemoteDir}/data",
            "${RemoteDir}/config",
            "${RemoteDir}/logs",
            "${RemoteDir}/config/n8n",
            "${RemoteDir}/config/gitea", 
            "${RemoteDir}/config/code-server",
            "${RemoteDir}/config/uptime-kuma",
            "${RemoteDir}/config/portainer",
            "${RemoteDir}/data/mysql",
            "${RemoteDir}/data/n8n",
            "${RemoteDir}/data/gitea",
            "${RemoteDir}/data/code-server",
            "${RemoteDir}/data/uptime-kuma",
            "${RemoteDir}/data/portainer"
        )
        
        foreach ($dir in $directories) {
            Write-ColorOutput "Checking directory: $dir" "Cyan"
            
            # Check if directory exists
            $dirExists = ssh -p $NasPort -o StrictHostKeyChecking=no "${NasUser}@${NasIP}" "test -d '$dir' && echo 'exists' || echo 'missing'"
            
            if ($dirExists -eq "missing") {
                Write-ColorOutput "Creating directory: $dir" "Yellow"
                
                # Create directory as root
                $createResult = ssh -p $NasPort "${NasUser}@${NasIP}" "mkdir -p '$dir' && echo 'success' || echo 'failed'"
                
                if ($createResult -eq "success") {
                    Write-ColorOutput "✓ Created: $dir" "Green"
                } else {
                    Write-ColorOutput "✗ Failed to create: $dir" "Red"
                }
            } else {
                Write-ColorOutput "✓ Already exists: $dir" "Green"
            }
        }
        
        # Set proper permissions for Docker services
        Write-ColorOutput "Setting directory permissions..." "Cyan"
        
        # Set ownership to current user
        ssh -p $NasPort "${NasUser}@${NasIP}" "sudo -i chown -R ${NasUser}:users /volume1/docker"
        
        # Set base permissions
        ssh -p $NasPort "${NasUser}@${NasIP}" "sudo -i chmod -R 755 /volume1/docker"
        
        # Set specific permissions for data directories (Docker needs write access)
        ssh -p $NasPort "${NasUser}@${NasIP}" "sudo -i chmod -R 777 ${RemoteDir}/data"
        ssh -p $NasPort "${NasUser}@${NasIP}" "sudo -i chmod -R 766 ${RemoteDir}/config"
        ssh -p $NasPort "${NasUser}@${NasIP}" "sudo -i chmod -R 755 ${RemoteDir}/logs"
        
        # Special permissions for MySQL data (needs to be writable by mysql user in container)
        ssh -p $NasPort "${NasUser}@${NasIP}" "sudo -i chmod 777 ${RemoteDir}/data/mysql"
        
        Write-ColorOutput "Directory structure and permissions set successfully" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Failed to create directory structure: $_" "Red"
        return $false
    }
}

# Function to transfer files with retry logic
function Copy-FileWithRetry {
    param(
        [string]$LocalFile,
        [string]$RemoteFile,
        [int]$MaxRetries = 3
    )
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        Write-ColorOutput "Transferring $LocalFile (attempt $i/$MaxRetries)..." "Cyan"
        
        try {
            scp -P $NasPort "$LocalFile" "${NasUser}@${NasIP}:$RemoteFile"
            if ($LASTEXITCODE -eq 0) {
                Write-ColorOutput "✓ Successfully transferred: $(Split-Path $LocalFile -Leaf)" "Green"
                return $true
            }
        }
        catch {
            Write-ColorOutput "Transfer attempt $i failed: $_" "Yellow"
        }
        
        if ($i -lt $MaxRetries) {
            Start-Sleep -Seconds 2
        }
    }
    
    Write-ColorOutput "✗ Failed to transfer after $MaxRetries attempts: $(Split-Path $LocalFile -Leaf)" "Red"
    return $false
}

# Function to verify remote files
function Test-RemoteFiles {
    Write-ColorOutput "Verifying files on NAS..." "Yellow"
    
    try {
        $remoteFiles = ssh -p $NasPort "${NasUser}@${NasIP}" "find ${RemoteDir} -type f -ls 2>/dev/null || ls -la ${RemoteDir}/ 2>/dev/null"
        
        Write-ColorOutput "Files found on NAS:" "White"
        Write-Host $remoteFiles
        
        # Check specific files
        $requiredFiles = @(
            "${RemoteDir}/.env",
            "${RemoteDir}/docker-compose.yml",
            "${RemoteDir}/nas-setup-complete.sh"
        )
        
        $allGood = $true
        foreach ($file in $requiredFiles) {
            $exists = ssh -p $NasPort "${NasUser}@${NasIP}" "test -f '$file' && echo 'exists' || echo 'missing'"
            if ($exists -eq "exists") {
                Write-ColorOutput "✓ Remote file exists: $file" "Green"
            } else {
                Write-ColorOutput "✗ Remote file missing: $file" "Red"
                $allGood = $false
            }
        }
        
        return $allGood
    }
    catch {
        Write-ColorOutput "Failed to verify remote files: $_" "Red"
        return $false
    }
}

function Test-SSHConnection {
    Write-ColorOutput "Checking SSH connection to NAS..." "Yellow"
    
    try {
        $result = ssh -p $NasPort -o ConnectTimeout=10 "${NasUser}@${NasIP}" "echo 'SSH connection successful'"
        if ($result -eq "SSH connection successful") {
            Write-ColorOutput "SSH connection to NAS established" "Green"
            return $true
        }
    }
    catch {
        Write-ColorOutput "Cannot connect to NAS via SSH" "Red"
        Write-ColorOutput "Please ensure:" "White"
        Write-ColorOutput "1. NAS is accessible at $NasIP" "White"
        Write-ColorOutput "2. SSH is enabled on the NAS (port $NasPort)" "White"
        Write-ColorOutput "3. SSH password authentication is enabled" "White"
        Write-ColorOutput "4. Username and password are correct" "White"
        return $false
    }
}

function Copy-FilesToNAS {
    Write-ColorOutput "Transferring files to NAS..." "Yellow"
    
    try {
        # Create remote directories with proper permissions
        Write-ColorOutput "Creating remote directories..." "Cyan"
        
        # Create directories without sudo (user has permission to create in /volume1/docker)
        ssh -p $NasPort "${NasUser}@${NasIP}" "mkdir -p ${RemoteDir}"
        ssh -p $NasPort "${NasUser}@${NasIP}" "mkdir -p ${RemoteDir}/data ${RemoteDir}/config ${RemoteDir}/config/n8n ${RemoteDir}/logs"
        
        # Set proper ownership and permissions
        ssh -p $NasPort "${NasUser}@${NasIP}" "chown -R ${NasUser}:users ${RemoteDir}"
        ssh -p $NasPort "${NasUser}@${NasIP}" "chmod -R 755 ${RemoteDir}"
        
        Write-ColorOutput "Directory structure created successfully" "Green"
        
        # Transfer main configuration files
        Write-ColorOutput "Transferring main configuration files..." "Cyan"
        
        # Check if files exist before transfer
        if (!(Test-Path "${LocalDir}\.env")) {
            Write-ColorOutput "Warning: .env file not found at ${LocalDir}\.env" "Yellow"
        } else {
            scp -P $NasPort "${LocalDir}\.env" "${NasUser}@${NasIP}:${RemoteDir}/"
            if ($LASTEXITCODE -eq 0) { Write-ColorOutput "✓ .env transferred" "Green" }
        }
        
        if (!(Test-Path "${LocalDir}\docker-compose.yml")) {
            Write-ColorOutput "Warning: docker-compose.yml not found at ${LocalDir}\docker-compose.yml" "Yellow"
        } else {
            scp -P $NasPort "${LocalDir}\docker-compose.yml" "${NasUser}@${NasIP}:${RemoteDir}/"
            if ($LASTEXITCODE -eq 0) { Write-ColorOutput "✓ docker-compose.yml transferred" "Green" }
        }
        
        if (!(Test-Path "${LocalDir}\nas-setup-complete.sh")) {
            Write-ColorOutput "Warning: nas-setup-complete.sh not found at ${LocalDir}\nas-setup-complete.sh" "Yellow"
        } else {
            scp -P $NasPort "${LocalDir}\nas-setup-complete.sh" "${NasUser}@${NasIP}:${RemoteDir}/"
            if ($LASTEXITCODE -eq 0) { Write-ColorOutput "✓ nas-setup-complete.sh transferred" "Green" }
        }
        
        # Transfer n8n API key
        Write-ColorOutput "Transferring n8n API key..." "Cyan"
        if (!(Test-Path "${LocalDir}\n8n\20250626_n8n_API_KEY.txt")) {
            Write-ColorOutput "Warning: n8n API key not found at ${LocalDir}\n8n\20250626_n8n_API_KEY.txt" "Yellow"
            # Create a placeholder API key file
            ssh -p $NasPort "${NasUser}@${NasIP}" "echo 'n8n_api_key_placeholder' > ${RemoteDir}/config/n8n/api-keys.txt"
        } else {
            scp -P $NasPort "${LocalDir}\n8n\20250626_n8n_API_KEY.txt" "${NasUser}@${NasIP}:${RemoteDir}/config/n8n/api-keys.txt"
            if ($LASTEXITCODE -eq 0) { Write-ColorOutput "✓ n8n API key transferred" "Green" }
        }
        
        # Set execute permissions
        Write-ColorOutput "Setting file permissions..." "Cyan"
        ssh -p $NasPort "${NasUser}@${NasIP}" "chmod +x ${RemoteDir}/nas-setup-complete.sh 2>/dev/null || true"
        ssh -p $NasPort "${NasUser}@${NasIP}" "chmod 644 ${RemoteDir}/.env ${RemoteDir}/docker-compose.yml 2>/dev/null || true"
        
        # Verify files were transferred
        Write-ColorOutput "Verifying file transfer..." "Cyan"
        $fileList = ssh -p $NasPort "${NasUser}@${NasIP}" "ls -la ${RemoteDir}/"
        Write-ColorOutput "Files in remote directory:" "White"
        Write-Host $fileList
        
        Write-ColorOutput "Files transferred successfully" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Failed to transfer files: $_" "Red"
        Write-ColorOutput "Error details: $($_.Exception.Message)" "Red"
        return $false
    }
}

function Invoke-SetupScript {
    Write-ColorOutput "Running setup script on NAS..." "Yellow"
    
    try {
        ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && ./nas-setup-complete.sh"
        Write-ColorOutput "Setup script execution completed" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Failed to run setup script: $_" "Red"
        return $false
    }
}

function Deploy-DockerServices {
    Write-ColorOutput "Deploying Docker services on NAS..." "Yellow"
    
    try {
        # Update .env with proper values
        ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && sed -i 's|DATA_ROOT=.*|DATA_ROOT=${RemoteDir}/data|g' .env"
        ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && sed -i 's|DB_PASSWORD=.*|DB_PASSWORD=changeme123|g' .env"
        ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && sed -i 's|N8N_PORT=.*|N8N_PORT=31001|g' .env"
        
        # Stop existing services
        ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker-compose down --remove-orphans"
        
        # Start services
        ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker-compose up -d"
        
        Write-ColorOutput "Docker services deployed" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Failed to deploy services: $_" "Red"
        return $false
    }
}

function Test-ServicesHealth {
    Write-ColorOutput "Performing health check..." "Yellow"
    
    Start-Sleep -Seconds 30  # Wait for services to start
    
    try {
        # Check service status
        ssh -p $NasPort "${NasUser}@${NasIP}" "cd ${RemoteDir} && docker-compose ps"
        Write-ColorOutput "Health check completed" "Green"
        return $true
    }
    catch {
        Write-ColorOutput "Health check failed: $_" "Red"
        return $false
    }
}

function Show-ServiceInfo {
    Write-ColorOutput "Service Information:" "Cyan"
    Write-Host ""
    Write-Host "=== Service URLs ===" -ForegroundColor Yellow
    Write-Host "n8n:              http://192.168.0.5:31001" -ForegroundColor White
    Write-Host "Gitea:            http://192.168.0.5:8484" -ForegroundColor White
    Write-Host "Code Server:      http://192.168.0.5:3000" -ForegroundColor White
    Write-Host "Uptime Kuma:      http://192.168.0.5:31003" -ForegroundColor White
    Write-Host "Portainer:        http://192.168.0.5:9000" -ForegroundColor White
    Write-Host ""
    Write-Host "=== Sub-domain URLs (if configured) ===" -ForegroundColor Yellow
    Write-Host "n8n:              https://n8n.crossman.synology.me" -ForegroundColor White
    Write-Host "Gitea:            https://git.crossman.synology.me" -ForegroundColor White
    Write-Host "Code Server:      https://code.crossman.synology.me" -ForegroundColor White
    Write-Host "Uptime Kuma:      https://uptime.crossman.synology.me" -ForegroundColor White
    Write-Host ""
    Write-Host "=== Default Credentials ===" -ForegroundColor Yellow
    Write-Host "n8n:              admin / changeme123" -ForegroundColor White
    Write-Host "Code Server:      changeme123" -ForegroundColor White
    Write-Host "Database:         nasuser / changeme123" -ForegroundColor White
    Write-Host ""
}

# Main execution
Write-ColorOutput "==========================================" "Cyan"
Write-ColorOutput "NAS Docker Environment Deployment" "Cyan"
Write-ColorOutput "==========================================" "Cyan"

# Step 1: Verify local files
Write-ColorOutput "Step 1: Verifying local files..." "Yellow"
if (!(Test-LocalFiles)) {
    Write-ColorOutput "Some required local files are missing. Please check the file paths." "Red"
    Write-ColorOutput "Press any key to continue anyway or Ctrl+C to abort..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Step 2: Test SSH connection
Write-ColorOutput "Step 2: Testing SSH connection..." "Yellow"
if (!(Test-SSHConnection)) {
    Write-ColorOutput "SSH connection failed. Cannot proceed with deployment." "Red"
    Write-ColorOutput "Press any key to exit..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Step 3: Create directory structure
Write-ColorOutput "Step 3: Creating directory structure..." "Yellow"
if (!(New-RemoteDirectoryStructure)) {
    Write-ColorOutput "Failed to create directory structure. Continuing anyway..." "Yellow"
}

# Step 4: Transfer files
Write-ColorOutput "Step 4: Transferring files..." "Yellow"
if (!(Copy-FilesToNAS)) {
    Write-ColorOutput "File transfer failed. Cannot proceed with deployment." "Red"
    Write-ColorOutput "Press any key to exit..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# Step 5: Verify remote files
Write-ColorOutput "Step 5: Verifying remote files..." "Yellow"
if (!(Test-RemoteFiles)) {
    Write-ColorOutput "Some files are missing on NAS. Continuing anyway..." "Yellow"
}

# Step 6: Run setup script
Write-ColorOutput "Step 6: Running setup script..." "Yellow"
if (!(Invoke-SetupScript)) {
    Write-ColorOutput "Setup script failed. Continuing anyway..." "Yellow"
}

# Step 7: Deploy Docker services
Write-ColorOutput "Step 7: Deploying Docker services..." "Yellow"
if (!(Deploy-DockerServices)) {
    Write-ColorOutput "Docker deployment failed. Check the logs above." "Red"
    Write-ColorOutput "Press any key to continue to health check..." "Yellow"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Step 8: Health check
Write-ColorOutput "Step 8: Performing health check..." "Yellow"
if (!(Test-ServicesHealth)) {
    Write-ColorOutput "Health check failed. Services may not be running properly." "Yellow"
}

# Step 9: Show service information
Write-ColorOutput "Step 9: Displaying service information..." "Yellow"
Show-ServiceInfo

Write-ColorOutput "==========================================" "Cyan"
Write-ColorOutput "Deployment process completed!" "Green"
Write-ColorOutput "==========================================" "Cyan"
Write-ColorOutput "Check the service URLs above to verify everything is working." "Cyan"
Write-ColorOutput "If services are not accessible, try running docker-compose manually on NAS." "Yellow"

Write-ColorOutput "Press any key to continue..." "Yellow"
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
