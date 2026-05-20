#!/usr/bin/env bash
# Install prerequisites for Cilium in Action demo.
# Installs: minikube, kubectl, helm, cilium-cli, hubble-cli
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

install_if_missing() {
    local tool=$1
    local tap=${2:-""}
    if command -v "$tool" &>/dev/null; then
        info "$tool already installed: $(command -v "$tool")"
    else
        if [ -n "$tap" ]; then
            info "Tapping $tap..."
            brew tap "$tap"
        fi
        info "Installing $tool via Homebrew..."
        brew install "$tool"
    fi
}

echo ""
echo "================================================"
echo "  🐝 Cilium in Action — Prerequisites Installer"
echo "================================================"
echo ""

# Check Homebrew
if ! command -v brew &>/dev/null; then
    echo "❌ Homebrew is required. Install from https://brew.sh"
    exit 1
fi
info "Homebrew found"

# Check Docker
if ! command -v docker &>/dev/null; then
    echo "❌ Docker Desktop is required. Install from https://www.docker.com/products/docker-desktop/"
    exit 1
fi
if ! docker info &>/dev/null 2>&1; then
    warn "Docker is installed but not running. Please start Docker Desktop."
    exit 1
fi
info "Docker is running"

# Install tools
install_if_missing minikube
install_if_missing kubectl
install_if_missing helm
install_if_missing cilium
install_if_missing hubble

echo ""
echo "================================================"
echo "  ✅ All prerequisites installed!"
echo ""
echo "  Next: ./scripts/02-start-cluster.sh"
echo "================================================"
