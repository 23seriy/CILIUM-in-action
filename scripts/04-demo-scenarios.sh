#!/usr/bin/env bash
# Interactive demo walkthrough for Cilium in Action.
set -euo pipefail

NAMESPACE="cilium-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[FAIL]${NC} $*"; }
section() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}  $*${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

pause() {
    echo ""
    read -rp "  Press ENTER to continue to the next scenario... "
    echo ""
}

cleanup_policies() {
    info "Cleaning up previous Cilium policies..."
    kubectl delete cnp --all -n "$NAMESPACE" 2>/dev/null || true
    sleep 2
}

echo ""
echo "================================================"
echo "  🐝 Cilium in Action — Demo Scenarios"
echo "================================================"
echo ""
echo "  Make sure port-forwarding is running:"
echo "    kubectl port-forward svc/scoreboard-api 9080:8080 -n $NAMESPACE"
echo ""
pause

# ─────────────────────────────────────────────────────────────
section "Scenario 1: Baseline — Everyone Can Talk to Everyone"
# ─────────────────────────────────────────────────────────────

cleanup_policies

info "No Cilium policies applied. All pods can communicate freely."
echo ""

info "1a. Scoreboard calls stats-service (should work):"
echo "    curl http://localhost:9080/scores/1"
echo ""
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "import requests; r=requests.get('http://stats-service:8080/api/stats/game/1'); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    info "✅ scoreboard → stats-service: ALLOWED" || \
    error "❌ scoreboard → stats-service: BLOCKED"

echo ""
info "1b. Rogue pod calls stats-service (should also work — no policies!):"
kubectl exec -n "$NAMESPACE" rogue-pod -- \
    curl -s -o /dev/null -w "  Status: %{http_code}" http://stats-service:8080/api/stats 2>/dev/null && \
    echo "" && warn "⚠️  rogue-pod → stats-service: ALLOWED (no protection!)" || \
    echo "" && info "rogue-pod → stats-service: BLOCKED"

echo ""
warn "Without network policies, any pod in the namespace can access any service."
warn "The rogue pod just read all your player stats. Let's fix that."
pause

# ─────────────────────────────────────────────────────────────
section "Scenario 2: L3/L4 Policy — Only Scoreboard Reaches Stats"
# ─────────────────────────────────────────────────────────────

cleanup_policies

info "Applying L3/L4 policy: only scoreboard-api → stats-service on port 8080..."
kubectl apply -f "$PROJECT_DIR/cilium/02-allow-scoreboard-to-stats.yaml"
kubectl apply -f "$PROJECT_DIR/cilium/03-allow-scoreboard-to-news.yaml"
sleep 3

info "2a. Scoreboard calls stats-service:"
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "import requests; r=requests.get('http://stats-service:8080/api/stats/game/1'); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    info "✅ scoreboard → stats-service: ALLOWED" || \
    error "❌ scoreboard → stats-service: BLOCKED (unexpected)"

echo ""
info "2b. Rogue pod tries to call stats-service:"
kubectl exec -n "$NAMESPACE" rogue-pod -- \
    curl -s --connect-timeout 3 -o /dev/null -w "  Status: %{http_code}" http://stats-service:8080/api/stats 2>/dev/null && \
    echo "" && warn "⚠️  rogue-pod → stats-service: ALLOWED (policy not blocking)" || \
    echo "" && info "✅ rogue-pod → stats-service: BLOCKED by Cilium L3/L4 policy"

echo ""
info "The rogue pod is now locked out. Only scoreboard-api can reach internal services."
pause

# ─────────────────────────────────────────────────────────────
section "Scenario 3: L7 HTTP Policy — Read-Only Stats Access"
# ─────────────────────────────────────────────────────────────

cleanup_policies

info "Applying L7 HTTP policy: scoreboard-api can only GET from stats-service."
info "POST and DELETE are blocked — even from authorized services."
kubectl apply -f "$PROJECT_DIR/cilium/04-l7-http-stats-policy.yaml"
kubectl apply -f "$PROJECT_DIR/cilium/03-allow-scoreboard-to-news.yaml"
sleep 3

info "3a. GET /api/stats/game/1 (should work):"
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "import requests; r=requests.get('http://stats-service:8080/api/stats/game/1'); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    info "✅ GET stats: ALLOWED" || \
    error "❌ GET stats: BLOCKED (unexpected)"

echo ""
info "3b. POST /api/stats/update (should be BLOCKED by L7 policy):"
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "import requests; r=requests.post('http://stats-service:8080/api/stats/update', json={'test': True}); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    warn "⚠️  POST stats: ALLOWED (L7 policy may need time)" || \
    info "✅ POST stats: BLOCKED by Cilium L7 HTTP policy"

echo ""
info "3c. DELETE /api/stats/game/1 (should be BLOCKED):"
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "import requests; r=requests.delete('http://stats-service:8080/api/stats/game/1'); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    warn "⚠️  DELETE stats: ALLOWED (L7 policy may need time)" || \
    info "✅ DELETE stats: BLOCKED by Cilium L7 HTTP policy"

echo ""
info "This is Cilium's superpower: HTTP-aware policies at the kernel level via eBPF."
info "Traditional NetworkPolicy can only filter by IP and port — not by HTTP method or path."
pause

# ─────────────────────────────────────────────────────────────
section "Scenario 4: DNS Egress Policy — Control Outbound Access"
# ─────────────────────────────────────────────────────────────

cleanup_policies

info "Applying DNS egress policy: scoreboard-api can only reach internal services."
kubectl apply -f "$PROJECT_DIR/cilium/05-dns-egress-policy.yaml"
kubectl apply -f "$PROJECT_DIR/cilium/02-allow-scoreboard-to-stats.yaml"
kubectl apply -f "$PROJECT_DIR/cilium/03-allow-scoreboard-to-news.yaml"
sleep 3

info "4a. Scoreboard → stats-service (internal, should work):"
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "import requests; r=requests.get('http://stats-service:8080/health'); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    info "✅ Internal traffic: ALLOWED" || \
    error "❌ Internal traffic: BLOCKED (unexpected)"

echo ""
info "4b. Scoreboard → external domain (should be BLOCKED):"
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "
import requests
try:
    r=requests.get('https://httpbin.org/get', timeout=3)
    print(f'  Status: {r.status_code}')
except Exception as e:
    print(f'  Blocked: {type(e).__name__}')
" 2>/dev/null
info "Egress is restricted — pods can't exfiltrate data to external domains."
pause

# ─────────────────────────────────────────────────────────────
section "Scenario 5: Hubble Flow Visualization"
# ─────────────────────────────────────────────────────────────

cleanup_policies
kubectl apply -f "$PROJECT_DIR/cilium/02-allow-scoreboard-to-stats.yaml"
kubectl apply -f "$PROJECT_DIR/cilium/03-allow-scoreboard-to-news.yaml"
sleep 2

info "Hubble lets you observe all traffic flows in real-time."
info "Open the Hubble UI in another terminal:"
echo ""
echo "    cilium hubble ui"
echo "    # Opens http://localhost:12000"
echo ""
info "Or watch flows from the CLI:"
echo ""
echo "    hubble observe -n $NAMESPACE --follow"
echo "    hubble observe -n $NAMESPACE --verdict DROPPED"
echo ""
info "Generate some traffic:"
echo ""
echo "    curl http://localhost:9080/scores/1"
echo "    curl http://localhost:9080/headlines"
echo ""
info "Watch Hubble show allowed and dropped flows in real-time."
pause

# ─────────────────────────────────────────────────────────────
section "Scenario 6: Full Zero-Trust — Production-Ready Setup"
# ─────────────────────────────────────────────────────────────

cleanup_policies

info "Applying full zero-trust policy set..."
kubectl apply -f "$PROJECT_DIR/cilium/06-full-zero-trust.yaml"
sleep 5

info "6a. Scoreboard → stats-service (GET, should work):"
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "import requests; r=requests.get('http://stats-service:8080/api/stats/game/1'); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    info "✅ ALLOWED" || error "❌ BLOCKED (unexpected)"

echo ""
info "6b. Scoreboard → news-service (should work):"
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "import requests; r=requests.get('http://news-service:8080/api/news'); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    info "✅ ALLOWED" || error "❌ BLOCKED (unexpected)"

echo ""
info "6c. Rogue pod → stats-service (should be BLOCKED):"
kubectl exec -n "$NAMESPACE" rogue-pod -- \
    curl -s --connect-timeout 3 -o /dev/null -w "  Status: %{http_code}" http://stats-service:8080/api/stats 2>/dev/null && \
    echo "" && warn "⚠️  ALLOWED (unexpected)" || \
    echo "" && info "✅ BLOCKED — zero-trust in action"

echo ""
info "6d. Rogue pod → news-service (should be BLOCKED):"
kubectl exec -n "$NAMESPACE" rogue-pod -- \
    curl -s --connect-timeout 3 -o /dev/null -w "  Status: %{http_code}" http://news-service:8080/api/news 2>/dev/null && \
    echo "" && warn "⚠️  ALLOWED (unexpected)" || \
    echo "" && info "✅ BLOCKED — zero-trust in action"

echo ""
info "6e. Scoreboard → stats-service POST (should be BLOCKED by L7):"
kubectl exec -n "$NAMESPACE" deploy/scoreboard-api -- \
    python -c "import requests; r=requests.post('http://stats-service:8080/api/stats/update', json={}); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    warn "⚠️  POST ALLOWED (check L7 rules)" || \
    info "✅ POST BLOCKED — read-only access enforced"

echo ""
info "Zero-trust summary:"
info "  ✅ scoreboard-api → stats-service (GET only)"
info "  ✅ scoreboard-api → news-service"
info "  ❌ rogue-pod → anything"
info "  ❌ stats-service → news-service (lateral movement blocked)"
info "  ❌ POST/DELETE to stats-service (even from authorized pods)"

echo ""
echo "================================================"
echo "  🎉 All demo scenarios complete!"
echo ""
echo "  Explore more:"
echo "    cilium hubble ui          # Visualize traffic flows"
echo "    cilium status             # Check Cilium health"
echo "    cilium connectivity test  # Full connectivity validation"
echo "    kubectl get cnp -n $NAMESPACE  # List active policies"
echo ""
echo "  Teardown: ./scripts/05-teardown.sh"
echo "================================================"
