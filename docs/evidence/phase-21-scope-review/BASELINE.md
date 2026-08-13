# BASELINE.md — Phase 21 Scope Review

## Certified state (input)

| Item | Value |
|------|-------|
| Phases 16–20 | **PASS** |
| Progress | **96%** |
| Installer | `0.20.0-phase20` |
| Artifact SHA256 | `4e4eafc9ebb1fe8db62b789faead89476b03455536e5c1cd33e6c470963288d9` |
| Phase 11.5 | FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED |
| Phase 21 impl | **NOT AUTHORIZED** |
| Phase 22+ | **UNAUTHORIZED** |

## Dirty-state preservation

No runtime changes. Phase 20 evidence under `docs/evidence/phase-20-*` remains authoritative for authorization/rebind. This review adds documentation only under `docs/evidence/phase-21-scope-review/`.

## Repositories

| Repo | Role |
|------|------|
| `soviez-sh` | Cutover orchestration, DNS instruction, nginx/SSL promote, health/smoke, rollback |
| `soviez-saas` | Ledger `traffic_owner` / cutover audit metadata (no payload relay) |
| `Soviez ERP` | `local_license_guard` — **gap:** lacks first-class `migration_origin_grace`, `production_licensed_pre_cutover`, `traffic_owner` |
| `soviez-deploy/soviez.sh` | Legacy reference only — **not** cutover authority |

## Pre-Phase-21 system posture (from Phase 20 PASS)

```text
MIGRATION TOKEN — CONSUMED EXACTLY ONCE
SOURCE — migration_origin_grace (traffic active, writes restricted)
DESTINATION — production_licensed_pre_cutover (internal Production-mode, public_route=false)
TRAFFIC_OWNER — source
PRODUCTION DNS — UNCHANGED (still resolves to source)
PHASE 21 READINESS — PASS / WARNING / BLOCKED (signed, TTL-bound)
```

## Artifact check (review start)

```text
version: 0.20.0-phase20
SHA256: 4e4eafc9ebb1fe8db62b789faead89476b03455536e5c1cd33e6c470963288d9
```

Must remain identical at review end.

## Scope review constraints

- English, concise technical prose.
- No secrets, credentials, or live DNS mutation runbooks that imply execution.
- No changes to `VERSION`, `dist/`, SaaS UI, or progress accounting numbers.
- Proposed progress weight **1** documented but **not applied** (remaining budget ~4% for Phases 21–25).
