# RingMenu Reborn Build Script
# Packages the addon for distribution

$AddonID = "RingMenuReborn"
$BaseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$OutputDir = Join-Path $BaseDir "releases"

# Extract version from TOC
$TocFile = Join-Path $BaseDir "$AddonID.toc"
$TocData = Get-Content $TocFile -Raw
if ($TocData -match '## Version:\s*(.+)') {
    $Ver = $Matches[1].Trim()
} else {
    Write-Error "Version not found in TOC"
    exit 1
}

Write-Host "Packaging $AddonID version $Ver..." -ForegroundColor Cyan

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    Write-Host "Created output directory"
}

# Output filename
$PackageName = "$AddonID-$Ver.zip"
$PackagePath = Join-Path $OutputDir $PackageName

# Handle existing package
if (Test-Path $PackagePath) {
    Write-Warning "Package $PackageName exists!"
    $Confirm = Read-Host "Replace? (y/N)"
    if ($Confirm -ne 'y' -and $Confirm -ne 'Y') {
        Write-Host "Aborted."
        exit 0
    }
    Remove-Item $PackagePath
}

# Staging directory
$StagingRoot = Join-Path $env:TEMP "$AddonID-pkg-$(Get-Random)"
$StagingDir = Join-Path $StagingRoot $AddonID
New-Item -ItemType Directory -Path $StagingDir | Out-Null

# Addon file patterns
$FilePatterns = @("*.lua", "*.xml", "*.tga", "*.toc", "*.md")

Write-Host "Including files:"
foreach ($Pattern in $FilePatterns) {
    $Matches = Get-ChildItem -Path $BaseDir -Filter $Pattern -File -ErrorAction SilentlyContinue
    foreach ($File in $Matches) {
        Write-Host "  - $($File.Name)" -ForegroundColor Gray
        Copy-Item -Path $File.FullName -Destination $StagingDir
    }
}

# Include libs directory
$LibsPath = Join-Path $BaseDir "libs"
$LibsDest = Join-Path $StagingDir "libs"
if (Test-Path $LibsPath) {
    Write-Host "  - libs/" -ForegroundColor Gray
    Copy-Item -Path $LibsPath -Destination $LibsDest -Recurse
}

# Create archive
Write-Host "Generating $PackageName..."
Compress-Archive -Path $StagingDir -DestinationPath $PackagePath -Force

# Cleanup
Remove-Item -Path $StagingRoot -Recurse -Force

# Report results
if (Test-Path $PackagePath) {
    $SizeKB = (Get-Item $PackagePath).Length / 1KB
    Write-Host ""
    Write-Host "Package created successfully!" -ForegroundColor Green
    Write-Host "  Path: $PackagePath" -ForegroundColor Green
    Write-Host "  Size: $([math]::Round($SizeKB, 2)) KB" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ready for distribution!" -ForegroundColor Yellow
} else {
    Write-Error "Package creation failed"
    exit 1
}
