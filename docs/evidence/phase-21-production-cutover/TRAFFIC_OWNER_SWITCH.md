# TRAFFIC_OWNER_SWITCH — Phase 21

**Status:** STUB

## Design facts tested

- Schema `soviez.traffic_owner.v1` signed at `$SOVIEZ_MIG_ROOT/traffic_owner/<auth-id>.json`
- Default `source`; cutover commit sets `destination` exactly once
- Idempotent re-switch is no-op

## Evidence to attach

- [ ] traffic_owner.json before/after cutover
- [ ] Rollback restores `source`
