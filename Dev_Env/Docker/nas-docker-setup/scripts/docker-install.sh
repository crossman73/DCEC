#!/bin/bash
# Docker Installation Script for NAS

set -euo pipefail

# ===========================================
# Check for existing Docker installation
# ===========================================
if command -v docker &> /dev/null; then
    echo "Docker is already installed: $(docker --version)"
    exit 0
fi

# ===========================================
# Install Docker
# ===========================================
echo "Docker not found. Installing Docker..."

# Update package index
sudo apt-get update

# Install required packages
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

# Add Docker's stable repository
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update package index again
sudo apt-get update

# Install Docker CE
sudo apt-get install -y docker-ce

# ===========================================
# Verify Docker installation
# ===========================================
if command -v docker &> /dev/null; then
    echo "Docker installed successfully: $(docker --version)"
else
    echo "Docker installation failed"
    exit 1
fi

# ===========================================
# Post-installation steps
# ===========================================
echo "Adding user to the Docker group..."
sudo usermod -aG docker $(whoami)

echo "Docker installation complete. Please log out and back in to use Docker without sudo."