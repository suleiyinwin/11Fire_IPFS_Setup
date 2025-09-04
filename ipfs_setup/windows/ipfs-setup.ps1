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

# Create a safe working directory first (before any file operations)
$workingDir = "$env:TEMP\ipfs-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
try {
    if (-not (Test-Path $workingDir)) {
        New-Item -Path $workingDir -ItemType Directory -Force | Out-Null
    }
    Write-Host "Working directory: $workingDir" -ForegroundColor Gray
    Set-Location $workingDir
    Write-Host "Changed to working directory" -ForegroundColor Gray
}
catch {
    Write-Host "Failed to create working directory: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Falling back to user profile directory..." -ForegroundColor Yellow
    $workingDir = "$env:USERPROFILE\ipfs-setup-temp"
    if (-not (Test-Path $workingDir)) {
        New-Item -Path $workingDir -ItemType Directory -Force | Out-Null
    }
    Set-Location $workingDir
    Write-Host "Using fallback directory: $workingDir" -ForegroundColor Gray
}

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
$ZIP_FILE = "$workingDir\kubo_${KUBO_VERSION}_windows-${ARCH_NAME}.zip"

Write-Host "Step 1: Downloading IPFS Kubo $KUBO_VERSION for Windows $ARCH_NAME..." -ForegroundColor Green
Write-Host "Download location: $ZIP_FILE" -ForegroundColor Gray

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    # Add progress tracking for large downloads
    $ProgressPreference = 'SilentlyContinue'  # Disable progress bar for better performance
    Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $ZIP_FILE -UseBasicParsing
    $ProgressPreference = 'Continue'  # Re-enable progress bar
    
    # Verify download completed successfully
    if (Test-Path $ZIP_FILE) {
        $fileSize = (Get-Item $ZIP_FILE).Length
        Write-Host "Download completed successfully (size: $([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
        
        # Basic integrity check - IPFS releases should be at least 10MB
        if ($fileSize -lt 10MB) {
            Write-Host "Warning: Downloaded file seems too small, may be corrupted" -ForegroundColor Yellow
            throw "Downloaded file appears to be corrupted or incomplete"
        }
    } else {
        throw "Downloaded file not found after download completion"
    }
}
catch {
    Write-Host "Failed to download IPFS Kubo: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Trying alternative download location..." -ForegroundColor Yellow
    try {
        $alternativeFile = "$env:USERPROFILE\Downloads\kubo_${KUBO_VERSION}_windows-${ARCH_NAME}.zip"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $alternativeFile -UseBasicParsing
        $ProgressPreference = 'Continue'
        
        if (Test-Path $alternativeFile) {
            $fileSize = (Get-Item $alternativeFile).Length
            if ($fileSize -gt 10MB) {
                $ZIP_FILE = $alternativeFile
                Write-Host "Download completed to alternative location: $ZIP_FILE (size: $([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Green
            } else {
                throw "Alternative download also appears corrupted"
            }
        } else {
            throw "Alternative download failed - file not found"
        }
    }
    catch {
        Write-Host "Failed to download to alternative location: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Please check your internet connection and try again." -ForegroundColor Yellow
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host "Step 2: Extracting archive..." -ForegroundColor Green
try {
    $extractPath = Split-Path $ZIP_FILE -Parent
    
    # First, verify the ZIP file exists and is not corrupted
    if (-not (Test-Path $ZIP_FILE)) {
        throw "ZIP file not found: $ZIP_FILE"
    }
    
    $fileSize = (Get-Item $ZIP_FILE).Length
    if ($fileSize -lt 1MB) {
        throw "ZIP file appears to be corrupted (size: $fileSize bytes)"
    }
    
    Write-Host "ZIP file verified (size: $([math]::Round($fileSize/1MB, 2)) MB)" -ForegroundColor Gray
    
    # Try PowerShell 5+ method first
    try {
        Expand-Archive -Path $ZIP_FILE -DestinationPath $extractPath -Force
        Write-Host "Extraction completed using Expand-Archive" -ForegroundColor Green
    }
    catch {
        Write-Host "Expand-Archive failed, trying alternative method..." -ForegroundColor Yellow
        
        # Fallback to COM object method for older PowerShell versions
        try {
            $shell = New-Object -ComObject Shell.Application
            $zip = $shell.NameSpace($ZIP_FILE)
            $destination = $shell.NameSpace($extractPath)
            $destination.CopyHere($zip.Items(), 4)
            Write-Host "Extraction completed using Shell.Application" -ForegroundColor Green
        }
        catch {
            Write-Host "Shell.Application also failed, trying .NET method..." -ForegroundColor Yellow
            
            # Try .NET ZipFile method
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($ZIP_FILE, $extractPath)
            Write-Host "Extraction completed using .NET ZipFile" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "Failed to extract archive: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "ZIP file location: $ZIP_FILE" -ForegroundColor Yellow
    Write-Host "Extract path: $extractPath" -ForegroundColor Yellow
    
    if (Test-Path $ZIP_FILE) {
        $fileInfo = Get-Item $ZIP_FILE
        Write-Host "ZIP file size: $($fileInfo.Length) bytes" -ForegroundColor Yellow
        Write-Host "ZIP file created: $($fileInfo.CreationTime)" -ForegroundColor Yellow
    }
    
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
    $extractPath = Split-Path $ZIP_FILE -Parent
    $kuboPath = "$extractPath\kubo"
    if (-not (Test-Path "$kuboPath\ipfs.exe")) {
        Write-Host "Error: ipfs.exe not found in kubo folder" -ForegroundColor Red
        Write-Host "Extract path: $extractPath" -ForegroundColor Yellow
        Write-Host "Looking for: $kuboPath\ipfs.exe" -ForegroundColor Yellow
        if (Test-Path $kuboPath) {
            Write-Host "Contents of kubo folder:" -ForegroundColor Yellow
            Get-ChildItem $kuboPath | Format-Table Name
        } else {
            Write-Host "Kubo folder not found. Contents of extract path:" -ForegroundColor Yellow
            Get-ChildItem $extractPath | Format-Table Name
        }
        throw "IPFS binary not found"
    }
    
    Copy-Item "$kuboPath\ipfs.exe" "$installPath\ipfs.exe" -Force
    
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
    if (Test-Path $ZIP_FILE) {
        Remove-Item $ZIP_FILE -ErrorAction SilentlyContinue
    }
    $extractPath = Split-Path $ZIP_FILE -Parent
    $kuboPath = "$extractPath\kubo"
    if (Test-Path $kuboPath) {
        Remove-Item $kuboPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "Cleanup completed" -ForegroundColor Green
    
    # Clean up working directory if it's a temp directory
    if ($workingDir -like "*temp*" -and $workingDir -ne $env:USERPROFILE) {
        Set-Location $env:USERPROFILE
        Remove-Item $workingDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Working directory cleaned up" -ForegroundColor Green
    }
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