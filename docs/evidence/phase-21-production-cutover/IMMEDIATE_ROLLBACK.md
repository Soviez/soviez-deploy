# IMMEDIATE_ROLLBACK — Phase 21

**Status:** STUB

## Design facts tested

- R0: pre-commit (`traffic_owner=source`)
- R1: post-commit within window, no meaningful writes
- R3: `SOVIEZ_MIG_P21_MEANINGFUL_WRITES=1` → `MIGRATION_ROLLBACK_NOT_SAFE`
- AR-04 split-brain auto trigger
- Token never restored on rollback

## Evidence to attach

- [ ] R1 rollback JSON
- [ ] R3 denial log
- [ ] `rollback_window.json` timestamps
