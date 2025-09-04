# IPFS Kubo Auto Setup Script for Windows (PowerShell)
# Downloads, installs, and configures IPFS with swarm key from environment variable

param(
    [switch]$StartDaemon
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "IPFS Kubo Auto Setup - Windows" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan

# Configuration
$KUBO_VERSION = "v0.34.1"
$BOOTSTRAP_NODE = "/ip4/10.4.56.71/tcp/4001/p2p/12D3KooWB8e8PHhq1GbdeZk9Y6fLUBYu6AqZKjs15zQZaGrYHxu9"

# Check if swarm key is provided via environment variable
if ([string]::IsNullOrEmpty($env:IPFS_SWARM_KEY)) {
    Write-Host "Error: IPFS_SWARM_KEY environment variable is not set!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please set it before running this script:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   For current PowerShell session:" -ForegroundColor White
    Write-Host '   $env:IPFS_SWARM_KEY = "/key/swarm/psk/1.0.0/`n/base16/`nyour-64-char-hex-key-here"' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   For permanent setup (run as Administrator):" -ForegroundColor White
    Write-Host '   [Environment]::SetEnvironmentVariable("IPFS_SWARM_KEY", "/key/swarm/psk/1.0.0/`n/base16/`nyour-key-here", "Machine")' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Or for current user only:" -ForegroundColor White
    Write-Host '   [Environment]::SetEnvironmentVariable("IPFS_SWARM_KEY", "/key/swarm/psk/1.0.0/`n/base16/`nyour-key-here", "User")' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Example key format:" -ForegroundColor White
    Write-Host '   "/key/swarm/psk/1.0.0/`n/base16/`n0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"' -ForegroundColor Gray
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Swarm key found in environment variable" -ForegroundColor Green

# Check if running as Administrator (optional for user-level install)
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Running without Administrator privileges - installing to user directory" -ForegroundColor Yellow
    Write-Host "IPFS will be installed for current user only" -ForegroundColor Yellow
}

# Detect architecture
$arch = $env:PROCESSOR_ARCHITECTURE
switch ($arch) {
    "AMD64" { $ARCH_NAME = "amd64" }
    "ARM64" { $ARCH_NAME = "arm64" }
    default {
        Write-Host "Unsupported architecture: $arch" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

$DOWNLOAD_URL = "https://dist.ipfs.tech/kubo/$KUBO_VERSION/kubo_${KUBO_VERSION}_windows-${ARCH_NAME}.zip"
$ZIP_FILE = "kubo_${KUBO_VERSION}_windows-${ARCH_NAME}.zip"

Write-Host "Step 1: Downloading IPFS Kubo $KUBO_VERSION for Windows $ARCH_NAME..." -ForegroundColor Green

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $ZIP_FILE -UseBasicParsing
    Write-Host "Download completed" -ForegroundColor Green
}
catch {
    Write-Host "Failed to download IPFS Kubo: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Step 2: Extracting archive..." -ForegroundColor Green
try {
    Expand-Archive -Path $ZIP_FILE -DestinationPath "." -Force
    Write-Host "Extraction completed" -ForegroundColor Green
}
catch {
    Write-Host "Failed to extract archive: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Step 3: Installing IPFS..." -ForegroundColor Green
try {
    # Choose installation path based on admin privileges
    if ($isAdmin) {
        $installPath = "$env:ProgramFiles\IPFS"
        $pathScope = "Machine"
        Write-Host "Installing to system directory (admin mode)" -ForegroundColor Green
    } else {
        $installPath = "$env:USERPROFILE\IPFS\bin"
        $pathScope = "User"
        Write-Host "Installing to user directory (non-admin mode)" -ForegroundColor Green
    }
    
    if (-not (Test-Path $installPath)) {
        New-Item -Path $installPath -ItemType Directory -Force | Out-Null
    }
    
    # Check if ipfs.exe exists in the kubo folder
    if (-not (Test-Path "kubo\ipfs.exe")) {
        Write-Host "Error: ipfs.exe not found in kubo folder" -ForegroundColor Red
        Write-Host "Contents of kubo folder:" -ForegroundColor Yellow
        Get-ChildItem "kubo" | Format-Table Name
        throw "IPFS binary not found"
    }
    
    Copy-Item "kubo\ipfs.exe" "$installPath\ipfs.exe" -Force
    
    # Add to PATH (system or user level based on privileges)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", $pathScope)
    if ($currentPath -notlike "*$installPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installPath", $pathScope)
        $env:Path += ";$installPath"
        Write-Host "Added IPFS to $pathScope PATH" -ForegroundColor Green
    }
    
    Write-Host "Installation completed" -ForegroundColor Green
}
catch {
    Write-Host "Installation failed: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Step 4: Verifying installation..." -ForegroundColor Green
try {
    & ipfs --version
    Write-Host "Verification completed" -ForegroundColor Green
}
catch {
    Write-Host "IPFS installation verification failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Step 5: Initializing IPFS..." -ForegroundColor Green
$ipfsPath = "$env:USERPROFILE\.ipfs"
if (Test-Path $ipfsPath) {
    Write-Host "IPFS already initialized, skipping init..." -ForegroundColor Yellow
} else {
    try {
        & ipfs init
        Write-Host "Initialization completed" -ForegroundColor Green
    }
    catch {
        Write-Host "IPFS initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host "Step 6: Creating swarm key from environment variable..." -ForegroundColor Green
try {
    $swarmKeyPath = "$ipfsPath\swarm.key"
    $env:IPFS_SWARM_KEY | Out-File -FilePath $swarmKeyPath -Encoding UTF8
    Write-Host "Swarm key created at: $swarmKeyPath" -ForegroundColor Green
    
    # Validate swarm key format (basic check)
    $keyContent = Get-Content $swarmKeyPath -Raw
    if ($keyContent -notmatch "^/key/swarm/psk/") {
        Write-Host "Warning: Swarm key format may be invalid. Expected format:" -ForegroundColor Yellow
        Write-Host "   /key/swarm/psk/1.0.0/" -ForegroundColor Gray
        Write-Host "   /base16/" -ForegroundColor Gray
        Write-Host "   <64-character-hex-key>" -ForegroundColor Gray
    }
}
catch {
    Write-Host "Failed to create swarm key: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Step 7: Configuring bootstrap nodes..." -ForegroundColor Green
try {
    & ipfs bootstrap rm --all
    & ipfs bootstrap add $BOOTSTRAP_NODE
    Write-Host "Bootstrap configuration completed" -ForegroundColor Green
}
catch {
    Write-Host "Bootstrap configuration failed: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Step 8: Configuring IPFS settings..." -ForegroundColor Green
try {
    & ipfs config --json Routing '{ "Type": "dhtserver" }'
    & ipfs config AutoTLS.Enabled false --bool
    & ipfs config --json Swarm.Transports.Network.Websocket false
    Write-Host "IPFS settings configured" -ForegroundColor Green
}
catch {
    Write-Host "IPFS settings configuration failed: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Step 9: Cleaning up..." -ForegroundColor Green
try {
    Remove-Item $ZIP_FILE -ErrorAction SilentlyContinue
    Remove-Item "kubo" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Cleanup completed" -ForegroundColor Green
}
catch {
    Write-Host "Cleanup had some issues, but installation completed" -ForegroundColor Yellow
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "IPFS Setup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Configuration Summary:" -ForegroundColor White
Write-Host "• Installation path: $installPath" -ForegroundColor White
Write-Host "• Bootstrap nodes:" -ForegroundColor White
& ipfs bootstrap list
Write-Host "• Swarm key: $ipfsPath\swarm.key" -ForegroundColor White
Write-Host "• Private network: Enabled" -ForegroundColor White
Write-Host "• Installed for: $(if ($isAdmin) { 'All users (system-wide)' } else { 'Current user only' })" -ForegroundColor White
Write-Host ""
Write-Host "To start IPFS daemon:" -ForegroundColor Yellow
Write-Host "   ipfs daemon" -ForegroundColor White
Write-Host ""
Write-Host "To check connected peers:" -ForegroundColor Yellow
Write-Host "   ipfs swarm peers" -ForegroundColor White
Write-Host ""
Write-Host "Security Note: Swarm key loaded from IPFS_SWARM_KEY environment variable" -ForegroundColor Green
if (-not $isAdmin) {
    Write-Host "Note: You may need to restart PowerShell for PATH changes to take effect" -ForegroundColor Yellow
}
Write-Host "Note: You may need to allow IPFS through Windows Firewall" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Cyan

if ($StartDaemon) {
    Write-Host "Starting IPFS daemon..." -ForegroundColor Green
    & ipfs daemon
} else {
    Read-Host "Press Enter to exit"
}