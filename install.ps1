# Laravel Best Practice Skills — Installer (Windows PowerShell)
# Usage: irm https://raw.githubusercontent.com/sasabajic/laravel-best-practice-skills/main/install.ps1 | iex
# Or locally: .\install.ps1

$ErrorActionPreference = "Stop"

$version = "2.0.0"
$skillsDir = Join-Path $env:USERPROFILE ".copilot\skills"
$tempDir = Join-Path $env:TEMP "laravel-best-practice-skills-$(Get-Random)"
$repoUrl = "https://github.com/sasabajic/laravel-best-practice-skills.git"

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Laravel Best Practice Skills — Installer v$version" -ForegroundColor Cyan
Write-Host "  github.com/sasabajic/laravel-best-practice-skills" -ForegroundColor Gray
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check if git is available
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: git is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install git from https://git-scm.com and try again." -ForegroundColor Yellow
    exit 1
}

# Create skills directory if it doesn't exist
if (-not (Test-Path $skillsDir)) {
    Write-Host "Creating skills directory: $skillsDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null
}

# Clone to temp directory
Write-Host "Cloning repository..." -ForegroundColor Yellow
if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
git clone --depth 1 $repoUrl $tempDir 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to clone repository." -ForegroundColor Red
    exit 1
}

# Copy all skill folders (folders containing SKILL.md)
$skillFolders = Get-ChildItem -Path $tempDir -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "SKILL.md")
}

$count = 0
foreach ($folder in $skillFolders) {
    $dest = Join-Path $skillsDir $folder.Name
    Copy-Item -Path $folder.FullName -Destination $dest -Recurse -Force
    $count++
    Write-Host "  Installed: $($folder.Name)" -ForegroundColor Green
}

# Also copy .github folder if it exists (prompt templates)
$githubDir = Join-Path $tempDir ".github"
if (Test-Path $githubDir) {
    Copy-Item -Path $githubDir -Destination (Join-Path $skillsDir ".github") -Recurse -Force
    Write-Host "  Installed: .github (prompt templates)" -ForegroundColor Green
}

# Copy project documentation files
foreach ($file in @("README.md", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE")) {
    $filePath = Join-Path $tempDir $file
    if (Test-Path $filePath) {
        Copy-Item -Path $filePath -Destination (Join-Path $skillsDir $file) -Force
        Write-Host "  Copied: $file" -ForegroundColor Green
    }
}

# Cleanup temp directory
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Done! Installed $count skills (v$version) to:" -ForegroundColor Green
Write-Host "  $skillsDir" -ForegroundColor White
Write-Host ""
Write-Host "Installed skills:" -ForegroundColor Yellow
Get-ChildItem -Path $skillsDir -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "SKILL.md")
} | ForEach-Object {
    Write-Host "  * $($_.Name)" -ForegroundColor White
}
Write-Host ""
Write-Host "To update later, run this script again." -ForegroundColor Gray
Write-Host ""
