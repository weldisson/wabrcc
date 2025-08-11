#!/usr/bin/env bash
set -euo pipefail

# Install Docker Engine on Ubuntu/Debian
# Usage: sudo bash ./scripts/install_docker.sh

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash ./scripts/install_docker.sh"
  exit 1
fi

if command -v docker >/dev/null 2>&1; then
  echo "Docker already installed: $(docker --version)"
  exit 0
fi

echo "Installing prerequisites..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release

echo "Adding Docker’s official GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo "Setting up the repository..."
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" > /etc/apt/sources.list.d/docker.list

echo "Installing Docker..."
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

usermod -aG docker ${SUDO_USER:-$USER} || true

echo "Docker installed: $(docker --version)"
echo "You may need to log out and back in for docker group to apply."


