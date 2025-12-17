# NOTE: I'm too stupid (or PowerShell is too stupid) to source env variables from a file.
#
# Also, this script in itself is also stupid due to the fact you'd need to restart Windows,
# run this script again, manually start Docker in order for it to be succeed.

$SwarmToken = ""
$ManagerIp  = "" 

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message" -ForegroundColor Cyan
}

try {
    # 1. Check Administrator Privileges
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "This script requires Administrator privileges. Please run as Administrator."
        break
    }

    # 2. Check if Docker is installed
    $dockerInstalled = $false
    if (Get-Command "docker" -ErrorAction SilentlyContinue) {
        $dockerInstalled = $true
        Write-Log "Docker is already installed."
    } elseif (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
        $dockerInstalled = $true
        Write-Log "Docker found in Program Files."
        $env:Path += ";C:\Program Files\Docker\Docker\resources\bin"
    }

    # 3. Install Docker (if missing)
    if (-not $dockerInstalled) {
        Write-Log "Docker not found. Starting installation..."

        # Check WSL prerequisites
        $wslStatus = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
        if ($wslStatus.State -ne 'Enabled') {
            Write-Log "Enabling WSL..."
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
            Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
            Write-Warning "WSL enabled. RESTART REQUIRED. Please restart your PC and run this script again."
            return
        }

        # Download & Install
        $installerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
        $downloadPath = "$env:TEMP\Docker Desktop Installer.exe"
        
        Write-Log "Downloading Docker Installer..."
        Invoke-WebRequest -Uri $installerUrl -OutFile $downloadPath -UseBasicParsing
        
        Write-Log "Installing Docker (Quiet Mode)..."
        Start-Process -FilePath $downloadPath -ArgumentList "install", "--quiet", "--accept-license" -Wait
        
        Remove-Item $downloadPath -Force
        Write-Log "Installation complete."
        
        # Refresh Path
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }

    # 4. Start Docker Desktop (Required for Windows Swarm)
    Write-Log "Ensuring Docker Engine is running..."
    $dockerProcess = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
    if (-not $dockerProcess) {
        Write-Log "Launching Docker Desktop..."
        if (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe") {
            Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        } else {
            Write-Error "Could not find Docker Desktop executable."
            return
        }
    }

    # 5. Wait for Engine Readiness
    Write-Log "Waiting for Docker Engine to initialize (up to 2 mins)..."
    $maxRetries = 24
    $retryCount = 0
    do {
        Start-Sleep -Seconds 5
        $isReady = docker info 2>$null
        $retryCount++
        if ($retryCount -ge $maxRetries) {
            Write-Error "Timed out waiting for Docker Engine. Please check Docker Desktop manually."
            return
        }
    } until ($isReady)
    Write-Log "Docker Engine is ready."

    # 6. Join Swarm
    if ($SwarmToken -ne "PUT_YOUR_LONG_TOKEN_STRING_HERE" -and $ManagerIp) {
        $swarmStatus = docker info --format '{{.Swarm.LocalNodeState}}'
        
        if ($swarmStatus -eq "active") {
            Write-Log "Node is ALREADY part of a swarm. Skipping join."
        } else {
            Write-Log "Joining Swarm at $ManagerIp..."
            docker swarm join --token $SwarmToken "$($ManagerIp):2377"
            
            if ($?) {
                Write-Host "SUCCESS: Joined the swarm!" -ForegroundColor Green
            } else {
                Write-Error "FAILED: Could not join swarm. Check token/IP/firewall."
            }
        }
    } else {
        Write-Warning "Skipping Swarm Join: Token or IP not configured in script."
    }

} catch {
    Write-Error "An error occurred: $_"
}
