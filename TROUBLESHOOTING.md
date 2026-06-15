# Troubleshooting Guide

Common issues and fixes when running cilium-in-action.

## Installation & Prerequisites

### `command not found: minikube` / `kubectl` / `cilium` / `hubble`

The `01-install-prerequisites.sh` script installs everything via Homebrew. Rerun:

```bash
chmod +x scripts/01-install-prerequisites.sh
./scripts/01-install-prerequisites.sh
```

Or install manually:

```bash
brew install minikube kubectl cilium-cli hubble helm
```

### Docker Desktop is not running

Start it first:

```bash
open /Applications/Docker.app
```

Wait until the menu bar shows "Docker Desktop is running."

### Minikube won't start / out of resources

Minikube + Cilium + Hubble need ~8 GB RAM. Check your free memory:

```bash
sysctl hw.memsize | awk '{print $2 / 1024 / 1024 / 1024 " GB total"}'
```

If under 8 GB available:

- Close other apps
- Lower Docker Desktop's memory in **Preferences → Resources → Memory**
- Tear down a previous cluster: `./scripts/05-teardown.sh`

## Cluster Setup Issues

### `cilium status` shows pods not Ready

Wait longer (Cilium can take 2–3 minutes on first install):

```bash
cilium status --wait
```

If still failing, inspect the operator:

```bash
kubectl -n kube-system logs deploy/cilium-operator
kubectl -n kube-system get pods -l k8s-app=cilium
```

### `kube-proxy` still running

Scripts/02 deletes it explicitly. If you see it:

```bash
kubectl -n kube-system delete daemonset kube-proxy --ignore-not-found
kubectl -n kube-system delete configmap kube-proxy --ignore-not-found
```

Then restart Cilium:

```bash
kubectl -n kube-system rollout restart daemonset/cilium
```

### Cilium can't reach the API server (no kube-proxy)

`scripts/02` passes `k8sServiceHost` / `k8sServicePort` explicitly. If you installed manually, get them with:

```bash
kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].addresses[0].ip}:{.subsets[0].ports[0].port}'
```

## Pod Issues

### Pods stuck in `CreateContainerConfigError`

Usually the image isn't loaded into Minikube's Docker daemon. Re-run:

```bash
./scripts/03-deploy-app.sh
```

Or load manually:

```bash
docker build -t scoreboard-api:local apps/scoreboard-api
minikube image load scoreboard-api:local -p cilium-demo
```

### Pods stuck in `CrashLoopBackOff` after hardening

The Pods run as UID 10001 with a read-only root filesystem. If you customized a container that needs to write somewhere besides `/tmp`, add a writable `emptyDir` mount:

```yaml
volumeMounts:
  - name: cache
    mountPath: /var/cache/myapp
volumes:
  - name: cache
    emptyDir: {}
```

### Liveness/readiness probe failures

The Flask apps serve `/health` on port 8080. Confirm:

```bash
kubectl exec -n cilium-demo deploy/scoreboard-api -- \
  python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8080/health').status)"
```

Expect `200`.

## Policy Issues

### Policy seems applied but traffic isn't blocked

Cilium **unions** all matching policies. If both an L3/L4 allow-all and an L7 GET-only policy match the same endpoint, the L3/L4 wins. Remove the broader policy before applying the narrower:

```bash
kubectl delete cnp allow-scoreboard-to-stats -n cilium-demo
kubectl apply -f cilium/04-l7-http-stats-policy.yaml
```

### L7 policy doesn't filter HTTP methods

Cilium needs a few seconds to wire up the eBPF L7 proxy:

```bash
sleep 5
kubectl exec -n cilium-demo deploy/scoreboard-api -- \
  python -c "import requests; print(requests.post('http://stats-service:8080/api/stats/update').status_code)"
```

If still allowed, confirm Hubble sees the flow as `http`:

```bash
hubble observe -n cilium-demo --to-label app=stats-service --output jsonpb | head
```

## Hubble Issues

### `hubble observe` says "could not dial server"

Start the port-forward first:

```bash
cilium hubble port-forward &
```

Then `hubble observe -n cilium-demo --follow`.

### Hubble UI shows nothing

Generate traffic — Hubble only displays flows that have happened:

```bash
kubectl port-forward -n cilium-demo svc/scoreboard-api 9080:8080 &
curl http://localhost:9080/scores
curl http://localhost:9080/headlines
```

## Teardown Issues

### `cilium uninstall` hangs

Force-delete:

```bash
minikube delete -p cilium-demo
```

That wipes the whole VM, no further cleanup needed.

## Still Stuck?

Open an issue with:

- The exact command that failed
- Full output (paste in a fenced block)
- `minikube version`, `cilium version`, macOS version
