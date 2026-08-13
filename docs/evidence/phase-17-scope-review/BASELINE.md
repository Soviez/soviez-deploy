# Baseline — Phase 17 Scope Review

**Date:** 2026-08-01  
**Type:** Documentation / scope correction only  
**Runtime code changed:** No  
**Installer artifact changed:** No  
**Progress credit applied:** No (remains **84%**)  
**Implementation authorized:** No  
**Installer version:** `0.16.0-phase16`  
**Artifact SHA256:** `6560270687629460870da65bd05e30af19eb0bc2c3bf6d7749af2286ec7cf2b3`

## Certified project state (pre–Phase 17 implementation)

| Item | Value |
|------|-------|
| Phase 14 Unified Operation Engine | **PASS** |
| Phase 15 Safe Update | **PASS** |
| Phase 16 Production Backup, Restore, Verification, and Recovery | **PASS** |
| Credited progress | **84%** (`78+6`) |
| Installer version | `0.16.0-phase16` |
| Artifact | `dist/soviez.sh` (unchanged this task) |
| Phase 11.5 | FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED (uncredited) |
| Phase 17 prior plan status | Unauthorized stub: “Migration discovery and destination bootstrap” |
| Phase 18+ | Unauthorized |

## Repository baselines inspected

| Path | Role |
|------|------|
| `/Volumes/PortableSSD/soviez-project/soviez-sh` | Primary — modular installer source of truth |
| `/Volumes/PortableSSD/soviez-project/soviez-saas` | Commercial Migration Token + license hardware migrate APIs |
| `/Volumes/PortableSSD/soviez-project/Soviez ERP` | License Guard / deactivation receipt (Phase 20 boundary) |
| `/Volumes/PortableSSD/soviez-project/soviez-deploy/soviez.sh` | Legacy monolith — `--init`, `SOVIEZ_MIGRATION_SECRET` (not server migrate) |

## Dirty-state preservation

Git: `No commits yet on main`. Large dirty/untracked tree preserved. **No commit/push/merge/tag/deploy/publish** in this review.

## Binding future outcome (post-implementation only)

```text
SOURCE DISCOVERY — COMPLETE
DESTINATION BOOTSTRAP — COMPLETE
MIGRATION PAIR — TRUSTED
READINESS — PASS / BLOCKED / NEEDS ACTION
NO DATA TRANSFER STARTED
SOURCE REMAINS ACTIVE
MIGRATION TOKEN NOT CONSUMED
```

## Key absences (Phase 17 core)

| Capability | Status |
|------------|--------|
| `src/migration/` | **Missing** |
| `--migrate-in` / `--merge-in` CLI | **Missing** (never implemented; plan name is `--migrate-in`) |
| Destination `--init` in soviez-sh | **Missing** (legacy only) |
| Signed installer bootstrap delivery | **Missing** as migrate product |
| Source discovery assistant | **Missing** |
| Migration-pair / trust pairing | **Missing** |
| Cross-host restore | **Denied** (Phase 16 OD-08 → migration later) |
