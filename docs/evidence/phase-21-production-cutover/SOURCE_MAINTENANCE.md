# SOURCE_MAINTENANCE — Phase 21

**Status:** STUB

## Design facts tested

- State machine: `migration_origin_grace` → `cutover_freeze` → `cutover_maintenance`
- Signed maintenance page (no tracking scripts)
- AR-09: `soviez_migration_source_transition_deny_writes` during freeze/maintenance

## Evidence to attach

- [ ] `source_restricted.json` state after cutover
- [ ] Write denial error code excerpt
