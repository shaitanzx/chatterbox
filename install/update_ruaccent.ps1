# Install ruaccent + chardet
$PIP = "$env:PYTHON_DIR\Scripts\pip.exe"

function Ensure-PythonPackage($name) {
    Write-Host "Checking for $name..." -ForegroundColor Yellow
    $installed = & $PIP show $name 2>$null
    if (-not $installed) {
        Write-Host "$name not found. Installing..." -ForegroundColor Yellow
        & $PIP install $name --upgrade
        Write-Host "$name installed successfully." -ForegroundColor Green
    } else {
        Write-Host "$name already installed." -ForegroundColor Green
    }
}

Ensure-PythonPackage "ruaccent"
Ensure-PythonPackage "chardet"

# Remove old chatterbox + install new from Git

Write-Host "Removing old chatterbox module..." -ForegroundColor Yellow
& $PIP uninstall -y chatterbox 2>$null

Write-Host "Installing chatterbox from GitHub..." -ForegroundColor Yellow
& $PIP install "git+https://github.com/LeeAeron/chatterbox.git"
Write-Host "chatterbox installed successfully." -ForegroundColor Green

# Sox download + extract

$cacheDir    = Join-Path $PSScriptRoot ".cache"
$projectRoot = Split-Path $PSScriptRoot -Parent

$config = @{
    SoxArchiveUrl = "https://huggingface.co/datasets/LeeAeron/Chatterbox-TTS-Server-Multilingual/resolve/main/sox.7z?download=true"
    SoxArchive    = Join-Path $cacheDir "sox.7z"
    SoxDir        = Join-Path $projectRoot "sox"
    SevenZipExe   = Join-Path $cacheDir "7zr.exe"
    SevenZipUrl   = "https://huggingface.co/datasets/LeeAeron/ffmpeg_for_ai/resolve/main/7zr.exe?download=true"
}

if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir | Out-Null
}

function Ensure-7Zip {
    if (-not (Test-Path $config.SevenZipExe)) {
        Write-Host "7zr.exe not found. Downloading..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $config.SevenZipUrl -OutFile $config.SevenZipExe -UseBasicParsing
        Write-Host "7zr.exe downloaded successfully." -ForegroundColor Green
    }
}

function Expand-ArchiveAuto($archivePath, $destinationPath) {
    $ext = [IO.Path]::GetExtension($archivePath).ToLower()

    if (Test-Path $destinationPath) {
        Remove-Item $destinationPath -Recurse -Force
    }

    if ($ext -eq ".7z") {
        Start-Process -FilePath $config.SevenZipExe `
            -ArgumentList "x `"$archivePath`" -o`"$destinationPath`" -y" `
            -Wait -NoNewWindow
    } elseif ($ext -eq ".zip") {
        Expand-Archive -Path $archivePath -DestinationPath $destinationPath -Force
    }
}

# Ensure 7zr exists
Ensure-7Zip

# Download Sox
if (-not (Test-Path $config.SoxArchive)) {
    Write-Host "Downloading Sox archive..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $config.SoxArchiveUrl -OutFile $config.SoxArchive -UseBasicParsing
}

Write-Host "Extracting Sox..." -ForegroundColor Cyan
Expand-ArchiveAuto $config.SoxArchive $config.SoxDir

$soxExePath = Join-Path $config.SoxDir "sox.exe"
if (-not (Test-Path $soxExePath)) {
    throw "Sox not found after extraction."
}

Write-Host "Sox ready at: $soxExePath" -ForegroundColor Green

# Remove archive
if (Test-Path $config.SoxArchive) {
    Write-Host "Removing Sox archive..." -ForegroundColor Yellow
    Remove-Item $config.SoxArchive -Force
}

# Schedule .cache cleanup
$cleanupScript = @"
Start-Sleep -Seconds 2
Remove-Item -Recurse -Force '$cacheDir'
"@

$cleanupPath = Join-Path $env:TEMP "cleanup_cache.ps1"
Set-Content -Path $cleanupPath -Value $cleanupScript -Encoding UTF8

Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$cleanupPath`"" -WindowStyle Hidden

# Safe self-delete
$scriptPath = $MyInvocation.MyCommand.Path
Start-Sleep -Seconds 2
Start-Process powershell -ArgumentList "-NoProfile -Command Start-Sleep 1; Remove-Item -Force '$scriptPath'" -WindowStyle Hidden

exit 0
