# SECRET_SCAN

## Tool run (this audit)
- Command: `tools/secret_scan.sh all`
- Result: **SECRET_SCAN — PASS**
- gitleaks: not installed — embedded scanner authoritative
- Git history scan: N/A (zero commits)

## Manual sensitive findings (publication hygiene — BLOCKERS if not excluded)

| File | Classification | Notes |
|------|----------------|-------|
| `keys.json` | SECRET_OR_SENSITIVE | Offline key map at repo root — **DO_NOT_PUBLISH** |
| `ticket.token` | SECRET_OR_SENSITIVE | JWT ticket — **DO_NOT_PUBLISH** |
| `offline-package.json` | SECRET_OR_SENSITIVE | Offline auth package — **DO_NOT_PUBLISH** |
| `.tmp/**/*.key`, dumps | SECRET_OR_SENSITIVE | Local test material — **DO_NOT_PUBLISH** |
| saas `.env*` | SECRET_OR_SENSITIVE | Present on disk; gitignored — verify never staged |

## Verdict for publishable set
Embedded scan PASS. **Publication readiness requires `.gitignore` + explicit exclusion of root credential files** before first commit (see OPEN_ITEMS / BLOCKER_MATRIX).

Secret findings count (blocking if included in commit): **3 root files + .tmp key material**  
Secret findings in intended publish set after exclusions: **0**
