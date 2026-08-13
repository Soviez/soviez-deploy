# PRE_PUBLISH_TEST_REQUIREMENTS

## Required before owner authorizes commit/push
1. Confirm `.gitignore` added and root secrets untracked
2. `tools/docs_validate.sh` (PASS this audit)
3. `tools/secret_scan.sh all` after gitignore (re-run)
4. Dual-wizard `sha256` equality
5. Artifact SHA verify
6. Static contracts: migration CLI, websocket, workers=0, proxy_mode
7. Publication manifest review (no UNKNOWN in publish set) — PASS

## Fresh run_all?
**CURRENT_RUN_ACCEPTABLE** if no further source changes.  
If gitignore-only / evidence-only adds: still acceptable.  
If any `src/` or wizard edit: **FRESH_RUN_ALL_REQUIRED_BEFORE_PUBLISH**.

## Optional but recommended before live sim
- SaaS migration apply on staging + installer-auth smoke
- Wizard smoke on disposable VPS
