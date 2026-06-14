#!/bin/bash

set -e

echo "=== Development Tools Installer (Ubuntu) ==="

# Update package lists
sudo apt update

# Install Docker
if command -v docker &>/dev/null; then
    echo "✓ Docker is already installed"
else
    echo "Installing Docker..."

        # Add Docker's official GPG key:
    sudo apt update
    sudo apt install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    sudo apt update

    # install Docker
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "Docker installed successfully"
fi

# Check Docker Compose
if docker compose version &>/dev/null; then
    echo "✓ Docker Compose is already installed"
else
    echo "Installing Docker Compose Plugin..."

    sudo apt install -y docker-compose-plugin
fi

# Install Python
if command -v python3 &> /dev/null; then
    if python3 -c 'import sys; exit(0 if sys.version_info >= (3,9) else 1)'; then
        echo "✓ Python $(python3 --version | awk '{print $2}') is already installed"
    else
        echo "Python version below 3.9. Installing newer version..."
        sudo apt install -y python3 python3-pip python3-venv
    fi
else
    echo "Installing Python..."
    sudo apt install -y python3 python3-pip python3-venv
fi

# Install pip if missing
if ! command -v pip3 &>/dev/null; then
    sudo apt install -y python3-pip
fi

# Install Django
if python3 -m pip show django &> /dev/null; then
    DJANGO_VERSION=$(python3 -m pip show django | grep Version | awk '{print $2}')
    echo "✓ Django $DJANGO_VERSION is already installed"
else
    echo "Installing Django..."

    python3 -m pip install --user --upgrade pip

    python3 -m pip install --user django
fi

echo ""
echo "=== Installation completed ==="