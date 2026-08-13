# Overlap and Duplication Analysis — Phase 16

## Problem statement

Multiple “backup-like” paths exist. Treating any of them as the Production backup/restore product without correction creates false safety and duplicate engines.

## Overlap matrix

| Capability | Looks like backup? | Restore-capable full unit? | Safe as Phase 16 product base? |
|------------|--------------------|----------------------------|--------------------------------|
| Phase 11 Stage snapshot | Yes (internal) | Stage-only clone | Reuse **primitives**, not CLI product |
| Phase 11 `--stage-backup` | Yes (CLI name) | **No** (live DB gap) | **No** — refactor required |
| Phase 13 final backup | Yes (ops) | **No** (inherits gap) | Ops/retention patterns only |
| Phase 14 reserved slots | Naming only | N/A | Extend conflict registry |
| Phase 15 recovery set | Yes (internal) | Update rollback only | Pattern reuse; not product |
| Legacy `--backup` | Yes (product-ish) | Backup only, no restore | Spec reference; reimplement modularly |
| Odoo web backup/restore | Yes | Yes (unsafe) | **Exclude** |

## Duplicate-implementation risks

1. **Second dump engine** — Reimplementing `pg_dump -Fc` beside `src/stage/pg.sh` without shared module.  
2. **Calling `--stage-backup` for Production** — Wrong environment semantics + DB gap.  
3. **Promoting Phase 15 recovery_set to user backups** — Fixture/copy semantics; 24h update-scoped; wrong retention.  
4. **Forking legacy monolith** — Brings space check/tar patterns but not ops engine, encryption, candidate restore.  
5. **Enabling Odoo web restore** — Circumvents License Guard, ops locks, exact targeting.  
6. **Equating retention archive with Production backup** — Stage lifetime / Safe Shield semantics leak into Production.

## Recommended ownership boundaries

| Concern | Owner after Phase 16 (proposed) |
|---------|----------------------------------|
| Production full backup/restore product | **New** `src/backup/` + `src/restore/` |
| Stage create clone dump/restore | Remain Phase 11; share low-level PG helpers |
| Stage ad-hoc backup CLI | Refactor separately; not Phase 16 Production MVP unless owner expands |
| Retention final archive | Remain Phase 13; may later call shared dump if Stage full backup is fixed |
| Update recovery set | Remain Phase 15-internal |
| Ops conflict/types | Phase 14 extended by Phase 16 adapters |
| Legacy CLI | Freeze as reference; do not dual-maintain |

## Corrected narrative vs old plan

| Old plan phrase | Reality |
|-----------------|---------|
| “Keep backup” | Legacy had backup; **soviez-sh does not** |
| “Add restore” | Implies backup already exists in modular installer — **false** |
| Complexity Medium, no weight | Propose weight **6** (uncredited) matching Phase 15 Medium-High style |

## Required refactors (documentation only now)

1. Refactor `soviez_stage_cmd_backup` to use real `pg_dump -Fc` on live Stage (or clearly label incomplete).  
2. Extract shared dump/filestore/manifest helpers for Stage create, Stage backup, Production backup, update recovery (when authorized).  
3. Do **not** silently widen Phase 15 recovery set into general backup retention.
