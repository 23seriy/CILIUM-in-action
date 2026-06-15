# Fix Demo-Script Verdict Reporting

**Date:** 2026-06-15
**Author:** Sergei Olshanetski (via Claude Code brainstorming)
**Status:** Approved
**Related:** Follow-up to PR #6 (repo hygiene & hardening) — flagged the bug, this fixes it.

## Goal

Make `scripts/04-demo-scenarios.sh` print accurate ALLOWED / BLOCKED verdicts when Cilium L7 returns HTTP 4xx. Today, scenarios 3b, 3c, and 6e mislabel HTTP 403 (Cilium L7 block) as "ALLOWED" because Python exits 0 even when it printed a non-200 status.

## Root cause

Each verdict check has this shape:

```bash
python -c "import requests; r=requests.get(URL); print(f'Status: {r.status_code}')" 2>/dev/null && \
    info "✅ ALLOWED" || \
    error "❌ BLOCKED"
```

The bash `&& / ||` chain branches on Python's exit code, not on `r.status_code`. Python exits 0 whenever the `requests` call returns a Response — even a 403. So:

- L3/L4 block → `requests` raises `ConnectionError` → Python exits 1 → `error BLOCKED` (correct)
- L7 block (HTTP 403) → `requests` returns 403, Python prints and exits 0 → `info ALLOWED` (**wrong**)

## Fix

Add `sys.exit(0 if r.status_code < 400 else 1)` to every `python -c` block. Python's exit code now reflects the HTTP outcome, and the existing `&& / ||` pattern produces correct verdicts uniformly across all 9 sites.

Before:

```bash
python -c "import requests; r=requests.get(URL); print(f'  Status: {r.status_code}')" 2>/dev/null && \
    info "✅ ALLOWED" || \
    error "❌ BLOCKED"
```

After:

```bash
python -c "import requests,sys; r=requests.get(URL); print(f'  Status: {r.status_code}'); sys.exit(0 if r.status_code < 400 else 1)" 2>/dev/null && \
    info "✅ ALLOWED" || \
    error "❌ BLOCKED"
```

## Sites to change

All 9 `python -c "import requests..."` blocks in `scripts/04-demo-scenarios.sh`:

| Line | Method | Scenario | Today | After fix |
|---|---|---|---|---|
| 55  | GET    | 1a baseline scoreboard→stats           | ✅ correct | ✅ correct |
| 84  | GET    | 2a L3/L4 scoreboard→stats              | ✅ correct | ✅ correct |
| 113 | GET    | 3a L7 GET scoreboard→stats             | ✅ correct | ✅ correct |
| 120 | POST   | 3b L7 blocks POST                      | ❌ wrong (`ALLOWED`) | ✅ `BLOCKED` |
| 127 | DELETE | 3c L7 blocks DELETE                    | ❌ wrong (`ALLOWED`) | ✅ `BLOCKED` |
| 150 | GET    | 4a DNS+L3/L4 scoreboard→stats          | ✅ correct | ✅ correct |
| 212 | GET    | 6a zero-trust scoreboard→stats         | ✅ correct | ✅ correct |
| 218 | GET    | 6b zero-trust scoreboard→news          | ✅ correct | ✅ correct |
| 238 | POST   | 6e zero-trust POST                     | ❌ wrong (`ALLOWED`) | ✅ `BLOCKED` |

## Non-goals

- Do not rewrite `A && B || C` to `if/then/else`. SC2015 stays disabled in `.shellcheckrc`.
- Do not touch `curl`-based rogue-pod checks (lines 60–64, 89–93, 222–224, 229–231). They use `curl --connect-timeout 3` which already returns non-zero on connection failure, so the verdicts work.
- Do not change the warn/info wording or NBA narration around each block.
- No new tests, no new policies, no new scenarios.

## Validation

1. `shellcheck -x scripts/*.sh` — clean
2. `bash -n scripts/04-demo-scenarios.sh` — syntax check
3. End-to-end demo run: `./scripts/02-start-cluster.sh && ./scripts/03-deploy-app.sh && ./scripts/04-demo-scenarios.sh`
   - Scenarios 3b / 3c / 6e print `✅ BLOCKED — Cilium L7` (or similar), no longer `⚠️ ALLOWED`
   - Other scenarios produce identical output to today
4. CI green on PR

## Risks

- **Tiny**: a future test that expects a 2xx body but receives a different 2xx (e.g., 204 No Content from a route that should return 200) would still be marked ALLOWED. Acceptable — this is not how the current scenarios work.
- **Pre-existing dead `error` branches** at lines like 86 now have a non-zero chance of firing if a deploy regresses (e.g., a 500). That is a **feature** — the script becomes more useful for catching regressions.

## Delivery

- Branch: `fix/demo-script-verdict-reporting`
- Single PR titled: `[fix] correct demo-script verdicts on HTTP 4xx`
- Single commit: `fix(scripts): exit non-zero on HTTP >=400 so demo verdicts are accurate`

## Acceptance criteria

- [ ] All 9 `python -c` sites in `scripts/04-demo-scenarios.sh` include `sys.exit(0 if r.status_code < 400 else 1)`.
- [ ] No other lines in `scripts/04-demo-scenarios.sh` are modified.
- [ ] `shellcheck -x scripts/*.sh` clean.
- [ ] End-to-end demo run shows correct verdicts for 3b, 3c, 6e.
- [ ] PR opened and CI green.
