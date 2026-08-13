# GIT_STATE

## soviez-sh
- Inside work tree: YES
- HEAD: **NO COMMITS** (`rev-parse HEAD` fails / empty history)
- Current branch: unborn / no named branch with commits
- Upstream: none
- Remotes: **none**
- Dirty/untracked status lines: **133** (entire tree untracked; includes many `.tmp.*` root temps)
- Provenance quality: **ZERO_HISTORY** — cycle work cannot be reconstructed from commits; use evidence packs + file classification
- `main` local: NO
- remote `main`: N/A (no remote)

## Soviez ERP
- Branch: `dev` @ `81be9f9840a1ab8716219d637e1cf3f356dae9cf`
- Upstream: tracks `origin/dev` (same tip as `main` / `origin/main` at audit time)
- Remotes: `origin` = `https://github.com/Soviez/soviez-erp.git`
- Dirty/untracked status lines: **138** (mostly `venv/` churn + UI evidence + `soviez.sh` + `CHANGELOG.md`)
- Provenance quality: **GOOD_REMOTE_HISTORY** + dirty overlay; cycle delta for wizard is uncommitted on `dev`
- `main` local: YES (same commit as `dev`)
- remote `main`: YES (exists; equal tip observed locally)

## soviez-deploy
- Branch: `main` @ `afe6de5be61e8737a730a575c84fe8fb5be0050b` tracking `origin/main`
- Dirty: **1** file — `soviez.sh` (+379/−79)
- Provenance quality: **EXCELLENT** — single-file cycle delta on clean main
- remote `main`: YES

## soviez-saas
- Branch: `main` @ `2f2f13c655ac42aa976764db56d939bf60a40094` tracking `origin/main`
- Also: `staging` behind remote
- Dirty/untracked status lines: **125** (expanded untracked file set much larger under new dirs)
- Provenance quality: **GOOD_REMOTE_HISTORY** + large uncommitted lifecycle overlay
- remote `main`: YES

## Policy note
`git fetch --dry-run` / network remote reachability: **NOT executed** in this audit (avoid unexpected ref updates). Remote existence inferred from configured URLs + local tracking refs. Authentication: appears configured historically (prior pushes exist) but live auth not re-probed — mark reachability **UNKNOWN_LIVE**.
