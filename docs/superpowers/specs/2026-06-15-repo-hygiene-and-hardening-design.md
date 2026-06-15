# Cilium-in-Action — Repo Hygiene & Security Hardening

**Date:** 2026-06-15
**Author:** Sergei Olshanetski (via Claude Code brainstorming)
**Status:** Approved — pending implementation
**Reference project:** [`kyverno-in-action`](../../../../kyverno-in-action) (same author, similar shape)

## Goal

Bring `cilium-in-action` to the same level of repo polish and security hygiene as `kyverno-in-action`. Two parallel tracks in one PR:

1. **Repo hygiene** — community-health files, CI, lint configs, issue/PR templates.
2. **Security hardening** — multi-stage non-root Dockerfiles, Pod Security Standards `restricted` posture on workloads, recommended `app.kubernetes.io/*` labels.

The demo's educational content stays untouched: same six scenarios, same NBA microservices, same `cilium-demo` Minikube profile.

## Non-goals

- No new demo scenarios (mutual auth, Gateway API, BGP, transparent encryption — all out).
- No Helm chart.
- No automated e2e tests beyond the existing manual demo script.
- No `kubectl` / Kubernetes / Cilium version bump (stays K8s 1.32, Cilium 1.19).
- No README rewrite — only additive (a "Documentation" link section).
- No image-signing (Cosign) workflow — that's kyverno's hook, not cilium's.

## Track 1 — Repo Hygiene

### Files to add

```
.github/
├── workflows/
│   └── validate.yml                # CI matrix below
├── dependabot.yml                  # weekly: github-actions, pip
├── GOVERNANCE.md                   # maintainer model
├── PULL_REQUEST_TEMPLATE.md
└── ISSUE_TEMPLATE/
    ├── bug_report.md
    └── feature_request.md
.shellcheckrc                       # disable SC1091,SC2001 (kyverno's settings)
.markdownlint.json                  # line_length 120; MD013 code blocks off; MD033/MD024 off
CONTRIBUTING.md                     # adapted from kyverno (cilium examples)
CODE_OF_CONDUCT.md                  # Contributor Covenant 2.1
SECURITY.md                         # responsible disclosure; scope (not Cilium itself)
TESTING.md                          # local validation + CI guide
TROUBLESHOOTING.md                  # Minikube RAM, Cilium readiness, Hubble port-forward, policy precedence
CHANGELOG.md                        # initial 1.0.0 entry summarizing existing work
```

### CI workflow jobs (`.github/workflows/validate.yml`)

Triggers: push to `main`/`develop`, PRs to same.

| Job | Tool | Target |
|---|---|---|
| `shellcheck` | shellcheck | `scripts/*.sh` |
| `yaml-lint` | yamllint -d relaxed | `k8s/*.yaml`, `cilium/*.yaml` |
| `cilium-policy-validation` | Python + PyYAML | Confirm `cilium/*.yaml` contain `kind: CiliumNetworkPolicy` (or `CiliumClusterwideNetworkPolicy`) with required spec fields |
| `docker-lint` | hadolint | `apps/*/Dockerfile` (continue-on-error: true initially) |
| `script-syntax` | `bash -n` | `scripts/*.sh` |
| `python-lint` | flake8 + black --check | `apps/` (continue-on-error: true; flake8 line-length 100) |
| `markdown-lint` | nosborn/github-action-markdown-cli@v3.5.0 | repo root (continue-on-error: true) |
| `docs-check` | shell | Asserts README.md, LICENSE, .gitignore, CONTRIBUTING.md, CODE_OF_CONDUCT.md, SECURITY.md, TROUBLESHOOTING.md, CLAUDE.md all exist |

Hadolint, markdown-lint, flake8, black start as `continue-on-error: true` to avoid blocking the first PR; they can be tightened later. This mirrors kyverno's pragmatic stance.

### `cilium-policy-validation` details

Adapt the kyverno equivalent. For each file in `cilium/*.yaml`, ensure at least one document has `kind: CiliumNetworkPolicy` (or `CiliumClusterwideNetworkPolicy`) and that `spec` exists with at least one of `ingress` / `egress` / `endpointSelector`. The check stops short of admission-level validation (no real apiserver) — purely structural.

## Track 2 — Container & Manifest Hardening

### Dockerfile rewrite (all three apps)

Single shape, multi-stage:

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

Changes vs. current:

- Multi-stage: build deps stay in the builder layer.
- Non-root: UID/GID 10001 (matches kyverno project).
- Runtime hygiene: `PYTHONUNBUFFERED`, `PYTHONDONTWRITEBYTECODE`.
- Healthcheck for parity with docker-native run.

We do **not** pin the base by digest. Dependabot covers the `FROM python:3.12-slim` tag for security updates, and digests rot fast in a demo repo.

### Kubernetes manifest hardening

For `k8s/scoreboard-api.yaml`, `stats-service.yaml`, `news-service.yaml`:

```yaml
metadata:
  labels:
    app: scoreboard-api                          # KEEP — Cilium endpointSelector depends on this
    role: public                                 # KEEP — used by some policies
    app.kubernetes.io/name: scoreboard-api       # ADD
    app.kubernetes.io/component: api             # ADD
    app.kubernetes.io/part-of: cilium-demo       # ADD
    app.kubernetes.io/managed-by: kustomize      # ADD (or "manual")
spec:
  template:
    metadata:
      labels:
        # mirror the deployment labels
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
          # … existing fields …
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

**Critical invariant:** the existing `app:` and `role:` labels remain unchanged. They are the selectors used by all `cilium/*.yaml` policies. We only **add** the `app.kubernetes.io/*` set.

#### Rogue pod (`k8s/rogue-pod.yaml`)

Tighten what we can without breaking its purpose (an unauthorized curl client). It does not need root, so:

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    seccompProfile: { type: RuntimeDefault }
  containers:
    - name: curl
      # … existing …
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities: { drop: [ALL] }
```

The `curlimages/curl:8.5.0` image already runs as a non-root user by default; the explicit settings just make it auditable.

### `readOnlyRootFilesystem` risk for Flask

Flask + Werkzeug occasionally write to `/tmp`. Mitigation: mount an `emptyDir` at `/tmp` for each Flask container (shown above). If a startup fail surfaces in validation, the fallback is to drop `readOnlyRootFilesystem` only on the affected container and note it.

## Validation Plan (must pass before PR merge)

Sequential, end-to-end:

1. `shellcheck -x scripts/*.sh` — clean (no warnings)
2. `yamllint -d relaxed k8s/ cilium/` — clean
3. `hadolint apps/*/Dockerfile` — clean (or known-acceptable warnings only)
4. `python -m py_compile apps/scoreboard-api/app.py apps/stats-service/app.py apps/news-service/app.py`
5. `./scripts/02-start-cluster.sh` — Cilium reaches Ready
6. `./scripts/03-deploy-app.sh` — all four pods reach `Ready`; `kubectl exec deploy/scoreboard-api -- id` returns `uid=10001`
7. `./scripts/04-demo-scenarios.sh` — all six scenarios produce expected ALLOWED / BLOCKED verdicts:
   - Scenario 1: rogue-pod → stats ALLOWED (no policy)
   - Scenario 2: rogue-pod → stats BLOCKED (L3/L4)
   - Scenario 3: POST/DELETE to stats BLOCKED (L7), GET ALLOWED
   - Scenario 4: external egress BLOCKED, internal ALLOWED
   - Scenario 5: Hubble flows visible (manual visual check)
   - Scenario 6: all expected verdicts in the zero-trust matrix
8. `./scripts/05-teardown.sh` — clean exit, no orphaned cluster

## Delivery

- **One feature branch:** `feature/repo-hygiene-and-hardening`
- **One PR titled:** `[feature] repo hygiene and security hardening`
- **Commit shape:** atomic commits per concern (`docs:`, `ci:`, `hardening(docker):`, `hardening(k8s):`, `chore:`) — but all in one PR for review locality.
- **PR description:** summary, motivation, validation evidence (links to local test output).

## Risks

| Risk | Mitigation |
|---|---|
| `readOnlyRootFilesystem` breaks Flask startup | `emptyDir` at `/tmp`; fallback is per-container drop |
| Renaming labels breaks Cilium endpointSelectors | Strict additive-only policy — verified by re-running scenarios |
| HEALTHCHECK script depends on `urllib` semantics | Verified locally; `python:3.12-slim` ships stdlib `urllib` |
| CI hadolint/flake8/black noise blocks PR | `continue-on-error: true` for the lenient jobs, tighten later |
| Dependabot opens too many PRs week one | `groups:` config to bundle pip + actions weekly |
| Cilium 1.19 + Kubernetes 1.32 minikube combination drifts | Out of scope — track in a follow-up if it breaks CI |

## Open questions

None. Design approved 2026-06-15.

## Acceptance criteria

- [ ] All Track 1 files exist and pass their respective linters in CI.
- [ ] All three Dockerfiles are multi-stage and run as UID 10001.
- [ ] All three workload Deployments and the rogue pod carry the documented `securityContext` and recommended labels.
- [ ] Existing `app:` and `role:` labels unchanged on all manifests.
- [ ] Full scripted demo (`02 → 03 → 04 → 05`) passes end-to-end with all expected verdicts.
- [ ] PR opened with validation evidence in the description.
