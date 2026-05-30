<#
.SYNOPSIS
PDF Audiobook Studio - Installation Script for Windows
This script checks for ffmpeg, sets up a Python virtual environment, and installs dependencies.
#>

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "🎧 Installing PDF Audiobook Studio Dependencies 🚀" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check System Dependencies (ffmpeg)
Write-Host "[1/3] 🪟 Checking for FFmpeg..." -ForegroundColor Yellow
if (Get-Command "ffmpeg" -ErrorAction SilentlyContinue) {
    Write-Host "[1/3] ✅ FFmpeg is already installed." -ForegroundColor Green
} else {
    Write-Host "⚠️ FFmpeg is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install FFmpeg to enable M4A export and better audio joining."
    Write-Host "You can install it using Winget:"
    Write-Host "    winget install --id=Gyan.FFmpeg -e"
    Write-Host "Or via Chocolatey:"
    Write-Host "    choco install ffmpeg"
    Write-Host ""
}

# 2. Setup Python Environment
Write-Host "[2/3] 🐍 Setting up Python virtual environment..." -ForegroundColor Yellow
if (!(Get-Command "python" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Python is not installed or not in PATH. Please install Python 3.10+ from python.org." -ForegroundColor Red
    exit 1
}

if (!(Test-Path "venv")) {
    Write-Host "Creating 'venv' directory..."
    python -m venv venv
}

Write-Host "Activating virtual environment..."
$ActivateScript = ".\venv\Scripts\Activate.ps1"
if (Test-Path $ActivateScript) {
    & $ActivateScript
} else {
    Write-Host "❌ Failed to find virtual environment activation script." -ForegroundColor Red
    exit 1
}

# 3. Install Python Dependencies
Write-Host ""
Write-Host "[3/3] 📦 Installing Python dependencies from requirements.txt..." -ForegroundColor Yellow
python -m pip install --upgrade pip
pip install -r requirements.txt

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "🎉 Installation Complete!" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "To run the application in the future, simply execute:"
Write-Host "  .\venv\Scripts\activate"
Write-Host "  python main.py"
Write-Host ""
