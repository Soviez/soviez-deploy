# GIT_DIFF_SUMMARY — Phase 8

**Date:** 2026-07-30  
**Repository:** `soviez-sh` (untracked tree in certification workspace)

## Note

The `soviez-sh` tree is not yet committed to git in this workspace (`git status` shows untracked). This summary describes the Phase 8 deliverable surface area rather than a commit diff.

## New directories

| Path | Files (approx) | Purpose |
|------|----------------|---------|
| `src/` | 39 | Modular installer source |
| `build/` | 1 | Assembly script |
| `dist/` | 2 | Generated artifact + sha256 |
| `tests/` | 14+ | Unit + integration + helpers |
| `schemas/` | 1 | Operation state JSON schema |
| `docs/evidence/phase-08-new-connected-activation/` | 22 | Evidence pack |
| `docs/ai/`, `docs/dev/`, `docs/user/` | Updated + 2 new | Documentation |

## Key new files (installer)

```
src/commands/new.sh          — main orchestration (~224 lines)
src/license/activate_orm.sh  — ORM activation (~52 lines)
src/operations/state_machine.sh — 29 states
build/assemble.sh            — 36-module assembly
tests/run_all.sh             — test runner
tests/integration/mock_saas_server.py — mock SaaS
```

## Key new files (documentation)

```
docs/ai/NEW_INSTANCE_CONNECTED_ACTIVATION_MODEL.md
docs/dev/NEW_COMMAND_PROTOCOL.md
docs/user/INSTALLATION.md
docs/evidence/phase-08-new-connected-activation/FINAL_REPORT.md
```

## Modified documentation (append Phase 8)

- 13 existing docs updated with Phase 8 sections
- `PROJECT_STATE.md` — PARTIAL status

## Explicitly absent from diff

- `soviez-saas/**` — no changes
- `Soviez ERP/addons/local_license_guard/**` — no changes
- `.env`, credentials, secrets

## Generated artifact

```
dist/soviez.sh         — assembled installer (do not edit)
dist/soviez.sh.sha256  — 34ab9413ae86d2b66adcdeed0ea16c9e92c4a1485bd8c15528c939c9d06fabb2
```

SHA256 subject to change on rebuild — see `dist/soviez.sh.sha256`.

## No commit

Per phase gate instructions: no git commit in this session.
