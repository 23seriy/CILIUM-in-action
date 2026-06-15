# Testing Guide

How to validate cilium-in-action locally before pushing.

## Automated Checks

### Local Validation

```bash
# Shell scripts
shellcheck -x scripts/*.sh

# YAML manifests and policies
yamllint -d relaxed k8s/ cilium/

# Python apps compile
python -m py_compile apps/scoreboard-api/app.py
python -m py_compile apps/stats-service/app.py
python -m py_compile apps/news-service/app.py

# Dockerfiles (optional)
hadolint apps/scoreboard-api/Dockerfile
hadolint apps/stats-service/Dockerfile
hadolint apps/news-service/Dockerfile
```

### GitHub Actions

CI runs on every push and PR via `.github/workflows/validate.yml`:

- `shellcheck` — script linting
- `yaml-lint` — Kubernetes and policy YAML
- `cilium-policy-validation` — structural check that `cilium/*.yaml` contain valid `CiliumNetworkPolicy` documents
- `docker-lint` — hadolint on all Dockerfiles
- `python-lint` — compile + flake8 + black (advisory)
- `markdown-lint` — markdownlint against `.markdownlint.json`
- `docs-check` — required docs exist (README, LICENSE, CONTRIBUTING, etc.)
- `script-syntax` — `bash -n` on each script

## Manual Testing

### Full Demo Run

The most comprehensive test:

```bash
./scripts/01-install-prerequisites.sh   # once per machine
./scripts/02-start-cluster.sh
./scripts/03-deploy-app.sh
./scripts/04-demo-scenarios.sh
./scripts/05-teardown.sh
```

**Expected:** all six scenarios produce the documented ALLOWED / BLOCKED verdicts.

**Time:** ~15–20 minutes on a warm Docker daemon.

### Verify Pods Run As Non-Root

After `./scripts/03-deploy-app.sh`:

```bash
kubectl exec -n cilium-demo deploy/scoreboard-api -- id
# Expected: uid=10001(app) gid=10001(app)

kubectl exec -n cilium-demo deploy/stats-service -- id
# Expected: uid=10001(app) gid=10001(app)

kubectl exec -n cilium-demo deploy/news-service -- id
# Expected: uid=10001(app) gid=10001(app)
```

### Verify Read-Only Root Filesystem

```bash
kubectl exec -n cilium-demo deploy/scoreboard-api -- touch /test 2>&1 || echo "Read-only confirmed"
# Expected: "Read-only confirmed"
```

### Test a Single Policy in Isolation

```bash
# Reset
kubectl delete cnp --all -n cilium-demo

# Apply just the L7 policy
kubectl apply -f cilium/04-l7-http-stats-policy.yaml

# Watch flows
hubble observe -n cilium-demo --follow &

# Trigger traffic
kubectl exec -n cilium-demo deploy/scoreboard-api -- \
  python -c "import requests; print(requests.get('http://stats-service:8080/api/stats/game/1').status_code)"
```

## Troubleshooting Test Failures

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
