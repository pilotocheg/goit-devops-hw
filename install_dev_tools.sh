#!/bin/bash

set -e

echo "=== Development Tools Installer (macOS Apple Silicon) ==="

# Check Homebrew
if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Installing Homebrew..."

    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "✓ Homebrew is already installed"
fi

# Update Homebrew
brew update

# Install Docker Desktop
if ! command -v docker &> /dev/null; then
    echo "Installing Docker Desktop..."
    brew install --cask docker
    echo "Docker Desktop installed."
    echo "Please launch Docker Desktop manually once after installation."
else
    echo "✓ Docker is already installed"
fi

# Check Docker Compose
if docker compose version &> /dev/null; then
    echo "✓ Docker Compose is already installed"
else
    echo "Installing Docker Compose..."
    brew install docker-compose
fi

# Install Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

    if python3 -c 'import sys; exit(0 if sys.version_info >= (3,9) else 1)'; then
        echo "✓ Python $PYTHON_VERSION is already installed"
    else
        echo "Python version is below 3.9. Upgrading..."
        brew install python
    fi
else
    echo "Installing Python..."
    brew install python
fi

# Install Django
if python3 -m pip show django &> /dev/null; then
    DJANGO_VERSION=$(python3 -m pip show django | grep Version | awk '{print $2}')
    echo "✓ Django $DJANGO_VERSION is already installed"
else
    echo "Installing Django..."
    python3 -m pip install --upgrade pip
    python3 -m pip install django
fi

echo ""
echo "=== Installation completed ==="

echo "Docker version:"
docker --version || true

echo "Python version:"
python3 --version

echo "Django version:"
python3 -m django --version