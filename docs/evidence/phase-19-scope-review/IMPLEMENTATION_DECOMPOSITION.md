# IMPLEMENTATION_DECOMPOSITION.md

**Do not implement now.** Proposed modular layout for a future authorized Phase 19:

```text
src/migration/transfer/
  codes.sh
  model.sh
  manifest.sh
  classify.sh
  capacity.sh
  state_machine.sh
  conflict_adapter.sh
  abort.sh
  resume_registry.sh
  report_ready_for_20.sh
src/migration/transfer/protocol/
  mtls_session.sh
  chunk_io.sh
  compress_zstd.sh
  ssh_fallback.sh
  bans.sh                 # FTP/TOFU/SaaS-relay guards
src/migration/transfer/payload/
  db_fc.sh                # wraps Phase 16 pg_dump_fc/restore_fc
  filestore_files.sh
  addons_registry.sh
  config_secrets.sh
  stages.sh
src/migration/transfer/source/
  write_freeze.sh
  availability.sh
  backup_gate.sh
src/migration/transfer/dest/
  staging_identity.sh
  apply_allowlist.sh
  validate.sh
src/migration/transfer/commands/
  transfer_plan.sh
  transfer_start.sh
  transfer_status.sh
  transfer_resume.sh
  transfer_abort.sh
```

## Reuse

- Phase 16 dump/restore/manifest helpers  
- Phase 14 ops engine (`migration_transfer_*`)  
- Phase 17 pair + cert material → durable transfer plane  
- Phase 18 readiness gates  
- `assert_no_transfer` replaced by **scoped** authorization helpers only when modules land  

## Assembler / VERSION

Bump installer only when implementation authorized (not this review). Proposed weight **5** remains **uncredited**.

## Structured codes (minimum)

`MIGRATION_TRANSFER_NOT_AUTHORIZED`, `MIGRATION_PAIR_REQUIRED`, `MIGRATION_ROUTING_NOT_READY`, `MIGRATION_BACKUP_GATE_FAILED`, `MIGRATION_CAPACITY_BLOCKED`, `MIGRATION_FREEZE_TIMEOUT`, `MIGRATION_FREEZE_RELEASED`, `MIGRATION_CHUNK_MISMATCH`, `MIGRATION_RESUME_REQUIRED`, `MIGRATION_STAGING_INVALID`, `MIGRATION_PUBLIC_LOGIN_FORBIDDEN`, `MIGRATION_SLOT_FORBIDDEN`, `MIGRATION_TOKEN_NOT_RESERVED`, `MIGRATION_TOKEN_NOT_CONSUMED`, `MIGRATION_STAGE_OPTIONAL_FAILED`, `MIGRATION_STAGE_MANDATORY_FAILED`, `MIGRATION_ABORT_PRESERVED`, `MIGRATION_READY_FOR_20_PASS`, `MIGRATION_READY_FOR_20_WARNING`, `MIGRATION_READY_FOR_20_BLOCKED`, `MIGRATION_DATA_EGRESS_DENIED`.
