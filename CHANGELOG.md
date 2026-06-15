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
