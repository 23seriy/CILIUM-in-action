# Cilium in Action: eBPF-Powered Networking, Security, and Observability for Kubernetes — Without Sidecars

_A hands-on guide to replacing kube-proxy, enforcing L7 HTTP policies, and visualizing traffic flows — all on your laptop._

---

## Your Kubernetes Network Is a Free-for-All

Here's something most Kubernetes tutorials won't tell you: **by default, every pod in your cluster can talk to every other pod.** No authentication, no authorization, no visibility.

Deploy a compromised container? It can reach your database. A misconfigured service? It can scrape secrets from your API. A rogue pod? It can exfiltrate data to any external domain it wants.

Traditional Kubernetes NetworkPolicy helps — but only at the IP and port level. Want to allow `GET /api/stats` but block `DELETE /api/stats`? Standard NetworkPolicy can't do that. You'd need a service mesh with sidecars, adding latency and complexity.

**Cilium changes everything.** It runs in the Linux kernel using eBPF (extended Berkeley Packet Filter), giving you:

- **L3/L4/L7 network policies** — filter by HTTP method, URL path, and headers
- **kube-proxy replacement** — eBPF handles service routing instead of iptables
- **Hubble** — real-time traffic flow visualization
- **No sidecars** — runs as a DaemonSet, no extra containers per pod

In this article, I'll walk you through building a complete Cilium demo on your laptop. We'll deploy three NBA microservices, start with zero security, and progressively tighten the network until we achieve zero-trust — all with simple YAML files.

> **Full source code:** [github.com/23seriy/cilium-in-action](https://github.com/23seriy/cilium-in-action)

---

## What We're Building

```
                 ┌──────────────────────────────────────────────────┐
                 │                 Minikube Cluster                  │
                 │            (Cilium CNI, no kube-proxy)            │
                 │                                                  │
 NBA Fan ─────►  │  scoreboard-api ────────► stats-service          │
 localhost:9080 │  (public)                 (internal)              │
                 │       │                                          │
                 │       └────────────────► news-service            │
                 │                          (internal)              │
                 │                                                  │
                 │  rogue-pod ──✖──► stats-service  (BLOCKED)      │
                 │             ──✖──► news-service   (BLOCKED)      │
                 └──────────────────────────────────────────────────┘
```

Three Flask microservices themed around NBA live scores:

- **scoreboard-api** — The public-facing service. Fans hit this to see live scores, player stats, and headlines. It calls the two internal services.
- **stats-service** — Internal. Provides player statistics with GET, POST, and DELETE endpoints. We'll use Cilium's L7 policy to allow only GET.
- **news-service** — Internal. Provides NBA headlines. Only scoreboard-api should be able to reach it.
- **rogue-pod** — A `curl` container simulating an attacker. We'll use it to prove our policies work.

---

## Why eBPF (and Why It Matters for Your Career)

If you're a DevOps/platform engineer and you haven't looked at eBPF yet, now is the time. Here's why:

**eBPF runs inside the Linux kernel** — not in userspace. When Cilium processes a packet, it doesn't context-switch between kernel and userspace like iptables does. It runs a small, verified program directly in the kernel's networking stack.

The result? **Faster packet processing, lower latency, and no iptables chain bloat.** Clusters with thousands of services no longer choke on iptables rules.

But the real superpower is **programmability.** eBPF programs can inspect packet payloads — including HTTP headers, methods, and paths. That's how Cilium enforces L7 policies at kernel speed without sidecars.

Major adopters: Google (GKE), AWS (EKS), Azure (AKS), Datadog, Cloudflare, and many more run Cilium in production. The CNCF graduated Cilium in 2024.

---

## Step 1: Start the Cluster Without kube-proxy

This is the first "whoa" moment. We start Minikube with no CNI, then **remove kube-proxy** and let Cilium take over:

```bash
# Start the cluster with no CNI
minikube start \
    -p cilium-demo \
    --kubernetes-version=v1.32.0 \
    --cpus=4 \
    --memory=8192 \
    --cni=false \
    --driver=docker

# Remove kube-proxy — Cilium will replace it
kubectl -n kube-system delete daemonset kube-proxy --ignore-not-found
kubectl -n kube-system delete configmap kube-proxy --ignore-not-found
```

Then we install Cilium with kube-proxy replacement enabled. The key detail: we pass the API server's direct IP so Cilium can bootstrap without needing kube-proxy to route to the `kubernetes` ClusterIP:

```bash
# Get the API server's direct address
API_SERVER_IP=$(kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].addresses[0].ip}')
API_SERVER_PORT=$(kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].ports[0].port}')

cilium install \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=${API_SERVER_IP} \
    --set k8sServicePort=${API_SERVER_PORT} \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true
```

Without `k8sServiceHost`, Cilium tries to reach the API server via the `kubernetes` ClusterIP — but nobody is routing that traffic anymore (we just deleted kube-proxy). Classic chicken-and-egg problem.

Cilium's eBPF programs now handle all service routing — ClusterIP, NodePort, LoadBalancer — directly in the kernel. You can verify:

```bash
# No kube-proxy pods
kubectl get pods -n kube-system -l k8s-app=kube-proxy
# (empty — deleted and not coming back)

# Cilium is healthy
cilium status
```

---

## Step 2: Deploy the NBA Services

We build images on the host and load them into Minikube (building inside Minikube's Docker daemon can fail because external DNS may not work after kube-proxy removal):

```bash
# Build locally
docker build -t scoreboard-api:local apps/scoreboard-api/
docker build -t stats-service:local apps/stats-service/
docker build -t news-service:local apps/news-service/

# Load into Minikube
minikube image load scoreboard-api:local -p cilium-demo
minikube image load stats-service:local -p cilium-demo
minikube image load news-service:local -p cilium-demo

kubectl apply -f k8s/
```

Four pods come up: three services and one rogue pod. Cilium immediately assigns each an identity and tracks them as endpoints:

```bash
kubectl -n cilium-demo get ciliumendpoints
```

Each endpoint gets a numeric identity based on its labels — this is how Cilium makes policy decisions at kernel speed without IP lookups.

---

## Scenario 1: The Problem — No Policies

With no Cilium policies applied, let's see what the rogue pod can do:

```bash
# Rogue pod reads player stats (should it be able to?)
kubectl exec -n cilium-demo rogue-pod -- \
    curl -s http://stats-service:8080/api/stats

# Rogue pod reads news (this is an internal service!)
kubectl exec -n cilium-demo rogue-pod -- \
    curl -s http://news-service:8080/api/news
```

Both succeed with `200 OK`. **The rogue pod has full access to your internal services.** In a real cluster, this could be a compromised container reading your database, scraping credentials, or exfiltrating data.

---

## Scenario 2: L3/L4 Policy — Lock the Doors

Let's apply the first policy. This tells Cilium: "Only pods labeled `app=scoreboard-api` can reach `stats-service` on port 8080."

```yaml
# cilium/02-allow-scoreboard-to-stats.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-scoreboard-to-stats
  namespace: cilium-demo
spec:
  endpointSelector:
    matchLabels:
      app: stats-service
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: scoreboard-api
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

```bash
kubectl apply -f cilium/02-allow-scoreboard-to-stats.yaml
kubectl apply -f cilium/03-allow-scoreboard-to-news.yaml
```

Now test:

```bash
# Scoreboard → stats: works ✅
kubectl exec -n cilium-demo deploy/scoreboard-api -- \
    python -c "import requests; print(requests.get('http://stats-service:8080/api/stats').status_code)"
# 200

# Rogue → stats: blocked ❌
kubectl exec -n cilium-demo rogue-pod -- \
    curl -s --connect-timeout 3 http://stats-service:8080/api/stats
# (timeout — connection dropped)
```

The rogue pod's request never reaches stats-service. Cilium's eBPF program in the kernel drops the packet before it even enters the service's network stack. No firewall rules, no iptables — just a tiny eBPF program saying "nope."

---

## Scenario 3: L7 HTTP Policy — This Is the Killer Feature

This is where Cilium leaves standard NetworkPolicy in the dust. We want to allow scoreboard-api to **read** stats but not **modify** them:

```yaml
# cilium/04-l7-http-stats-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l7-stats-read-only
  namespace: cilium-demo
spec:
  endpointSelector:
    matchLabels:
      app: stats-service
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: scoreboard-api
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: GET
                path: "/api/stats.*"
              - method: GET
                path: "/health"
```

**Important gotcha:** Cilium unions all policies matching the same endpoint. If the L3/L4 policy from Scenario 2 is still active, it allows all TCP on port 8080 — overriding the L7 restrictions. You must remove it first:

```bash
# Remove the broad L3/L4 policy so the L7 restrictions take effect
kubectl delete cnp allow-scoreboard-to-stats -n cilium-demo

kubectl apply -f cilium/04-l7-http-stats-policy.yaml
```

Now test all three HTTP methods:

```bash
# GET — allowed ✅
curl http://localhost:9080/scores/1
# Returns game data with player stats

# POST — blocked ❌
kubectl exec -n cilium-demo deploy/scoreboard-api -- \
    python -c "import requests; print(requests.post('http://stats-service:8080/api/stats/update', json={}).status_code)"
# 403 (Access denied by Cilium L7 policy)

# DELETE — blocked ❌
kubectl exec -n cilium-demo deploy/scoreboard-api -- \
    python -c "import requests; print(requests.delete('http://stats-service:8080/api/stats/game/1').status_code)"
# 403 (Access denied by Cilium L7 policy)
```

**Read that again:** We're filtering HTTP methods and URL paths in a network policy. The scoreboard can look at the stat sheet, but it can't edit it. This happens at the kernel level, before the request reaches Flask. No sidecar proxy, no application changes.

With standard Kubernetes NetworkPolicy, you'd need:
1. An Istio sidecar on every pod, or
2. Application-level authorization code, or
3. A separate API gateway with route-level ACLs.

With Cilium, it's **six lines of YAML.**

---

## Scenario 4: DNS Egress — Prevent Data Exfiltration

Most teams focus on ingress policies and forget about egress. A compromised pod can resolve any DNS name and send data to `evil-server.com`:

```yaml
# cilium/05-dns-egress-policy.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: scoreboard-egress-dns
  namespace: cilium-demo
spec:
  endpointSelector:
    matchLabels:
      app: scoreboard-api
  egress:
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
    - toEndpoints:
        - matchLabels:
            app: stats-service
        - matchLabels:
            app: news-service
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
```

Now the scoreboard can only talk to kube-dns (for name resolution) and its two internal services. Any attempt to reach an external domain is silently dropped.

---

## Scenario 5: Hubble — See Everything

This is my favorite part. Hubble is Cilium's observability layer. It shows you every flow in real-time:

```bash
# Start the Hubble port-forward (required for CLI access)
cilium hubble port-forward &

# Open the Hubble UI
cilium hubble ui
# Opens http://localhost:12000

# Or from the CLI
hubble observe -n cilium-demo --follow

# Only dropped traffic
hubble observe -n cilium-demo --verdict DROPPED
```

Generate some traffic and watch Hubble light up. You'll see:

- **Green flows:** scoreboard-api → stats-service (allowed by policy)
- **Red flows:** rogue-pod → stats-service (dropped by policy)
- **Flow details:** source identity, destination, port, HTTP method, verdict

This is what debugging network issues should look like. Instead of guessing with `tcpdump` and `nslookup`, you see exactly who's talking to whom, what's allowed, and what's blocked.

---

## Scenario 6: Full Zero-Trust

The final setup combines everything into a production-ready posture:

```bash
kubectl apply -f cilium/06-full-zero-trust.yaml
```

This applies:
1. **Default deny** — nothing can talk to anything
2. **DNS exception** — pods can resolve internal names
3. **Explicit ingress** — scoreboard-api accepts external traffic
4. **Explicit egress** — scoreboard-api can reach stats + news
5. **L7 restriction** — stats-service only accepts GET

The result:

| Source | → Destination | Method | Verdict |
|--------|--------------|--------|---------|
| scoreboard-api | stats-service | GET | ✅ |
| scoreboard-api | stats-service | POST | ❌ |
| scoreboard-api | news-service | GET | ✅ |
| rogue-pod | stats-service | any | ❌ |
| rogue-pod | news-service | any | ❌ |
| stats-service | news-service | any | ❌ |

Every connection is intentional. Every other connection is denied. That's zero-trust.

---

## Why This Matters (Beyond the Demo)

### Cilium vs. Istio

The elephant in the room. Both provide traffic management and security. Here's the practical difference:

| Aspect | Cilium | Istio |
|--------|--------|-------|
| Architecture | DaemonSet (one per node) | Sidecar (one per pod) |
| Overhead | ~200MB per node | ~100MB per pod × N pods |
| Latency | Kernel-level (microseconds) | Userspace proxy (milliseconds) |
| L7 policies | eBPF (kernel) | Envoy proxy (userspace) |
| mTLS | WireGuard (kernel) | Envoy (userspace) |
| Installation | One command | Complex (istiod, gateways, sidecars) |
| Learning curve | Moderate | Steep |

Cilium is not a full replacement for Istio — it doesn't do traffic mirroring, retries, or circuit breaking (yet). But for networking, security, and observability, it's lighter, faster, and simpler.

### When to Use Cilium

- **You need L7 policies without a service mesh** — Cilium's sweet spot.
- **iptables is a bottleneck** — Large clusters with thousands of services benefit from eBPF routing.
- **You want observability without instrumentation** — Hubble gives you flow visibility for free.
- **You're already on a managed Kubernetes** — GKE, EKS, and AKS all support Cilium natively.

### When to Keep Istio

- You need advanced traffic management (retries, timeouts, circuit breaking).
- You need traffic mirroring for testing.
- You're already invested in the Envoy/Istio ecosystem.

---

## Quick Start (5 Minutes)

```bash
git clone https://github.com/23seriy/cilium-in-action.git
cd cilium-in-action

# Install tools
./scripts/01-install-prerequisites.sh

# Start cluster with Cilium (no kube-proxy)
./scripts/02-start-cluster.sh

# Deploy NBA services
./scripts/03-deploy-app.sh

# Port-forward (separate terminal)
kubectl port-forward svc/scoreboard-api 9080:8080 -n cilium-demo

# Run demo scenarios
./scripts/04-demo-scenarios.sh

# Clean up
./scripts/05-teardown.sh
```

---

## Key Takeaways

1. **eBPF is the future of Kubernetes networking.** Cilium runs network logic in the kernel — no iptables chains, no userspace proxies.

2. **L7 policies without sidecars.** Filter HTTP methods and paths in a network policy. Six lines of YAML instead of a full service mesh.

3. **Zero-trust is just YAML.** Start with default-deny, add explicit allows. Every connection is intentional.

4. **Hubble makes the invisible visible.** Real-time flow visualization turns network debugging from guessing to observing.

5. **kube-proxy is optional.** Cilium replaces it entirely with eBPF-based service routing. One less component to manage.

6. **The best security is the kind that runs in the kernel.** By the time a packet reaches your application, Cilium has already decided whether to allow it.

---

_The complete source code, scripts, and Cilium policies are available at [github.com/23seriy/cilium-in-action](https://github.com/23seriy/cilium-in-action). Clone it, run the scripts, break things, and learn eBPF networking by doing._

_If you found this useful, previously in this series: [Argo Rollouts in Action](https://medium.com/@sergeiolshanetski/argo-rollouts-in-action), [Crossplane in Action](https://medium.com/@sergeiolshanetski), [Istio in Action](https://medium.com/@sergeiolshanetski/istio-in-action), and [KEDA in Action](https://medium.com/@sergeiolshanetski/keda-in-action)._

---

**If this article helped you, here's how you can support it:**

👏 **Hit the clap button up to 50 times** — just hold it down. It takes a second but makes a real difference. Medium's algorithm uses claps to surface articles to more readers.

🔔 **Follow me on Medium** and **subscribe** to get new hands-on DevOps guides delivered straight to your inbox.
