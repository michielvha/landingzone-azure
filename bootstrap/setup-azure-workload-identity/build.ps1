# Build script for multiple platforms (PowerShell)

param(
    [string]$Version = "1.0.0"
)

$ErrorActionPreference = "Stop"

$BinaryName = "setup-azure-workload-identity"
$BuildDir = "bin"

Write-Host "Building $BinaryName v$Version" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Create build directory
New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null

# Build for multiple platforms
$platforms = @(
    @{OS="linux"; Arch="amd64"},
    @{OS="linux"; Arch="arm64"},
    @{OS="darwin"; Arch="amd64"},
    @{OS="darwin"; Arch="arm64"},
    @{OS="windows"; Arch="amd64"}
)

foreach ($platform in $platforms) {
    $os = $platform.OS
    $arch = $platform.Arch
    
    $outputName = "$BinaryName-$os-$arch"
    
    if ($os -eq "windows") {
        $outputName += ".exe"
    }
    
    $outputPath = Join-Path $BuildDir $outputName
    
    Write-Host "Building for $os/$arch..." -ForegroundColor Yellow
    
    $env:GOOS = $os
    $env:GOARCH = $arch
    
    & go build -ldflags "-X main.version=$Version" -o $outputPath .
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to build for $os/$arch" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "✅ Build complete! Binaries in $BuildDir/" -ForegroundColor Green
Get-ChildItem $BuildDir | Format-Table Name, Length, LastWriteTime

# Create archives
Write-Host ""
Write-Host "Creating archives..." -ForegroundColor Yellow

Push-Location $BuildDir

Get-ChildItem "$BinaryName-*" | ForEach-Object {
    $file = $_
    
    if ($file.Name -like "*.exe") {
        # Windows: zip
        $zipName = $file.Name -replace '\.exe$', '.zip'
        Compress-Archive -Path $file.FullName -DestinationPath $zipName -Force
        Remove-Item $file.FullName
    }
    else {
        # Unix: tar.gz (requires tar command, available on Windows 10+)
        $tarName = "$($file.Name).tar.gz"
        & tar czf $tarName $file.Name
        Remove-Item $file.FullName
    }
}

Pop-Location

Write-Host ""
Write-Host "✅ Archives created!" -ForegroundColor Green
Get-ChildItem $BuildDir | Format-Table Name, Length, LastWriteTime
