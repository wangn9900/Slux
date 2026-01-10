# Sing-box Core Auto-Download Script
# Run before Flutter build to automatically download Sing-box core for the target platform

param(
    [string]$Version = "latest",
    [string]$Platform = "windows",
    [string]$Proxy = "http://127.0.0.1:10808"
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Green "========================================="
Write-ColorOutput Green "  Sing-box Core Auto-Download Tool"
Write-ColorOutput Green "========================================="
Write-Output ""

# Android/iOS don't need downloaded cores (they use Libbox compiled into app)
if ($Platform -eq "android" -or $Platform -eq "ios") {
    Write-ColorOutput Yellow "Platform: $Platform"
    Write-ColorOutput Cyan "Android/iOS use Libbox (compiled into app), no need to download core"
    Write-ColorOutput Green "Skipping download for mobile platforms"
    exit 0
}

# Define paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$AssetsCoreDir = Join-Path $ProjectRoot "assets\core"

# Ensure directory exists
if (-not (Test-Path $AssetsCoreDir)) {
    New-Item -ItemType Directory -Path $AssetsCoreDir -Force | Out-Null
    Write-ColorOutput Yellow "Created directory: $AssetsCoreDir"
}

# Check for existing core files
$ExistingCore = Get-ChildItem -Path $AssetsCoreDir -Filter "sing-box*" -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq ".exe" -or $_.Name -eq "sing-box" }
if ($ExistingCore) {
    Write-ColorOutput Cyan "Found existing core files:"
    $ExistingCore | ForEach-Object { Write-Output "  - $($_.Name)" }
    
    $response = Read-Host "Re-download? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-ColorOutput Green "Skipping download, using existing files"
        exit 0
    }
}

# Configure proxy
if ($Proxy) {
    Write-ColorOutput Cyan "Using proxy: $Proxy"
    $env:HTTP_PROXY = $Proxy
    $env:HTTPS_PROXY = $Proxy
}

# Get specific version (Locked to v1.12.15 to match Android/iOS core)
Write-ColorOutput Cyan "Fetching Sing-box version v1.12.15..."
$LatestVersion = "1.12.15"

# Determine download filename based on platform
$DownloadFileName = switch ($Platform) {
    "windows" { "sing-box-$LatestVersion-windows-amd64.zip" }
    "macos" { "sing-box-$LatestVersion-darwin-amd64.zip" }
    "linux" { "sing-box-$LatestVersion-linux-amd64.zip" }
    default { "sing-box-$LatestVersion-windows-amd64.zip" }
}

$DownloadUrl = "https://github.com/SagerNet/sing-box/releases/download/v$LatestVersion/$DownloadFileName"
$TempZipPath = Join-Path $env:TEMP $DownloadFileName

Write-ColorOutput Cyan "Download URL: $DownloadUrl"
Write-Output ""

# Download file
Write-ColorOutput Yellow "Downloading Sing-box core..."
try {
    $ProgressPreference = 'SilentlyContinue'
    if ($Proxy) {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZipPath -UseBasicParsing -Proxy $Proxy
    }
    else {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZipPath -UseBasicParsing
    }
    $ProgressPreference = 'Continue'
    
    $FileSizeMB = [math]::Round((Get-Item $TempZipPath).Length / 1MB, 2)
    Write-ColorOutput Green "Download complete! File size: $FileSizeMB MB"
}
catch {
    Write-ColorOutput Red "Download failed: $_"
    Write-ColorOutput Yellow "Tip: Check proxy settings or download manually from:"
    Write-ColorOutput Yellow "  $DownloadUrl"
    Write-ColorOutput Yellow "Then place the extracted sing-box executable in: $AssetsCoreDir"
    exit 1
}

# Extract file
Write-ColorOutput Yellow "Extracting..."
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $TempExtractDir = Join-Path $env:TEMP "sing-box-extract-$(Get-Random)"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($TempZipPath, $TempExtractDir)
    
    # Find sing-box executable
    $ExeFiles = Get-ChildItem -Path $TempExtractDir -Recurse -Filter "sing-box*" -File | Where-Object {
        $_.Extension -eq ".exe" -or ($_.Extension -eq "" -and $_.Name -like "sing-box*")
    }
    
    if ($ExeFiles) {
        foreach ($exe in $ExeFiles) {
            # Rename to standard name
            $FinalName = if ($Platform -eq "windows") { "sing-box.exe" } else { "sing-box" }
            $DestPath = Join-Path $AssetsCoreDir $FinalName
            Copy-Item -Path $exe.FullName -Destination $DestPath -Force
            Write-ColorOutput Green "Copied: $($exe.Name) -> $FinalName"
        }
    }
    else {
        Write-ColorOutput Red "sing-box executable not found in archive"
        exit 1
    }
    
    # Cleanup temp files
    Remove-Item -Path $TempZipPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $TempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-ColorOutput Green "Extraction complete!"
}
catch {
    Write-ColorOutput Red "Extraction failed: $_"
    exit 1
}

Write-Output ""
Write-ColorOutput Green "========================================="
Write-ColorOutput Green "  Core files ready!"
Write-ColorOutput Green "========================================="
Write-Output ""
Write-ColorOutput Cyan "Downloaded files:"
Get-ChildItem -Path $AssetsCoreDir -Filter "sing-box*" -File | ForEach-Object {
    $SizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Output "  [OK] $($_.Name) ($SizeMB MB)"
}
Write-Output ""
Write-ColorOutput Green "Now you can run: flutter build $Platform"
