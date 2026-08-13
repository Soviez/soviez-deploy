# Implementation Decomposition — Phase 16 (Proposed)

**Do not implement now.** Structure for a future authorized phase.

## Recommended modules

```text
src/backup/
  codes.sh
  paths.sh
  model.sh
  targeting.sh
  inventory.sh
  consistency.sh
  capacity.sh
  database.sh
  filestore.sh
  manifest.sh
  checksum.sh
  compression.sh
  encryption.sh
  destinations.sh
  local_destination.sh
  remote_destination.sh
  transfer.sh
  verify.sh
  retention.sh
  schedule.sh
  export.sh
  import.sh
  engine.sh

src/restore/
  codes.sh
  targeting.sh
  compatibility.sh
  preflight.sh
  candidate.sh
  database.sh
  filestore.sh
  metadata.sh
  validate.sh
  switch.sh
  rollback.sh
  recovery.sh
  engine.sh
```

Equivalent modular layout is acceptable if responsibilities stay separated.

## Shared extractions (future refactor)

| Existing | Proposed share |
|----------|----------------|
| `src/stage/pg.sh` dump/restore helpers | Shared low-level PG module used by Stage create + Production backup/restore |
| Phase 15 checksum/manifest patterns | Shared integrity helpers (keep update schema distinct) |
| Phase 15 candidate workspace + LG temp identity | Restore candidate binder (no new permanent slot) |
| Phase 14 ops registry/conflicts/adapters | Register new op types + conflict rows |

## Must remain phase-specific

| Keep separate | Why |
|---------------|-----|
| `src/update/backup.sh` recovery_set | Update rollback semantics / 24h window |
| Stage retention final backup orchestration | Stage lifetime / Safe Shield |
| Stage create UUID rotate clone | Not Production restore |

## Adjacent debt (may be separate auth)

Refactor `soviez_stage_cmd_backup` live DB dump gap — required for honest Stage/retention archives; not a substitute for Production product.

## Suggested delivery slices (after auth)

1. Object model + local Full backup + inventory CLI  
2. Integrity verification + retention/pin  
3. Encryption + remote destinations  
4. Candidate restore-test  
5. Production restore switch + rollback window  
6. Scheduling + conflict/perf hardening  

Each slice needs tests from `TEST_PLAN.md`.
