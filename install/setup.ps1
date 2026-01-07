[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$scriptDir   = $PSScriptRoot 
$projectRoot = (Split-Path -Parent $scriptDir)
$cacheDir    = Join-Path $projectRoot ".cache"

Write-Host "Project Root Directory set to: $projectRoot" -ForegroundColor Cyan
Write-Host "Cache Directory set to: $cacheDir" -ForegroundColor Cyan

if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir | Out-Null
}

$config = @{
    PythonArchiveUrl = "https://huggingface.co/datasets/LeeAeron/ffmpeg_for_ai/resolve/main/python.7z?download=true"
    GitArchiveUrl    = "https://huggingface.co/datasets/LeeAeron/ffmpeg_for_ai/resolve/main/git.7z?download=true"
    FfmpegArchiveUrl = "https://huggingface.co/datasets/LeeAeron/ffmpeg_for_ai/resolve/main/ffmpeg.zip?download=true"
    SoxArchiveUrl = "https://huggingface.co/datasets/LeeAeron/Chatterbox-TTS-Server-Multilingual/resolve/main/sox.7z?download=true"
    
    PythonArchive = Join-Path $cacheDir "Python.7z"
    GitArchive    = Join-Path $cacheDir "Git.7z"
    FfmpegArchive = Join-Path $cacheDir "ffmpeg.zip"
    SoxArchive    = Join-Path $cacheDir "sox.7z"

    SevenZipExe = Join-Path $cacheDir "7zr.exe"

    PythonDir = Join-Path $projectRoot "python"
    GitDir    = Join-Path $projectRoot "git"
    FfmpegDir = Join-Path $projectRoot "ffmpeg"
    SoxDir    = Join-Path $projectRoot "sox"
}

function Expand-ArchiveAuto($archivePath, $destinationPath) {
    if (-not (Test-Path $archivePath)) {
        throw "Archive not found: $archivePath"
    }

    if (Test-Path $destinationPath) {
        Write-Host "Removing old folder: $destinationPath" -ForegroundColor Yellow
        Remove-Item $destinationPath -Recurse -Force
    }

    $ext = [IO.Path]::GetExtension($archivePath).ToLower()

    if ($ext -eq ".zip") {
        Write-Host "Extracting ZIP archive: $archivePath" -ForegroundColor Cyan
        Expand-Archive -Path $archivePath -DestinationPath $destinationPath -Force
    }
    elseif ($ext -eq ".7z") {
        if (-not (Test-Path $config.SevenZipExe)) {
            throw "7zr.exe not found at $($config.SevenZipExe)"
        }

        Write-Host "Extracting 7Z archive: $archivePath" -ForegroundColor Cyan
        Start-Process -FilePath $config.SevenZipExe `
            -ArgumentList "x `"$archivePath`" -o`"$destinationPath`" -y" `
            -Wait -NoNewWindow
    }
    else {
        throw "Unsupported archive format: $ext"
    }
}

function Ensure-PortableDependencies {
    Write-Host "=== Setting up portable Python and Git ===" -ForegroundColor Cyan
    try {
        # --- Python ---
        if (-not (Test-Path $config.PythonArchive)) {
            Write-Host "Downloading portable Python archive..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $config.PythonArchiveUrl -OutFile $config.PythonArchive -UseBasicParsing
        }
        Expand-ArchiveAuto $config.PythonArchive $config.PythonDir
        $pythonExePath = Join-Path $config.PythonDir "python.exe"
        if (-not (Test-Path $pythonExePath)) {
            throw "Portable Python not found after extraction."
        }
        Write-Host "Portable Python ready at: $pythonExePath" -ForegroundColor Green

        # --- Git ---
        if (-not (Test-Path $config.GitArchive)) {
            Write-Host "Downloading portable Git archive..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $config.GitArchiveUrl -OutFile $config.GitArchive -UseBasicParsing
        }
        # --- FFmpeg ---
        if (-not (Test-Path $config.FfmpegArchive)) {
            Write-Host "Downloading FFmpeg archive..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $config.FfmpegArchiveUrl -OutFile $config.FfmpegArchive -UseBasicParsing
        }

        Write-Host "Extracting FFmpeg..." -ForegroundColor Cyan
        Expand-ArchiveAuto $config.FfmpegArchive $config.FfmpegDir
        
        Write-Host "FFmpeg unpacked." -ForegroundColor Green

        # --- Sox ---
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

        # ---UNPACK CODE ---
        Expand-ArchiveAuto $config.GitArchive $config.GitDir
        $gitExePath = Join-Path $config.GitDir "bin\git.exe"
        if (-not (Test-Path $gitExePath)) {
            throw "Portable Git not found after extraction."
        }
        Write-Host "Portable Git ready at: $gitExePath" -ForegroundColor Green

        $env:Path = "$($config.GitDir)\bin;$env:Path"

        return $pythonExePath
    } catch {
        Write-Host "`nError during portable dependency setup: $_" -ForegroundColor Red
        throw "Portable setup failed."
    }
}

try {
    $installType = ''
    while ($installType -notin ('0', '1', '2', '3')) {
        Write-Host "`n=== Choose Installation Type ===" -ForegroundColor Magenta
        Write-Host "1) NVIDIA GPU Version (CUDA, recommended for NVIDIA GPUs)"
        Write-Host "2) CPU Only Version (Works everywhere, slower)"
        Write-Host "3) AMD GPU Version (ROCm, RX 6000/7000 series and newer)"
        Write-Host "0) Exit to main menu"
        $installType = Read-Host "Enter your choice (0-3)"
    }

    if ($installType -eq '0') {
        Write-Host "`nReturning to main menu..." -ForegroundColor Yellow
        exit 99
    }

    $pythonExePath = Ensure-PortableDependencies

    $useNvidia = $false
    $useAmd    = $false

    if ($installType -eq '1') {
        Write-Host "Checking for NVIDIA GPU..." -ForegroundColor Cyan
        $gpu = Get-WmiObject -Query "SELECT * FROM Win32_VideoController WHERE Name LIKE '%NVIDIA%'" 
        if ($gpu) {
            Write-Host "NVIDIA GPU detected: $($gpu.Name)" -ForegroundColor Green
            $useNvidia = $true
        } else {
            Write-Host "No NVIDIA GPU detected. Switching to CPU-only." -ForegroundColor Yellow
        }
    } elseif ($installType -eq '2') {
        Write-Host "CPU-only installation selected." -ForegroundColor Green
    } elseif ($installType -eq '3') {
        Write-Host "Checking for AMD GPU..." -ForegroundColor Cyan
        $gpu = Get-WmiObject -Query "SELECT * FROM Win32_VideoController WHERE Name LIKE '%AMD%' OR Name LIKE '%Radeon%'" 
        if ($gpu) {
            Write-Host "AMD GPU detected: $($gpu.Name)" -ForegroundColor Green
            $useAmd = $true
        } else {
            Write-Host "No AMD GPU detected. Switching to CPU-only." -ForegroundColor Yellow
        }
    }

    $venvPath = Join-Path $projectRoot "venv"
    Write-Host "`nCreating Python virtual environment in '$venvPath'..." -ForegroundColor Yellow
    if (Test-Path $venvPath) {
        Write-Host "Virtual environment folder 'venv' already exists. Reusing it." -ForegroundColor Cyan
    }

    & $pythonExePath -m venv $venvPath

    $venvPip = Join-Path $venvPath "Scripts\pip.exe"

    $env:PIP_CACHE_DIR = $cacheDir
    $env:TEMP = $cacheDir
    $env:TMP  = $cacheDir

    Write-Host "Upgrading pip..." -ForegroundColor Yellow
    & $venvPip install --upgrade pip

    if ($useNvidia) {
        $requirementsFile = "requirements-nvidia.txt"
        Write-Host "Installing NVIDIA GPU requirements from '$requirementsFile'..." -ForegroundColor Yellow
    } elseif ($useAmd) {
        $requirementsFile = "requirements-rocm.txt"
        Write-Host "Installing AMD ROCm requirements from '$requirementsFile'..." -ForegroundColor Yellow
    } else {
        $requirementsFile = "requirements.txt"
        Write-Host "Installing CPU requirements from '$requirementsFile'..." -ForegroundColor Yellow
    }

    $reqPath = Join-Path $projectRoot $requirementsFile
    if (-not (Test-Path $reqPath)) {
        throw "Requirement file not found: $reqPath"
    }

    & $venvPip install -r $reqPath

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Python packages from $requirementsFile."
    }

    Write-Host "Installing russtress..." -ForegroundColor Yellow
    & $venvPip install russtress==0.1.4

    Write-Host "Uninstalling any existing protobuf..." -ForegroundColor Yellow
    & $venvPip uninstall -y protobuf

    Write-Host "Reinstalling protobuf==3.20.3..." -ForegroundColor Yellow
    & $venvPip install protobuf==3.20.3

    Write-Host "Uninstalling any existing tensorflow..." -ForegroundColor Yellow
    & $venvPip uninstall -y tensorflow

    Write-Host "Reinstalling tensorflow==2.12.0..." -ForegroundColor Yellow
    & $venvPip install tensorflow==2.12.0
    
    Write-Host "Installing ruaccent..." -ForegroundColor Yellow
    & $venvPip install ruaccent
    
    Write-Host "Installing chardet..." -ForegroundColor Yellow
    & $venvPip install chardet

    if (Test-Path $cacheDir) {
        Write-Host "Cleaning up cache directory: $cacheDir" -ForegroundColor Cyan
        Remove-Item $cacheDir -Recurse -Force
    }

    Write-Host "Finished! Portable project setup completed successfully!" -ForegroundColor Green

} catch {
    Write-Host "Error during setup: $_" -ForegroundColor Red
    exit 1
}