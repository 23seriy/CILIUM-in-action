# 🐝 Cilium in Action

A hands-on project demonstrating **Cilium** — eBPF-powered networking, security, and observability for Kubernetes. Instead of traditional iptables-based networking, Cilium runs directly in the Linux kernel using eBPF, giving you L3/L4/L7 network policies, kube-proxy replacement, and real-time traffic visualization — all on your laptop.

The demo uses three NBA microservices to showcase how Cilium enforces zero-trust networking: only the public scoreboard can reach internal stats and news services, and even then, only with read-only HTTP methods.

![Cilium](https://img.shields.io/badge/Cilium-1.16-F8C517?logo=cilium&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32-326CE5?logo=kubernetes&logoColor=white)
![Minikube](https://img.shields.io/badge/Minikube-local-F7B93E?logo=kubernetes&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![eBPF](https://img.shields.io/badge/eBPF-kernel-FF6600?logoColor=white)

> 📝 **Read the full walkthrough on Medium:** _[Link coming soon]_

## 🏗️ Architecture

```text
                 ┌──────────────────────────────────────────────────┐
                 │                 Minikube Cluster                  │
                 │            (Cilium CNI, no kube-proxy)            │
                 │                                                  │
 NBA Fan ─────►  │  scoreboard-api ────────► stats-service          │
 localhost:9080 │  (public, port 8080)      (internal, player stats)│
                 │       │                                          │
                 │       └────────────────► news-service            │
                 │                          (internal, headlines)    │
                 │                                                  │
                 │  🔒 Cilium Network Policies (L3/L4/L7)          │
                 │  🔍 Hubble Flow Visualization                    │
                 │  ⚡ eBPF kube-proxy replacement                  │
                 │                                                  │
                 │  rogue-pod ──✖──► stats-service  (BLOCKED)      │
                 │             ──✖──► news-service   (BLOCKED)      │
                 └──────────────────────────────────────────────────┘
```

**scoreboard-api** — Public-facing NBA live scores. Calls stats-service and news-service internally.

**stats-service** — Internal player statistics. Exposes GET, POST, and DELETE endpoints — but Cilium's L7 policy restricts access to GET only.

**news-service** — Internal NBA headlines. Only scoreboard-api is allowed to reach it.

**rogue-pod** — Simulates an attacker or misconfigured workload. Used to demonstrate that unauthorized pods are blocked.

## 📋 What You'll Learn

| Cilium Feature | What It Does | Demo Scenario |
|---|---|---|
| **kube-proxy Replacement** | eBPF handles service routing instead of iptables | Start cluster without kube-proxy entirely |
| **L3/L4 Network Policy** | Allow/deny traffic by pod labels and ports | Only scoreboard-api → stats-service on port 8080 |
| **L7 HTTP Policy** | Filter by HTTP method, path, and headers | Allow GET /api/stats, block POST and DELETE |
| **DNS Egress Policy** | Control which domains pods can resolve | Block external data exfiltration |
| **Default Deny** | Zero-trust foundation — deny everything first | No pod can reach anything until explicitly allowed |
| **Hubble Observability** | Real-time traffic flow visualization | Watch allowed and dropped flows live |
| **Zero-Trust Setup** | Complete production-ready policy set | Combine all policies into a coherent security posture |

## 🚀 Quick Start

### Step 0: Clone the Repository

```bash
git clone https://github.com/23seriy/cilium-in-action.git
cd cilium-in-action
```

### Prerequisites

- **macOS** (scripts use Homebrew; adapt for Linux)
- **Docker Desktop** running
- ~8 GB RAM available for Minikube (Cilium + Hubble are moderately heavy)

### Step 1: Install Tools

```bash
chmod +x scripts/*.sh
./scripts/01-install-prerequisites.sh
```

This installs or verifies `minikube`, `kubectl`, `helm`, `cilium` CLI, and `hubble` CLI via Homebrew.

### Step 2: Start Cluster + Install Cilium

```bash
./scripts/02-start-cluster.sh
```

Creates a Minikube profile called `cilium-demo` on **Kubernetes `v1.32.0`** with **no kube-proxy** — Cilium replaces it entirely using eBPF. Also installs Hubble for flow observability.

### Step 3: Build & Deploy the Application

```bash
./scripts/03-deploy-app.sh
```

Builds Docker images inside Minikube's Docker daemon (no registry needed) and deploys all NBA services plus the rogue pod.

### Step 4: Access the Scoreboard

In a **separate terminal**:

```bash
kubectl port-forward svc/scoreboard-api 9080:8080 -n cilium-demo
```

Then try:

```bash
# Live scores
curl http://localhost:9080/scores

# Game detail with player stats
curl http://localhost:9080/scores/1

# NBA headlines
curl http://localhost:9080/headlines

# Health check
curl http://localhost:9080/health
```

### Step 5: Run the Demo Scenarios

```bash
./scripts/04-demo-scenarios.sh
```

This walks you through each Cilium feature interactively, applying policies and showing results.

## 🎮 Demo Scenarios

### 1. Baseline — Everyone Can Talk to Everyone

No policies applied. The rogue pod can freely access stats-service and news-service. This demonstrates why default-allow networking is dangerous.

### 2. L3/L4 Policy — Only Scoreboard Reaches Stats

```bash
kubectl apply -f cilium/02-allow-scoreboard-to-stats.yaml
kubectl apply -f cilium/03-allow-scoreboard-to-news.yaml
```

Only pods with label `app=scoreboard-api` can reach internal services. The rogue pod is locked out at the network layer.

### 3. L7 HTTP Policy — Read-Only Stats Access

```bash
kubectl apply -f cilium/04-l7-http-stats-policy.yaml
```

Cilium inspects HTTP requests at the kernel level. GET requests to `/api/stats*` pass through; POST and DELETE are blocked — even from the authorized scoreboard-api. This is the feature that sets Cilium apart from standard Kubernetes NetworkPolicy.

### 4. DNS Egress Policy — Control Outbound Access

```bash
kubectl apply -f cilium/05-dns-egress-policy.yaml
```

Scoreboard-api can only resolve and reach internal services. External domains (e.g., httpbin.org) are blocked, preventing data exfiltration.

### 5. Hubble Flow Visualization

```bash
# Terminal 1: Open the Hubble UI
cilium hubble ui
# Opens http://localhost:12000

# Terminal 2: Watch flows from CLI
hubble observe -n cilium-demo --follow

# Terminal 3: Watch dropped traffic only
hubble observe -n cilium-demo --verdict DROPPED
```

Generate traffic (`curl http://localhost:9080/scores/1`) and watch Hubble show allowed and dropped flows in real-time.

### 6. Full Zero-Trust — Production-Ready Setup

```bash
kubectl apply -f cilium/06-full-zero-trust.yaml
```

Combines default-deny with explicit allow rules:

| Source | Destination | Method | Verdict |
|---|---|---|---|
| scoreboard-api | stats-service | GET | ✅ ALLOWED |
| scoreboard-api | stats-service | POST/DELETE | ❌ BLOCKED |
| scoreboard-api | news-service | GET | ✅ ALLOWED |
| rogue-pod | stats-service | any | ❌ BLOCKED |
| rogue-pod | news-service | any | ❌ BLOCKED |
| stats-service | news-service | any | ❌ BLOCKED |

## 🔧 Useful Commands

```bash
# Cilium status
cilium status

# List Cilium endpoints
kubectl -n cilium-demo get ciliumendpoints

# List active policies
kubectl get cnp -n cilium-demo

# Describe a policy
kubectl describe cnp <policy-name> -n cilium-demo

# Run Cilium connectivity test (comprehensive)
cilium connectivity test

# Hubble CLI — observe flows
hubble observe -n cilium-demo --follow
hubble observe -n cilium-demo --verdict DROPPED
hubble observe -n cilium-demo --to-label app=stats-service

# Hubble UI
cilium hubble ui
```

## 📁 Project Structure

```text
cilium-in-action/
├── apps/
│   ├── scoreboard-api/         # Public NBA scoreboard (Flask)
│   │   ├── app.py              # Calls stats-service and news-service
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── stats-service/          # Internal player statistics (Flask)
│   │   ├── app.py              # GET/POST/DELETE endpoints for L7 demo
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── news-service/           # Internal NBA headlines (Flask)
│       ├── app.py
│       ├── Dockerfile
│       └── requirements.txt
├── k8s/                        # Kubernetes manifests
│   ├── namespace.yaml
│   ├── scoreboard-api.yaml     # Deployment + Service
│   ├── stats-service.yaml      # Deployment + Service
│   ├── news-service.yaml       # Deployment + Service
│   └── rogue-pod.yaml          # Attacker simulation pod
├── cilium/                     # Cilium Network Policies
│   ├── 01-default-deny.yaml              # Zero-trust foundation
│   ├── 02-allow-scoreboard-to-stats.yaml # L3/L4: scoreboard → stats
│   ├── 03-allow-scoreboard-to-news.yaml  # L3/L4: scoreboard → news
│   ├── 04-l7-http-stats-policy.yaml      # L7: GET only on stats
│   ├── 05-dns-egress-policy.yaml         # DNS: block external egress
│   └── 06-full-zero-trust.yaml           # Complete production policy set
├── scripts/                    # Automation scripts
│   ├── 01-install-prerequisites.sh
│   ├── 02-start-cluster.sh
│   ├── 03-deploy-app.sh
│   ├── 04-demo-scenarios.sh
│   └── 05-teardown.sh
├── docs/
│   └── medium-story.md         # Full Medium article
└── .gitignore
```

## 🧹 Teardown

```bash
./scripts/05-teardown.sh
```

Deletes all Cilium policies, uninstalls Cilium, and removes the Minikube cluster.

## 💡 Key Takeaways

1. **eBPF replaces iptables** — Cilium runs network logic directly in the Linux kernel. No more iptables chain bloat, no kube-proxy bottleneck. Service routing and policy enforcement happen at kernel speed.

2. **L7 policies are a game-changer** — Standard Kubernetes NetworkPolicy only works at L3/L4 (IP + port). Cilium goes deeper: filter by HTTP method, URL path, headers, and even gRPC methods. "Allow GET but block DELETE" is one YAML file.

3. **Hubble makes traffic visible** — Real-time flow visualization shows exactly who's talking to whom, what's allowed, and what's dropped. Debugging network issues goes from guessing to observing.

4. **Zero-trust is achievable** — Start with default-deny, then add explicit allow rules. The result is a network where every connection is intentional and auditable.

5. **No sidecars needed** — Unlike Istio's sidecar-per-pod model, Cilium runs as a DaemonSet. No extra containers, no added latency, no pod startup delays.

6. **DNS-aware egress prevents exfiltration** — Control not just which IPs pods can reach, but which DNS names they can resolve. A compromised pod can't phone home.

## 📚 Resources

- [Cilium Documentation](https://docs.cilium.io/)
- [Cilium Network Policies](https://docs.cilium.io/en/stable/security/policy/)
- [Hubble Documentation](https://docs.cilium.io/en/stable/observability/)
- [eBPF.io — What is eBPF?](https://ebpf.io/)
- [Cilium — Kube-Proxy Replacement](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)

## 📝 License

MIT — Use freely for learning, demos, and presentations.
