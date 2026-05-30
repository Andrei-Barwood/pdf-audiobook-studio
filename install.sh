#!/usr/bin/env bash

# PDF Audiobook Studio - Installation Script for macOS / Linux (bash & zsh)
# This script installs system dependencies (ffmpeg) and Python dependencies.

echo "===================================================="
echo "🎧 Installing PDF Audiobook Studio Dependencies 🚀"
echo "===================================================="
echo ""

# 1. Install System Dependencies (ffmpeg)
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if ! command -v ffmpeg &> /dev/null; then
        echo "[1/3] 🍏 Installing FFmpeg via Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo "❌ Homebrew is not installed. Please install Homebrew first: https://brew.sh/"
            exit 1
        fi
        brew install ffmpeg
    else
        echo "[1/3] ✅ FFmpeg is already installed."
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux (Debian/Ubuntu based)
    if ! command -v ffmpeg &> /dev/null; then
        echo "[1/3] 🐧 Installing FFmpeg via apt..."
        sudo apt update && sudo apt install -y ffmpeg
    else
        echo "[1/3] ✅ FFmpeg is already installed."
    fi
else
    echo "[1/3] ⚠️ Unsupported OS for automatic FFmpeg installation. Please install FFmpeg manually."
fi

# 2. Setup Python Environment
echo ""
echo "[2/3] 🐍 Setting up Python environment..."

# Check if pyenv is being used, or fallback to standard venv
if command -v pyenv &> /dev/null && pyenv versions | grep -q "hokkaido"; then
    echo "Found pyenv environment 'hokkaido'. Using it..."
    export PYENV_VERSION=hokkaido
    eval "$(pyenv init -)"
    PYTHON_CMD="python"
    PIP_CMD="pip"
else
    echo "Creating a standard Python virtual environment (venv)..."
    if ! command -v python3 &> /dev/null; then
        echo "❌ Python 3 is not installed. Please install Python 3.10+."
        exit 1
    fi
    python3 -m venv venv
    source venv/bin/activate
    PYTHON_CMD="python"
    PIP_CMD="pip"
fi

# 3. Install Python Dependencies
echo ""
echo "[3/3] 📦 Installing Python dependencies from requirements.txt..."
$PIP_CMD install --upgrade pip
$PIP_CMD install -r requirements.txt

echo ""
echo "===================================================="
echo "🎉 Installation Complete!"
echo "===================================================="
echo "To run the application, execute:"
if [[ -d "venv" ]]; then
    echo "  source venv/bin/activate"
    echo "  python main.py"
else
    echo "  pyenv activate hokkaido (if applicable)"
    echo "  python main.py"
fi
echo ""
