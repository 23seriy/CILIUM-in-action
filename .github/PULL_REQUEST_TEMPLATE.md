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
