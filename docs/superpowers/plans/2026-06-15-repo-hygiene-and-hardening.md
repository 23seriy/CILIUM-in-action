# Cilium-in-Action — Repo Hygiene & Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring `cilium-in-action` to kyverno-in-action's level of repo polish (community-health files + CI) and security posture (multi-stage non-root Dockerfiles, PSS restricted on Pods, recommended labels), without changing the demo's educational content.

**Architecture:** Two parallel tracks shipped in one PR. Track 1 is purely additive (new files at repo root + `.github/`); Track 2 modifies existing Dockerfiles and `k8s/*.yaml` manifests. All existing `app:` / `role:` labels are preserved so Cilium policies keep working. End-to-end validation via the existing `scripts/02 → 03 → 04 → 05` demo flow.

**Tech Stack:** Bash, Python 3.12 / Flask, Docker (multi-stage), Kubernetes (Minikube), Cilium 1.19, GitHub Actions, shellcheck / yamllint / hadolint / flake8 / black / markdownlint.

**Spec:** `docs/superpowers/specs/2026-06-15-repo-hygiene-and-hardening-design.md`

---

## File Map

**Created:**
- `.shellcheckrc`
- `.markdownlint.json`
- `.github/workflows/validate.yml`
- `.github/dependabot.yml`
- `.github/GOVERNANCE.md`
- `.github/PULL_REQUEST_TEMPLATE.md`
- `.github/ISSUE_TEMPLATE/bug_report.md`
- `.github/ISSUE_TEMPLATE/feature_request.md`
- `CONTRIBUTING.md`
- `CODE_OF_CONDUCT.md`
- `SECURITY.md`
- `TESTING.md`
- `TROUBLESHOOTING.md`
- `CHANGELOG.md`

**Modified:**
- `apps/scoreboard-api/Dockerfile` — multi-stage, non-root UID 10001
- `apps/stats-service/Dockerfile` — multi-stage, non-root UID 10001
- `apps/news-service/Dockerfile` — multi-stage, non-root UID 10001
- `k8s/scoreboard-api.yaml` — PSS restricted securityContext + `app.kubernetes.io/*` labels + `/tmp` emptyDir
- `k8s/stats-service.yaml` — same
- `k8s/news-service.yaml` — same
- `k8s/rogue-pod.yaml` — minimal hardening (non-root, drop caps, no root FS write)
- `README.md` — add "📖 Documentation" section linking new docs

**Untouched (verified during validation):**
- All `cilium/*.yaml` — endpointSelector labels (`app:`, `role:`) preserved
- All `scripts/*.sh`
- `apps/*/app.py` — only Dockerfile changes
- `apps/*/requirements.txt`

---

## Conventions

- Branch: `feature/repo-hygiene-and-hardening`. Create at the start (Task 0), push at the end (Task 14).
- Commit style: Conventional Commits — `docs:`, `ci:`, `chore:`, `hardening(docker):`, `hardening(k8s):`. One commit per task.
- All shell scripts in this plan run from repo root.
- All `git commit` commands use `-S` implicitly (your git config). If signing fails in interactive sessions, the executor can re-run with `--no-gpg-sign` after explicit user approval.

---

## Task 0: Set up the feature branch

**Files:**
- N/A — git only

- [ ] **Step 1: Confirm working tree status**

Run: `git status`
Expected: On `main`, possibly with pre-existing dirty `.gitignore` / `CLAUDE.md` (leave those alone), plus untracked `docs/superpowers/`.

- [ ] **Step 2: Create the feature branch**

Run: `git checkout -b feature/repo-hygiene-and-hardening`
Expected: `Switched to a new branch 'feature/repo-hygiene-and-hardening'`

- [ ] **Step 3: Stage and commit the spec + plan**

```bash
git add docs/superpowers/specs/2026-06-15-repo-hygiene-and-hardening-design.md \
        docs/superpowers/plans/2026-06-15-repo-hygiene-and-hardening.md
git commit -m "docs: design spec and implementation plan for hygiene/hardening pass"
```

Expected: Single commit with two files. If GPG signing prompts and fails, abort and ask user (do NOT use `--no-gpg-sign` silently).

---

## Task 1: Lint configs (`.shellcheckrc`, `.markdownlint.json`)

**Files:**
- Create: `.shellcheckrc`
- Create: `.markdownlint.json`

- [ ] **Step 1: Write `.shellcheckrc`**

Create `.shellcheckrc`:

```
# Shellcheck configuration for cilium-in-action scripts
# SC1091: Sourced file not found in path (files are relative to repo)
# SC2001: Use regex replacement instead of sed (sed is clearer for indentation)
disable=SC1091,SC2001
```

- [ ] **Step 2: Write `.markdownlint.json`**

Create `.markdownlint.json`:

```json
{
  "default": true,
  "MD013": {
    "line_length": 120,
    "code_blocks": false,
    "code_line_length": 200
  },
  "MD033": false,
  "MD024": false,
  "no-hard-tabs": false
}
```

- [ ] **Step 3: Verify shellcheck reads the config (locally)**

Run: `shellcheck scripts/*.sh && echo "OK"`
Expected: Either `OK` printed (clean), or specific warnings. Pre-existing warnings are fine — Task 11 cleans them.

- [ ] **Step 4: Commit**

```bash
git add .shellcheckrc .markdownlint.json
git commit -m "chore: add shellcheck and markdownlint configs"
```

---

## Task 2: GitHub community-health files (`.github/`)

**Files:**
- Create: `.github/GOVERNANCE.md`
- Create: `.github/PULL_REQUEST_TEMPLATE.md`
- Create: `.github/ISSUE_TEMPLATE/bug_report.md`
- Create: `.github/ISSUE_TEMPLATE/feature_request.md`
- Create: `.github/dependabot.yml`

- [ ] **Step 1: Create the `.github` directory tree**

Run: `mkdir -p .github/workflows .github/ISSUE_TEMPLATE`

- [ ] **Step 2: Write `.github/GOVERNANCE.md`**

Create `.github/GOVERNANCE.md`:

```markdown
# Governance

This is a single-maintainer educational project. Decisions about scope, direction, and merges are made by the repository owner.

## Maintainer

- **Sergei Olshanetski** (@23seriy)

## Decision-making

For non-trivial changes (new scenarios, breaking refactors, dependency bumps), open an issue first to discuss. Bug fixes and documentation improvements can go directly to a PR.

## How to become a contributor

Open a PR with a useful change. Contributors who land multiple PRs may be invited as collaborators.
```

- [ ] **Step 3: Write `.github/PULL_REQUEST_TEMPLATE.md`**

Create `.github/PULL_REQUEST_TEMPLATE.md`:

```markdown
## Summary

<!-- One or two sentences: what does this PR change and why? -->

## Type of change

- [ ] `[docs]` — Documentation only
- [ ] `[fix]` — Bug fix
- [ ] `[feature]` — New scenario or policy
- [ ] `[refactor]` — Cleanup without behavior change
- [ ] `[ci]` — CI / tooling
- [ ] `[hardening]` — Security or hygiene improvement

## Validation

- [ ] `shellcheck scripts/*.sh` clean
- [ ] `yamllint -d relaxed k8s/ cilium/` clean
- [ ] Demo runs end-to-end: `./scripts/02-start-cluster.sh && ./scripts/03-deploy-app.sh && ./scripts/04-demo-scenarios.sh`
- [ ] All policy verdicts match expected ALLOWED / BLOCKED outcomes

## Related issues

Closes #
```

- [ ] **Step 4: Write `.github/ISSUE_TEMPLATE/bug_report.md`**

Create `.github/ISSUE_TEMPLATE/bug_report.md`:

```markdown
---
name: Bug report
about: A demo script failed, a policy didn't behave as expected, or docs are wrong
title: '[bug] '
labels: bug
---

## What happened

<!-- A clear description of the failure -->

## Steps to reproduce

1.
2.
3.

## Expected behavior

<!-- What should have happened? -->

## Environment

- macOS version:
- Docker Desktop version:
- Minikube version (`minikube version`):
- Kubernetes version:
- Cilium CLI version (`cilium version`):

## Logs / output

<details>
<summary>Click to expand</summary>

```
paste relevant output here
```

</details>
```

- [ ] **Step 5: Write `.github/ISSUE_TEMPLATE/feature_request.md`**

Create `.github/ISSUE_TEMPLATE/feature_request.md`:

```markdown
---
name: Feature request
about: Suggest a new demo scenario, policy, or improvement
title: '[feature] '
labels: enhancement
---

## What problem does this solve?

<!-- Why is this useful for learners or users of the project? -->

## Proposed approach

<!-- What would the new scenario or policy look like? -->

## Alternatives considered

<!-- Other ways to teach the same concept -->

## Additional context

<!-- Links, references, examples -->
```

- [ ] **Step 6: Write `.github/dependabot.yml`**

Create `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions:
        patterns: ["*"]

  - package-ecosystem: "pip"
    directory: "/apps/scoreboard-api"
    schedule:
      interval: "weekly"
    groups:
      python:
        patterns: ["*"]

  - package-ecosystem: "pip"
    directory: "/apps/stats-service"
    schedule:
      interval: "weekly"
    groups:
      python:
        patterns: ["*"]

  - package-ecosystem: "pip"
    directory: "/apps/news-service"
    schedule:
      interval: "weekly"
    groups:
      python:
        patterns: ["*"]

  - package-ecosystem: "docker"
    directory: "/apps/scoreboard-api"
    schedule:
      interval: "weekly"

  - package-ecosystem: "docker"
    directory: "/apps/stats-service"
    schedule:
      interval: "weekly"

  - package-ecosystem: "docker"
    directory: "/apps/news-service"
    schedule:
      interval: "weekly"
```

- [ ] **Step 7: Commit**

```bash
git add .github/
git commit -m "chore(github): add governance, templates, and dependabot config"
```

---

## Task 3: CI workflow (`.github/workflows/validate.yml`)

**Files:**
- Create: `.github/workflows/validate.yml`

- [ ] **Step 1: Write the workflow file**

Create `.github/workflows/validate.yml`:

```yaml
name: Validate

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  shellcheck:
    name: Shell Script Linting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install shellcheck
        run: sudo apt-get install -y shellcheck
      - name: Run shellcheck on all scripts
        run: shellcheck -x scripts/*.sh

  yaml-lint:
    name: YAML Validation
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install yamllint
        run: pip install yamllint
      - name: Lint manifests and policies
        run: |
          find k8s -name '*.yaml' -print0 | xargs -0 yamllint -d relaxed
          yamllint -d relaxed cilium/*.yaml

  cilium-policy-validation:
    name: Cilium Policy Syntax
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install PyYAML
        run: pip install pyyaml
      - name: Validate policy YAML structure
        run: |
          python3 << 'EOF'
          import glob, sys, yaml

          errors = 0
          valid_kinds = {"CiliumNetworkPolicy", "CiliumClusterwideNetworkPolicy"}
          for policy in sorted(glob.glob("cilium/*.yaml")):
              print(f"Validating {policy}")
              try:
                  with open(policy) as f:
                      docs = [d for d in yaml.safe_load_all(f) if d]
                  if not docs:
                      print(f"  ERROR: {policy} is empty")
                      errors += 1
                      continue
                  kinds = [d.get("kind") for d in docs]
                  if not any(k in valid_kinds for k in kinds):
                      print(f"  ERROR: {policy} contains no CiliumNetworkPolicy / CiliumClusterwideNetworkPolicy")
                      errors += 1
                      continue
                  # Spec sanity check
                  for d in docs:
                      if d.get("kind") in valid_kinds:
                          spec = d.get("spec") or {}
                          if not any(k in spec for k in ("endpointSelector", "ingress", "egress", "nodeSelector")):
                              print(f"  ERROR: {policy} spec lacks endpointSelector/ingress/egress/nodeSelector")
                              errors += 1
                  print(f"  OK — kinds: {kinds}")
              except Exception as e:
                  print(f"  ERROR: {e}")
                  errors += 1

          if errors:
              print(f"\n{errors} policy file(s) failed validation")
              sys.exit(1)
          print("\nAll policies have valid YAML and proper structure")
          EOF

  docker-lint:
    name: Dockerfile Linting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install hadolint
        run: |
          wget -q -O /tmp/hadolint https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64
          chmod +x /tmp/hadolint
          sudo mv /tmp/hadolint /usr/local/bin/hadolint
      - name: Lint Dockerfiles
        run: |
          hadolint apps/scoreboard-api/Dockerfile || true
          hadolint apps/stats-service/Dockerfile || true
          hadolint apps/news-service/Dockerfile || true
        continue-on-error: true

  script-syntax:
    name: Script Syntax Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check bash syntax
        run: |
          for script in scripts/*.sh; do
            echo "Checking $script"
            bash -n "$script"
          done

  python-lint:
    name: Python Code Quality
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.12'
      - name: Install linting tools
        run: pip install flake8 black
      - name: Compile-check apps
        run: |
          python -m py_compile apps/scoreboard-api/app.py
          python -m py_compile apps/stats-service/app.py
          python -m py_compile apps/news-service/app.py
      - name: flake8 (advisory)
        run: flake8 apps/ --max-line-length=100
        continue-on-error: true
      - name: black --check (advisory)
        run: black --check apps/
        continue-on-error: true

  markdown-lint:
    name: Markdown Linting
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: nosborn/github-action-markdown-cli@v3.5.0
        with:
          files: .
          config_file: .markdownlint.json
        continue-on-error: true

  docs-check:
    name: Documentation Completeness
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check required docs exist
        run: |
          files=(
            "README.md"
            "LICENSE"
            ".gitignore"
            "CONTRIBUTING.md"
            "CODE_OF_CONDUCT.md"
            "SECURITY.md"
            "TROUBLESHOOTING.md"
            "CLAUDE.md"
            "CHANGELOG.md"
          )
          for file in "${files[@]}"; do
            if [ ! -f "$file" ]; then
              echo "Missing: $file"
              exit 1
            fi
          done
          echo "All required documentation files present"
```

- [ ] **Step 2: Validate the YAML locally**

Run: `yamllint -d relaxed .github/workflows/validate.yml && echo OK`
Expected: `OK`. (If `yamllint` isn't installed locally, skip — CI will catch it.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/validate.yml
git commit -m "ci: add validation workflow (shellcheck, yamllint, cilium policy, hadolint, docs)"
```

---

## Task 4: CONTRIBUTING.md

**Files:**
- Create: `CONTRIBUTING.md`

- [ ] **Step 1: Write the file**

Create `CONTRIBUTING.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs: add CONTRIBUTING.md"
```

---

## Task 5: CODE_OF_CONDUCT.md

**Files:**
- Create: `CODE_OF_CONDUCT.md`

- [ ] **Step 1: Write the file**

Create `CODE_OF_CONDUCT.md` (Contributor Covenant 2.1):

```markdown
# Contributor Covenant Code of Conduct

## Our Pledge

We as members, contributors, and leaders pledge to make participation in our community a harassment-free experience for everyone, regardless of age, body size, visible or invisible disability, ethnicity, sex characteristics, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, religion, or sexual identity and orientation.

We pledge to act and interact in ways that contribute to an open, welcoming, diverse, inclusive, and healthy community.

## Our Standards

Examples of behavior that contributes to a positive environment:

- Demonstrating empathy and kindness toward other people
- Being respectful of differing opinions, viewpoints, and experiences
- Giving and gracefully accepting constructive feedback
- Accepting responsibility and apologizing to those affected by our mistakes
- Focusing on what is best for the overall community

Examples of unacceptable behavior:

- Sexualized language or imagery, and sexual attention or advances
- Trolling, insulting or derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate in a professional setting

## Enforcement Responsibilities

Community leaders are responsible for clarifying and enforcing our standards of acceptable behavior and will take appropriate and fair corrective action in response to any behavior that they deem inappropriate, threatening, offensive, or harmful.

## Scope

This Code of Conduct applies within all community spaces, and also applies when an individual is officially representing the community in public spaces.

## Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported by contacting the project maintainer at **23seriy@gmail.com**. All complaints will be reviewed and investigated promptly and fairly.

## Attribution

This Code of Conduct is adapted from the [Contributor Covenant][homepage], version 2.1, available at https://www.contributor-covenant.org/version/2/1/code_of_conduct.html.

[homepage]: https://www.contributor-covenant.org
```

- [ ] **Step 2: Commit**

```bash
git add CODE_OF_CONDUCT.md
git commit -m "docs: add Contributor Covenant code of conduct"
```

---

## Task 6: SECURITY.md

**Files:**
- Create: `SECURITY.md`

- [ ] **Step 1: Write the file**

Create `SECURITY.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add SECURITY.md
git commit -m "docs: add security policy"
```

---

## Task 7: TESTING.md

**Files:**
- Create: `TESTING.md`

- [ ] **Step 1: Write the file**

Create `TESTING.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add TESTING.md
git commit -m "docs: add testing guide"
```

---

## Task 8: TROUBLESHOOTING.md

**Files:**
- Create: `TROUBLESHOOTING.md`

- [ ] **Step 1: Write the file**

Create `TROUBLESHOOTING.md`:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add TROUBLESHOOTING.md
git commit -m "docs: add troubleshooting guide"
```

---

## Task 9: CHANGELOG.md

**Files:**
- Create: `CHANGELOG.md`

- [ ] **Step 1: Write the file**

Create `CHANGELOG.md`:

```markdown
# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project follows informal semantic versioning.

## [Unreleased]

### Added

- Community-health files: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `TESTING.md`, `TROUBLESHOOTING.md`, `CHANGELOG.md`
- GitHub templates: PR template, bug report, feature request, governance doc
- GitHub Actions CI: shellcheck, yamllint, Cilium policy validation, hadolint, Python lint, markdownlint, docs-existence
- Lint configs: `.shellcheckrc`, `.markdownlint.json`
- Dependabot for GitHub Actions, pip, and Docker base images
- Multi-stage Dockerfiles for all three NBA services, running as UID 10001
- Recommended `app.kubernetes.io/*` labels on all workload manifests (alongside the existing `app:` / `role:` labels Cilium policies depend on)
- Pod Security Standards "restricted" posture on workload Pods (`runAsNonRoot`, `readOnlyRootFilesystem`, `drop: [ALL]`, `seccompProfile: RuntimeDefault`)
- `emptyDir` at `/tmp` for Flask containers to satisfy `readOnlyRootFilesystem`
- "Documentation" section in README linking the new docs

### Changed

- `apps/*/Dockerfile` — switched to multi-stage build, non-root runtime, added `HEALTHCHECK`
- `k8s/scoreboard-api.yaml`, `k8s/stats-service.yaml`, `k8s/news-service.yaml` — added `securityContext` and recommended labels
- `k8s/rogue-pod.yaml` — minimal hardening (non-root, drop caps); intentionally still able to attempt unauthorized traffic for the demo

### Unchanged (intentionally)

- `apps/*/app.py` — application code untouched
- `cilium/*.yaml` — network policies untouched (existing `app:` / `role:` selectors preserved)
- `scripts/*.sh` — automation untouched
- Demo scenarios in README — identical behavior, same six steps

## [1.0.0] — 2025-05-20

### Added

- Initial release: three NBA microservices (scoreboard-api, stats-service, news-service)
- Six progressively-restrictive Cilium policies (default-deny, L3/L4, L7 HTTP, DNS egress, full zero-trust)
- Five orchestration scripts (install prereqs, start cluster, deploy, run scenarios, teardown)
- Rogue-pod manifest for demonstrating policy enforcement
- README with architecture, demo scenarios, and key takeaways
- LICENSE (MIT), CLAUDE.md (agent guide)
```

- [ ] **Step 2: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: add CHANGELOG"
```

---

## Task 10: Harden `apps/scoreboard-api/Dockerfile`

**Files:**
- Modify: `apps/scoreboard-api/Dockerfile`

- [ ] **Step 1: Replace the Dockerfile**

Replace the entire contents of `apps/scoreboard-api/Dockerfile` with:

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim
RUN groupadd -r app -g 10001 \
    && useradd -r -u 10001 -g app -d /home/app -m -s /sbin/nologin app
WORKDIR /app
COPY --from=builder --chown=app:app /root/.local /home/app/.local
COPY --chown=app:app app.py .
ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
USER 10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=2).status==200 else 1)"
CMD ["python", "app.py"]
```

- [ ] **Step 2: Build the image locally**

Run: `docker build -t scoreboard-api:hardening-test apps/scoreboard-api`
Expected: Successful build, no errors.

- [ ] **Step 3: Verify the image runs as non-root**

```bash
docker run --rm scoreboard-api:hardening-test id
```

Expected: `uid=10001(app) gid=10001(app) groups=10001(app)`

- [ ] **Step 4: Verify the app starts and serves /health**

```bash
docker run -d --rm --name scoreboard-test -p 18080:8080 scoreboard-api:hardening-test
sleep 3
curl -sf http://localhost:18080/health && echo " — OK"
docker stop scoreboard-test
```

Expected: `{"service":"scoreboard-api","status":"healthy"} — OK`. If port 18080 is taken, pick another.

- [ ] **Step 5: Commit**

```bash
git add apps/scoreboard-api/Dockerfile
git commit -m "hardening(docker): multi-stage non-root build for scoreboard-api"
```

---

## Task 11: Harden `apps/stats-service/Dockerfile`

**Files:**
- Modify: `apps/stats-service/Dockerfile`

- [ ] **Step 1: Replace the Dockerfile**

Replace the entire contents of `apps/stats-service/Dockerfile` with:

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim
RUN groupadd -r app -g 10001 \
    && useradd -r -u 10001 -g app -d /home/app -m -s /sbin/nologin app
WORKDIR /app
COPY --from=builder --chown=app:app /root/.local /home/app/.local
COPY --chown=app:app app.py .
ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
USER 10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=2).status==200 else 1)"
CMD ["python", "app.py"]
```

- [ ] **Step 2: Build**

Run: `docker build -t stats-service:hardening-test apps/stats-service`
Expected: Successful build.

- [ ] **Step 3: Verify non-root**

```bash
docker run --rm stats-service:hardening-test id
```

Expected: `uid=10001(app) gid=10001(app) groups=10001(app)`

- [ ] **Step 4: Verify /health**

```bash
docker run -d --rm --name stats-test -p 18081:8080 stats-service:hardening-test
sleep 3
curl -sf http://localhost:18081/health && echo " — OK"
docker stop stats-test
```

Expected: A `200` body containing `healthy`, plus `— OK`.

- [ ] **Step 5: Commit**

```bash
git add apps/stats-service/Dockerfile
git commit -m "hardening(docker): multi-stage non-root build for stats-service"
```

---

## Task 12: Harden `apps/news-service/Dockerfile`

**Files:**
- Modify: `apps/news-service/Dockerfile`

- [ ] **Step 1: Replace the Dockerfile**

Replace the entire contents of `apps/news-service/Dockerfile` with:

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim
RUN groupadd -r app -g 10001 \
    && useradd -r -u 10001 -g app -d /home/app -m -s /sbin/nologin app
WORKDIR /app
COPY --from=builder --chown=app:app /root/.local /home/app/.local
COPY --chown=app:app app.py .
ENV PATH=/home/app/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
USER 10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health',timeout=2).status==200 else 1)"
CMD ["python", "app.py"]
```

- [ ] **Step 2: Build**

Run: `docker build -t news-service:hardening-test apps/news-service`
Expected: Successful build.

- [ ] **Step 3: Verify non-root**

```bash
docker run --rm news-service:hardening-test id
```

Expected: `uid=10001(app) gid=10001(app) groups=10001(app)`

- [ ] **Step 4: Verify /health**

```bash
docker run -d --rm --name news-test -p 18082:8080 news-service:hardening-test
sleep 3
curl -sf http://localhost:18082/health && echo " — OK"
docker stop news-test
```

Expected: A `200` body containing `healthy`, plus `— OK`.

- [ ] **Step 5: Commit**

```bash
git add apps/news-service/Dockerfile
git commit -m "hardening(docker): multi-stage non-root build for news-service"
```

---

## Task 13: Harden `k8s/scoreboard-api.yaml`

**Files:**
- Modify: `k8s/scoreboard-api.yaml`

- [ ] **Step 1: Replace the Deployment block**

Replace the entire `Deployment` section of `k8s/scoreboard-api.yaml` (lines 1–49 of the current file) with the following. **Keep the existing Service block (lines 50–66) unchanged.**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scoreboard-api
  namespace: cilium-demo
  labels:
    app: scoreboard-api
    role: public
    app.kubernetes.io/name: scoreboard-api
    app.kubernetes.io/component: api
    app.kubernetes.io/part-of: cilium-demo
    app.kubernetes.io/managed-by: manual
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scoreboard-api
  template:
    metadata:
      labels:
        app: scoreboard-api
        role: public
        app.kubernetes.io/name: scoreboard-api
        app.kubernetes.io/component: api
        app.kubernetes.io/part-of: cilium-demo
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: scoreboard-api
          image: scoreboard-api:local
          imagePullPolicy: Never
          ports:
            - containerPort: 8080
          env:
            - name: STATS_SERVICE_URL
              value: "http://stats-service:8080"
            - name: NEWS_SERVICE_URL
              value: "http://news-service:8080"
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

- [ ] **Step 2: Confirm only the Deployment changed**

Run: `git diff k8s/scoreboard-api.yaml | head -100`
Expected: Diff confined to the Deployment block; Service block untouched.

- [ ] **Step 3: Validate YAML**

Run: `yamllint -d relaxed k8s/scoreboard-api.yaml && echo OK`
Expected: `OK` (or no output).

- [ ] **Step 4: Dry-run apply**

Run: `kubectl apply -f k8s/scoreboard-api.yaml --dry-run=client -o yaml > /dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add k8s/scoreboard-api.yaml
git commit -m "hardening(k8s): PSS restricted securityContext for scoreboard-api"
```

---

## Task 14: Harden `k8s/stats-service.yaml`

**Files:**
- Modify: `k8s/stats-service.yaml`

- [ ] **Step 1: Read the current file to find the Deployment vs Service boundary**

Run: `cat k8s/stats-service.yaml`
Expected: A Deployment followed by a Service, separated by `---`.

- [ ] **Step 2: Replace the Deployment block**

Replace the Deployment section of `k8s/stats-service.yaml` with the following. **Keep the existing Service block unchanged.** Re-use the existing image name (`stats-service:local`), env vars, and resources — adjust below if the current file uses different values.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stats-service
  namespace: cilium-demo
  labels:
    app: stats-service
    role: internal
    app.kubernetes.io/name: stats-service
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: cilium-demo
    app.kubernetes.io/managed-by: manual
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stats-service
  template:
    metadata:
      labels:
        app: stats-service
        role: internal
        app.kubernetes.io/name: stats-service
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: cilium-demo
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: stats-service
          image: stats-service:local
          imagePullPolicy: Never
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

**Important:** If the current `stats-service.yaml` uses different `role:` value (e.g., `internal` vs something else), preserve the original value — the Cilium policies might select on it.

- [ ] **Step 3: Validate YAML**

Run: `yamllint -d relaxed k8s/stats-service.yaml && echo OK`
Expected: `OK`.

- [ ] **Step 4: Dry-run apply**

Run: `kubectl apply -f k8s/stats-service.yaml --dry-run=client -o yaml > /dev/null && echo OK`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add k8s/stats-service.yaml
git commit -m "hardening(k8s): PSS restricted securityContext for stats-service"
```

---

## Task 15: Harden `k8s/news-service.yaml`

**Files:**
- Modify: `k8s/news-service.yaml`

- [ ] **Step 1: Read the current file**

Run: `cat k8s/news-service.yaml`

- [ ] **Step 2: Replace the Deployment block**

Same shape as Task 14, but for `news-service`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: news-service
  namespace: cilium-demo
  labels:
    app: news-service
    role: internal
    app.kubernetes.io/name: news-service
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: cilium-demo
    app.kubernetes.io/managed-by: manual
spec:
  replicas: 1
  selector:
    matchLabels:
      app: news-service
  template:
    metadata:
      labels:
        app: news-service
        role: internal
        app.kubernetes.io/name: news-service
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: cilium-demo
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: news-service
          image: news-service:local
          imagePullPolicy: Never
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

**Important:** Preserve original `role:` value if different.

- [ ] **Step 3: Validate**

```bash
yamllint -d relaxed k8s/news-service.yaml && echo OK
kubectl apply -f k8s/news-service.yaml --dry-run=client -o yaml > /dev/null && echo OK
```

Expected: `OK` twice.

- [ ] **Step 4: Commit**

```bash
git add k8s/news-service.yaml
git commit -m "hardening(k8s): PSS restricted securityContext for news-service"
```

---

## Task 16: Lightly harden `k8s/rogue-pod.yaml`

**Files:**
- Modify: `k8s/rogue-pod.yaml`

- [ ] **Step 1: Replace the file**

Replace `k8s/rogue-pod.yaml` with:

```yaml
# A "rogue" pod that simulates an attacker or misconfigured service
# trying to access internal services it shouldn't reach.
#
# It runs as non-root and drops all capabilities — its only "attack" is
# making unauthorized HTTP calls, which Cilium blocks at the network layer.
apiVersion: v1
kind: Pod
metadata:
  name: rogue-pod
  namespace: cilium-demo
  labels:
    app: rogue-pod
    role: attacker
    app.kubernetes.io/name: rogue-pod
    app.kubernetes.io/component: attacker-sim
    app.kubernetes.io/part-of: cilium-demo
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: curl
      image: curlimages/curl:8.5.0
      command: ["sleep", "3600"]
      resources:
        requests:
          cpu: 10m
          memory: 16Mi
        limits:
          cpu: 50m
          memory: 32Mi
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: [ALL]
```

`curlimages/curl` already runs as UID 65532 (`curl_user`) by default; we set it explicitly for auditability. No `/tmp` writes from a sleeping container, so no `emptyDir` needed.

- [ ] **Step 2: Validate**

```bash
yamllint -d relaxed k8s/rogue-pod.yaml && echo OK
kubectl apply -f k8s/rogue-pod.yaml --dry-run=client -o yaml > /dev/null && echo OK
```

Expected: `OK` twice.

- [ ] **Step 3: Commit**

```bash
git add k8s/rogue-pod.yaml
git commit -m "hardening(k8s): non-root + drop caps on rogue-pod"
```

---

## Task 17: Add Documentation section to README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Insert a "Documentation" section after the Medium link**

Find this block in `README.md` (around line 13):

```markdown
> 📝 **Read the full walkthrough on Medium:** [Cilium in Action — eBPF-Powered Networking, Security, and Observability for Kubernetes](https://medium.com/@sergeiolshanetski/cilium-in-action-ebpf-powered-networking-security-and-observability-for-kubernetes-without-9a0decd90b74)

## 🏗️ Architecture
```

Insert this between the Medium link and the Architecture header:

```markdown

## 📖 Documentation

- **[CLAUDE.md](CLAUDE.md)** — Architecture, file structure, and conventions for AI-assisted development
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — How to contribute (features, fixes, docs)
- **[TESTING.md](TESTING.md)** — Manual and automated testing procedures
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** — Common issues and solutions
- **[SECURITY.md](SECURITY.md)** — Vulnerability reporting and responsible disclosure
- **[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)** — Community guidelines
- **[CHANGELOG.md](CHANGELOG.md)** — Release notes

```

- [ ] **Step 2: Verify the diff**

Run: `git diff README.md`
Expected: A purely additive change inserting the Documentation block; no other edits.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs(readme): link new community-health and testing docs"
```

---

## Task 18: Local lint sweep

**Files:**
- N/A — running checks only

- [ ] **Step 1: shellcheck**

Run: `shellcheck -x scripts/*.sh`
Expected: Clean (no output). If warnings, **stop and fix them** before continuing — open a sub-task to address each one inline in the relevant script (don't change the script's behavior, just satisfy the linter).

- [ ] **Step 2: yamllint**

Run: `yamllint -d relaxed k8s/ cilium/`
Expected: Clean. Fix warnings if any.

- [ ] **Step 3: hadolint (if installed)**

Run: `command -v hadolint && hadolint apps/scoreboard-api/Dockerfile apps/stats-service/Dockerfile apps/news-service/Dockerfile || echo "hadolint not installed — skipping"`
Expected: Clean, or `skipping` message.

- [ ] **Step 4: Python compile-check**

```bash
python -m py_compile apps/scoreboard-api/app.py
python -m py_compile apps/stats-service/app.py
python -m py_compile apps/news-service/app.py
```

Expected: No output (success). The apps are unchanged in this PR — this is sanity verification.

- [ ] **Step 5: If anything was fixed, commit**

```bash
git add -u
git commit -m "chore: clean lint warnings" || echo "nothing to commit"
```

---

## Task 19: End-to-end demo run

**Files:**
- N/A — running the cluster

- [ ] **Step 1: Start the cluster**

Run: `./scripts/02-start-cluster.sh`
Expected: Eventually prints `✅ Minikube + Cilium ready!` and shows Cilium status as healthy. Time: ~3–5 minutes.

- [ ] **Step 2: Deploy hardened apps**

Run: `./scripts/03-deploy-app.sh`
Expected: All four pods reach `Ready`. Time: ~1–2 minutes.

- [ ] **Step 3: Verify pods run as non-root**

```bash
kubectl exec -n cilium-demo deploy/scoreboard-api -- id
kubectl exec -n cilium-demo deploy/stats-service -- id
kubectl exec -n cilium-demo deploy/news-service -- id
```

Expected: Each prints `uid=10001(app) gid=10001(app) groups=10001(app)`.

- [ ] **Step 4: Verify root filesystem is read-only**

```bash
kubectl exec -n cilium-demo deploy/scoreboard-api -- sh -c 'touch /forbidden 2>&1 || echo READONLY_OK'
kubectl exec -n cilium-demo deploy/scoreboard-api -- sh -c 'touch /tmp/allowed && echo TMP_OK'
```

Expected: First prints `READONLY_OK`. Second prints `TMP_OK`.

- [ ] **Step 5: Port-forward and curl the scoreboard**

In a separate terminal:

```bash
kubectl port-forward -n cilium-demo svc/scoreboard-api 9080:8080
```

Back in main terminal:

```bash
curl -sf http://localhost:9080/scores | head -c 100 && echo
curl -sf http://localhost:9080/scores/1 | head -c 200 && echo
curl -sf http://localhost:9080/headlines | head -c 100 && echo
curl -sf http://localhost:9080/health && echo
```

Expected: All four return data (no errors, no `unavailable`). If `/scores/1` returns `stats-service unavailable`, the hardened stats-service Pod didn't come up cleanly — check `kubectl logs` and roll back the Pod-spec changes if needed.

- [ ] **Step 6: Run all six demo scenarios**

Run: `./scripts/04-demo-scenarios.sh`

Expected, scenario by scenario:

| # | Scenario | Expected outcome |
|---|---|---|
| 1 | Baseline (no policies) | `scoreboard → stats: ALLOWED`, `rogue → stats: ALLOWED` |
| 2 | L3/L4 policy | `scoreboard → stats: ALLOWED`, `rogue → stats: BLOCKED` |
| 3 | L7 HTTP | `GET: ALLOWED`, `POST/DELETE: BLOCKED` |
| 4 | DNS egress | Internal: `ALLOWED`, external `httpbin.org`: blocked |
| 5 | Hubble flows | Manual narration only — no automated verdict |
| 6 | Full zero-trust | All six rows of the matrix match the README's table |

If any scenario produces an unexpected verdict, **stop** and investigate before continuing. Likely causes: a `securityContext` change broke the Pod, or a label change broke a Cilium endpointSelector.

- [ ] **Step 7: Teardown**

Run: `./scripts/05-teardown.sh`
Expected: Clean exit. Profile `cilium-demo` deleted.

---

## Task 20: Push and open PR

**Files:**
- N/A — git + gh

- [ ] **Step 1: Confirm branch is clean and ahead of main**

```bash
git status
git log --oneline main..feature/repo-hygiene-and-hardening
```

Expected: Working tree clean. ~17 commits ahead of main.

- [ ] **Step 2: Push the branch**

Run: `git push -u origin feature/repo-hygiene-and-hardening`
Expected: Push succeeds. No force-push.

- [ ] **Step 3: Open the PR**

```bash
gh pr create --title "[feature] repo hygiene and security hardening" --body "$(cat <<'EOF'
## Summary

Brings cilium-in-action to the same level of repo polish and security posture as the sibling kyverno-in-action project.

## Type of change

- [x] `[hardening]` — Security or hygiene improvement

## What changed

**Track 1 — Repo hygiene (purely additive):**
- Community-health files: `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `TESTING.md`, `TROUBLESHOOTING.md`, `CHANGELOG.md`
- `.github/` templates (PR, bug report, feature request, governance)
- GitHub Actions CI: shellcheck, yamllint, Cilium policy validation, hadolint, Python lint, markdownlint, docs-existence
- Lint configs: `.shellcheckrc`, `.markdownlint.json`
- Dependabot for GitHub Actions, pip, Docker

**Track 2 — Security hardening:**
- Multi-stage Dockerfiles, running as UID 10001
- Pod Security Standards "restricted" posture on all workload Pods (`runAsNonRoot`, `readOnlyRootFilesystem`, `drop: [ALL]`, `seccompProfile: RuntimeDefault`)
- Recommended `app.kubernetes.io/*` labels added (existing `app:` / `role:` labels preserved so Cilium policies keep working)
- Minimal hardening of `rogue-pod` (non-root, drop caps)

**Out of scope (intentionally untouched):**
- `apps/*/app.py` — application logic
- `cilium/*.yaml` — network policies
- `scripts/*.sh` — automation
- Demo scenarios — identical behavior

## Validation

- [x] `shellcheck -x scripts/*.sh` — clean
- [x] `yamllint -d relaxed k8s/ cilium/` — clean
- [x] `hadolint apps/*/Dockerfile` — clean
- [x] All three Dockerfiles build, run as UID 10001, and serve `/health`
- [x] All four Pods reach `Ready` in the hardened deployment
- [x] All six demo scenarios produce the expected ALLOWED / BLOCKED verdicts
- [x] `./scripts/05-teardown.sh` exits cleanly

## Test plan for reviewer

1. Pull the branch
2. `./scripts/02-start-cluster.sh && ./scripts/03-deploy-app.sh`
3. `kubectl exec -n cilium-demo deploy/scoreboard-api -- id` → confirms `uid=10001`
4. `./scripts/04-demo-scenarios.sh` → verify all scenarios match expectations
5. `./scripts/05-teardown.sh`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed. Confirm CI starts running.

- [ ] **Step 4: Watch CI**

Run: `gh pr checks`
Expected: All required jobs eventually pass. Advisory jobs (hadolint, flake8, black, markdown-lint) may show warnings but won't block.

- [ ] **Step 5: Notify**

If CI is green, surface the PR URL to the user.
