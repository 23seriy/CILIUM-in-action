#!/usr/bin/env bash
# Clean up everything: delete namespace, uninstall Cilium, remove Minikube profile.
set -euo pipefail

PROFILE="cilium-demo"
NAMESPACE="cilium-demo"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo ""
echo "================================================"
echo "  🐝 Cilium in Action — Teardown"
echo "================================================"
echo ""

read -rp "This will delete the Minikube cluster '$PROFILE'. Continue? (y/N) " answer
if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    info "Cancelled."
    exit 0
fi

# Delete namespace
info "Deleting namespace '$NAMESPACE'..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found --timeout=60s 2>/dev/null || true

# Uninstall Cilium
info "Uninstalling Cilium..."
cilium uninstall 2>/dev/null || true

# Delete Minikube profile
info "Deleting Minikube profile '$PROFILE'..."
minikube delete -p "$PROFILE"

echo ""
echo "================================================"
echo "  ✅ Teardown complete. System is clean."
echo "================================================"
