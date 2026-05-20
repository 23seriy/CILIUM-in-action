#!/usr/bin/env bash
# Build images inside Minikube and deploy the NBA services.
set -euo pipefail

PROFILE="cilium-demo"
NAMESPACE="cilium-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

echo ""
echo "================================================"
echo "  🐝 Cilium in Action — Deploy NBA Services"
echo "================================================"
echo ""

# Build images locally (Minikube's Docker daemon may lack external DNS after
# kube-proxy removal, so we build on the host and load into Minikube).
info "Building scoreboard-api image..."
docker build -t scoreboard-api:local "$PROJECT_DIR/apps/scoreboard-api"

info "Building stats-service image..."
docker build -t stats-service:local "$PROJECT_DIR/apps/stats-service"

info "Building news-service image..."
docker build -t news-service:local "$PROJECT_DIR/apps/news-service"

# Load images into Minikube
info "Loading images into Minikube..."
minikube image load scoreboard-api:local -p "$PROFILE"
minikube image load stats-service:local -p "$PROFILE"
minikube image load news-service:local -p "$PROFILE"

# Create namespace
info "Creating namespace '$NAMESPACE'..."
kubectl apply -f "$PROJECT_DIR/k8s/namespace.yaml"

# Deploy services
info "Deploying NBA services..."
kubectl apply -f "$PROJECT_DIR/k8s/scoreboard-api.yaml"
kubectl apply -f "$PROJECT_DIR/k8s/stats-service.yaml"
kubectl apply -f "$PROJECT_DIR/k8s/news-service.yaml"

# Deploy rogue pod for security demos
info "Deploying rogue pod (for security scenarios)..."
kubectl apply -f "$PROJECT_DIR/k8s/rogue-pod.yaml"

# Wait for all pods to be ready
info "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=scoreboard-api -n "$NAMESPACE" --timeout=120s
kubectl wait --for=condition=ready pod -l app=stats-service -n "$NAMESPACE" --timeout=120s
kubectl wait --for=condition=ready pod -l app=news-service -n "$NAMESPACE" --timeout=120s
kubectl wait --for=condition=ready pod/rogue-pod -n "$NAMESPACE" --timeout=120s

echo ""
info "All pods running:"
kubectl get pods -n "$NAMESPACE" -o wide
echo ""

# Verify Cilium sees the endpoints
info "Cilium endpoint status:"
kubectl -n "$NAMESPACE" get ciliumendpoints
echo ""

echo "================================================"
echo "  ✅ NBA services deployed!"
echo ""
echo "  Services:"
echo "    scoreboard-api — public scoreboard (port 8080)"
echo "    stats-service  — internal player stats"
echo "    news-service   — internal NBA news"
echo "    rogue-pod      — attacker simulation"
echo ""
echo "  Access the scoreboard:"
echo "    kubectl port-forward svc/scoreboard-api 9080:8080 -n $NAMESPACE"
echo "    open http://localhost:9080/scores"
echo ""
echo "  Next: ./scripts/04-demo-scenarios.sh"
echo "================================================"
