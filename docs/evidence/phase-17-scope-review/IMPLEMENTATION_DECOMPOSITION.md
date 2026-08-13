# Implementation Decomposition — Phase 17 (proposed; not implemented)

```text
src/migration/discovery/
  codes.sh
  targeting.sh
  identity.sh
  runtime.sh
  capacity.sh
  addons.sh
  stages.sh
  network.sh
  report.sh
  engine.sh

src/migration/bootstrap/
  codes.sh
  host_preflight.sh
  installer.sh
  prerequisites.sh
  init.sh
  identity.sh
  validate.sh
  abort.sh
  engine.sh

src/migration/pairing/
  codes.sh
  challenge.sh
  trust.sh
  certificate.sh
  verify.sh
  revoke.sh
  engine.sh

src/migration/readiness/
  compatibility.sh
  capacity.sh
  connectivity.sh
  backup_prerequisite.sh
  commercial.sh
  report.sh
  engine.sh

src/migration/pair/
  object.sh
  persist.sh
  abort.sh

src/commands/migration_*.sh   # CLI adapters
tests/unit/migration/
tests/integration/migration/
tests/security/migration/
```

## Assemble / wiring (future)

- Register modules in assemble manifest  
- Extend `src/ops/conflicts.sh` / adapters for new op types  
- **Do not** overload `src/ops/migration.sh` name — keep schema remapper separate  

## Explicit non-goals of this review

No modules created on disk in this task.
