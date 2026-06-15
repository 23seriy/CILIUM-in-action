# Contributing to cilium-in-action

Thanks for your interest in contributing. This project is a hands-on educational demo of Cilium — eBPF networking, security, and observability on Kubernetes. Bug fixes, doc improvements, and new demo scenarios are all welcome.

## Getting Started

1. **Fork and clone** the repository
2. **Create a feature branch** from `main`: `git checkout -b feature/your-feature`
3. **Make your changes** and test them
4. **Submit a pull request** with a clear description

## Code of Conduct

This project adheres to a Code of Conduct. Please review [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Development Workflow

### Before You Start

- Install prerequisites: Docker Desktop, Minikube, macOS Homebrew (scripts assume macOS).
- Familiarity with Kubernetes NetworkPolicy / Cilium policy syntax helps but isn't required.

### Testing Your Changes

For **script changes**:

```bash
chmod +x scripts/*.sh
./scripts/02-start-cluster.sh     # fresh cluster
./scripts/03-deploy-app.sh        # build + deploy
./scripts/04-demo-scenarios.sh    # run all scenarios
./scripts/05-teardown.sh          # clean up
```

For **policy changes**:

```bash
# Apply a single policy and observe behavior
kubectl apply -f cilium/<policy-file>.yaml
hubble observe -n cilium-demo --follow
```

For **manifest changes**:

- Update the YAML in `k8s/`
- Re-run `./scripts/03-deploy-app.sh` and verify pods become `Ready`
- Run `./scripts/04-demo-scenarios.sh` end-to-end

### Shell Script Standards

All shell scripts should:

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Use the project's `info()` / `warn()` / `error()` helpers
- Pass `shellcheck -x scripts/*.sh` cleanly

### Cilium Policy Standards

Policies in `cilium/` should:

- Have a comment at the top explaining what they do
- Use the `NN-<short-name>.yaml` naming convention
- Be referenced from `scripts/04-demo-scenarios.sh`
- Use `app:` / `role:` labels for endpoint selectors (these are the project's convention)

### Documentation Standards

- Keep the README in sync with the current Kubernetes and Cilium versions
- Document new scenarios in the README "Demo Scenarios" section
- Update CLAUDE.md if you add architectural concepts

## Reporting Issues

### Security Vulnerabilities

Do **not** open a public issue. See [SECURITY.md](SECURITY.md).

### Bugs and Feature Requests

Use the GitHub issue templates. Include:

- Clear title (`[bug] Hubble UI fails to start on M1` is better than `Broken`)
- Steps to reproduce
- Expected vs. actual behavior
- Environment (macOS version, Minikube version, Cilium version)

## Pull Request Process

1. Run the full demo and confirm scenarios pass
2. Run `shellcheck -x scripts/*.sh` and `yamllint -d relaxed k8s/ cilium/`
3. Update docs if behavior changes
4. Write a clear PR description explaining the *why*

### PR Title Convention

Format: `[type] short description`

Types: `[docs]`, `[fix]`, `[feature]`, `[refactor]`, `[ci]`, `[hardening]`

Example: `[feature] add transparent-encryption demo scenario`

## Project Philosophy

- **Clarity over cleverness** — a simple policy teaches more than a complex one
- **One concept per scenario** — don't mix multiple Cilium features in one demo step
- **Reproducible** — anything in `scripts/` should work the same on any macOS machine with the prerequisites
- **Preserve the NBA metaphor** — when adding examples, stay in the arena

## Questions?

Open a discussion or issue if you're unsure about anything.
