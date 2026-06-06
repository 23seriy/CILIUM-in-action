# CLAUDE.md — Cilium in Action

## Project Overview

Hands-on demo of **Cilium** — eBPF-powered networking, security, and observability for Kubernetes. Uses three NBA microservices to showcase L3/L4/L7 network policies, zero-trust networking, and Hubble observability on a local Minikube cluster.

## Tech Stack

- **Apps**: Python/Flask (scoreboard-api, stats-service, news-service)
- **Platform**: Minikube (profile: `cilium-demo`) with Cilium CNI
- **Tools**: Cilium CLI, Hubble CLI, Hubble UI
- **Container**: Docker (images built inside Minikube's Docker daemon)

## Project Structure

```
apps/                  # Three NBA microservices
  scoreboard-api/      # Public-facing API (calls stats + news internally)
  stats-service/       # Internal stats service
  news-service/        # Internal news service
cilium/                # Cilium network policies (numbered 01–06)
k8s/                   # Base Kubernetes manifests (deployments, services, rogue-pod)
scripts/               # Numbered automation scripts (01–05)
docs/                  # Documentation
```

## Scripts Convention

All scripts are in `scripts/` and numbered sequentially:
- `01-install-prerequisites.sh` — Installs minikube, kubectl, cilium, hubble via Homebrew
- `02-start-cluster.sh` — Creates Minikube cluster with Cilium CNI enabled
- `03-deploy-app.sh` — Builds images and deploys the three microservices
- `04-demo-scenarios.sh` — Interactive walkthrough of network policies
- `05-teardown.sh` — Destroys cluster (has confirmation prompt)

Scripts use `#!/usr/bin/env bash` and `set -euo pipefail`.

## Key Concepts

- **Network policies** in `cilium/` are numbered and applied progressively:
  1. Default deny all traffic
  2. Allow scoreboard → stats
  3. Allow scoreboard → news
  4. L7 HTTP policy (read-only methods)
  5. DNS egress policy
  6. Full zero-trust
- `k8s/rogue-pod.yaml` is used to demonstrate policy enforcement (blocked traffic)
- The scoreboard-api aggregates data from stats-service and news-service
- Hubble provides real-time flow visualization

## Conventions

- All Kubernetes resources use the `cilium-demo` namespace
- Cilium policies use Kubernetes labels for endpoint selection
- Emoji prefixes in script output for readability (🐝, ✅, 🗑️)
- Docker images are built locally in Minikube's Docker daemon (no registry push)
