#!/usr/bin/env bash
# Start Minikube with Cilium as the CNI (replacing kube-proxy).
set -euo pipefail

PROFILE="cilium-demo"
K8S_VERSION="v1.32.0"
CPUS=4
MEMORY=8192

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo ""
echo "================================================"
echo "  🐝 Cilium in Action — Cluster Setup"
echo "================================================"
echo ""

# Check if profile already exists
if minikube status -p "$PROFILE" &>/dev/null 2>&1; then
    warn "Minikube profile '$PROFILE' already exists."
    read -rp "Delete and recreate? (y/N) " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        info "Deleting existing profile..."
        minikube delete -p "$PROFILE"
    else
        info "Reusing existing profile."
        echo ""
        echo "  Next: ./scripts/03-deploy-app.sh"
        exit 0
    fi
fi

# Start Minikube with no CNI (Cilium will be installed next)
info "Starting Minikube (profile=$PROFILE, k8s=$K8S_VERSION, CPUs=$CPUS, RAM=${MEMORY}MB)..."
minikube start \
    -p "$PROFILE" \
    --kubernetes-version="$K8S_VERSION" \
    --cpus="$CPUS" \
    --memory="$MEMORY" \
    --cni=false \
    --driver=docker

# Remove kube-proxy so Cilium can replace it with eBPF
info "Removing kube-proxy (Cilium will handle service routing via eBPF)..."
kubectl -n kube-system delete daemonset kube-proxy --ignore-not-found
kubectl -n kube-system delete configmap kube-proxy --ignore-not-found

# Discover the API server's direct address (Cilium needs this to bootstrap
# without kube-proxy — otherwise it can't resolve the kubernetes ClusterIP).
API_SERVER_IP=$(kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].addresses[0].ip}')
API_SERVER_PORT=$(kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].ports[0].port}')
info "API server at ${API_SERVER_IP}:${API_SERVER_PORT}"

# Install Cilium with kubeProxyReplacement
info "Installing Cilium with kube-proxy replacement and Hubble..."
cilium install \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost="${API_SERVER_IP}" \
    --set k8sServicePort="${API_SERVER_PORT}" \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true

# Wait for Cilium to be ready
info "Waiting for Cilium to become ready (this may take 2-3 minutes)..."
cilium status --wait

# Enable Hubble
info "Enabling Hubble observability..."
cilium hubble enable --ui

echo ""
info "Verifying Cilium installation..."
cilium status
echo ""

# Verify kube-proxy is NOT running
info "Confirming kube-proxy is NOT running (Cilium replaced it)..."
if kubectl get pods -n kube-system -l k8s-app=kube-proxy 2>/dev/null | grep -q "Running"; then
    warn "kube-proxy pods found — Cilium may not be fully replacing it."
else
    info "✅ No kube-proxy pods — Cilium eBPF is handling all service routing!"
fi

echo ""
echo "================================================"
echo "  ✅ Minikube + Cilium ready!"
echo ""
echo "  Cluster:  $PROFILE"
echo "  K8s:      $K8S_VERSION"
echo "  CNI:      Cilium (with kube-proxy replacement)"
echo "  Hubble:   Enabled (relay + UI)"
echo ""
echo "  Next: ./scripts/03-deploy-app.sh"
echo "================================================"
