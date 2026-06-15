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

# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
