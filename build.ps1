# Build script for RingMenuReborn
# Creates a release zip file in the releases folder

$addonName = "RingMenuReborn"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$releasesDir = Join-Path $scriptDir "releases"

# Read version from TOC file
$tocPath = Join-Path $scriptDir "$addonName.toc"
$tocContent = Get-Content $tocPath -Raw
if ($tocContent -match '## Version:\s*(.+)') {
    $version = $Matches[1].Trim()
} else {
    Write-Error "Could not find version in TOC file"
    exit 1
}

Write-Host "Building $addonName v$version..." -ForegroundColor Cyan

# Create releases directory if it doesn't exist
if (-not (Test-Path $releasesDir)) {
    New-Item -ItemType Directory -Path $releasesDir | Out-Null
    Write-Host "Created releases directory"
}

# Define the zip filename
$zipName = "$addonName-$version.zip"
$zipPath = Join-Path $releasesDir $zipName

# Check if this version already exists
if (Test-Path $zipPath) {
    Write-Warning "Release $zipName already exists!"
    $response = Read-Host "Overwrite? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Build cancelled."
        exit 0
    }
    Remove-Item $zipPath
}

# Create a temporary directory for packaging
$tempDir = Join-Path $env:TEMP "$addonName-build-$(Get-Random)"
$addonDir = Join-Path $tempDir $addonName
New-Item -ItemType Directory -Path $addonDir | Out-Null

# Files and folders to include (whitelist approach)
# This ensures .git, .gitignore, README.md, build.ps1, releases/, etc. are NOT included
$includePatterns = @(
    "*.lua",
    "*.xml",
    "*.tga",
    "*.toc"
)

# Copy matching files to temp directory
Write-Host "Packaging files:"
foreach ($pattern in $includePatterns) {
    $items = Get-ChildItem -Path $scriptDir -Filter $pattern -File -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        Write-Host "  + $($item.Name)" -ForegroundColor Gray
        Copy-Item -Path $item.FullName -Destination $addonDir
    }
}

# Copy libs folder if it exists
$libsSource = Join-Path $scriptDir "libs"
$libsDest = Join-Path $addonDir "libs"
if (Test-Path $libsSource) {
    Write-Host "  + libs/" -ForegroundColor Gray
    Copy-Item -Path $libsSource -Destination $libsDest -Recurse
}

# Create the zip file
Write-Host "Creating $zipName..."
Compress-Archive -Path $addonDir -DestinationPath $zipPath -Force

# Cleanup temp directory
Remove-Item -Path $tempDir -Recurse -Force

# Verify the zip was created
if (Test-Path $zipPath) {
    $zipSize = (Get-Item $zipPath).Length / 1KB
    Write-Host ""
    Write-Host "Successfully created release!" -ForegroundColor Green
    Write-Host "  File: $zipPath" -ForegroundColor Green
    Write-Host "  Size: $([math]::Round($zipSize, 2)) KB" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ready to upload to CurseForge!" -ForegroundColor Yellow
} else {
    Write-Error "Failed to create zip file"
    exit 1
}
