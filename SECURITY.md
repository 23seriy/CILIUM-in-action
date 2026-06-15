# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in cilium-in-action, please **do not** open a public GitHub issue. Email [23seriy@gmail.com](mailto:23seriy@gmail.com) with:

- A description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fixes (if any)

**Please do not disclose publicly until we've had time to address it.**

We will:

1. Acknowledge receipt within 48 hours
2. Provide a remediation timeline
3. Coordinate disclosure with you
4. Credit you in the advisory (unless you prefer anonymity)

## Scope

This policy covers the **cilium-in-action repository itself**. It does not cover:

- **Cilium itself** — report to the [Cilium project](https://github.com/cilium/cilium/security)
- **Kubernetes** — report via the [Kubernetes disclosure process](https://kubernetes.io/security/)
- **Minikube** — report to the [Minikube project](https://github.com/kubernetes/minikube/security)

## What Counts as a Security Issue

- Code injection in scripts (shell, Python)
- Unintended credential leakage
- Unsafe defaults that could allow unintended policy bypasses
- Supply-chain risks in the build workflow

The following are **not** security issues (file as bugs instead):

- The `rogue-pod` and demo scenarios intentionally violate policies — that's the point
- Cilium policy misconfigurations (report to Cilium)
- Kubernetes API behavior (report to Kubernetes)

## Using This Project Securely

- **Run on Minikube only** — this is a demo, not a production-hardened system
- **Don't expose Minikube to the internet** — keep it on your laptop
- **Tear down between runs** — `./scripts/05-teardown.sh`
- **Don't reuse the manifests in production unchanged** — they're tuned for clarity, not for compliance with your environment's requirements
