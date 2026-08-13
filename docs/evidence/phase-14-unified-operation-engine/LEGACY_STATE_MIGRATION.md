# Legacy State Migration

**Phase:** 14  
**Verdict:** PASS  

## 1. State Mapping Validation

Legacy states are migrated into the new schema structure via `src/ops/migration.sh`:

- **Phase 8:** Legacy `state.json` is mapped to canonical JSON. The command is set to `new` and any existing state string is written into `current_checkpoint`.
- **Phase 11:** Legacy Stage workspace JSON matches `stage_create`.
- **Phase 12:** SSL workspace state files map to `ssl_renewal` or `ssl_repair`.
- **Phase 13:** Retention JSON files are resolved via `retention_operation_id` to `retention_delete`.

## 2. Recovery Safety

- Existing legacy state files are backed up to `<filename>.pre-phase14.bak`.
- Conversion is fully idempotent; calling migration on an already upgraded canonical file exits successfully without rewriting.
