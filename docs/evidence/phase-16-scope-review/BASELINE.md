# Baseline — Phase 16 Scope Review

**Date:** 2026-08-01  
**Type:** Documentation / scope correction only  
**Runtime code changed:** No  
**Installer artifact changed:** No  
**Progress credit applied:** No (remains **78%**)  
**Implementation authorized:** No

## Certified project state (pre–Phase 16)

| Item | Value |
|------|-------|
| Phase 14 Unified Operation Engine | **PASS** |
| Phase 15 Safe Update | **PASS** |
| Phase 15 final certification closure | **PASS** |
| Credited progress | **78%** (`72+6`) |
| Installer version | `0.15.0-phase15` |
| Artifact | `dist/soviez.sh` (unchanged this task) |
| Phase 11.5 | FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED (uncredited) |
| Phase 16 prior status | Unauthorized; obsolete plan title “Backup/restore” |

## Repository baselines inspected

| Path | Role |
|------|------|
| `/Volumes/PortableSSD/soviez-project/soviez-sh` | Primary — modular installer source of truth |
| `/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh` | Legacy monolith backup CLI reference |
| `/Volumes/PortableSSD/soviez-project/soviez-saas` | SaaS offline Stage package (auth ticket only) |
| `/Volumes/PortableSSD/soviez-project/Soviez ERP` | Odoo `/web/database/backup|restore` (exclude) |

## Key source paths (inventory anchors)

| Capability | Paths |
|------------|-------|
| Stage create snapshot / PG | `src/stage/snapshot.sh`, `clone.sh`, `pg.sh` |
| Stage `--stage-backup` | `src/stage/lifecycle.sh` → `soviez_stage_cmd_backup` |
| Retention final backup | `src/stage/retention_engine.sh` → `soviez_retention_final_backup` |
| Ops conflict / adapters | `src/ops/conflicts.sh`, `src/ops/adapters.sh` |
| Update recovery set | `src/update/backup.sh`, rollback/candidate modules |
| CLI surfaces | `src/cli/parse.sh`, `src/entrypoint.sh` |

## Governance docs baseline

- `docs/ai/MASTER_IMPLEMENTATION_PLAN.md` — Phase 16 was “Keep backup; add restore” (incorrect: no Production `--backup`/`--restore` in soviez-sh)
- `docs/ai/CURRENT_STATE.md` / `PROJECT_STATE.md` — Phase 16 unauthorized; progress 78%
- `docs/ai/DECISION_LOG.md` — through D095 (Phase 15 PASS)

## Explicit non-actions this task

- Do not credit Phase 16 weight
- Do not change version off `0.15.0-phase15`
- Do not regenerate `dist/soviez.sh`
- Do not modify `src/`, `tests/`, or `dist/`
- Do not implement backup/restore product behavior
- Do not commit, push, deploy, or publish

## Outcome of this review

See `FINAL_REPORT.md` and `CORRECTED_SCOPE.md`. Status after review:

```text
Phase 16 = SCOPE REVIEW COMPLETE — IMPLEMENTATION NOT AUTHORIZED
Progress = 78%
```
