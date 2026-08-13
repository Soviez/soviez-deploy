# FINAL_CUTOVER_SYNC — Phase 21

**Status:** STUB

## Design facts tested

- Bounded freeze (`SOVIEZ_MIG_P21_FREEZE_MAX_SECONDS`, default 900)
- Markers: database snapshot + filestore reconciliation
- `SOVIEZ_MIG_P21_INJECT_SYNC_FAIL=1` → `MIGRATION_FINAL_CUTOVER_SYNC_FAILED`
- Does not re-consume migration token

## Evidence to attach

- [ ] `sync_markers/report.json` excerpt after successful cutover
- [ ] Sync fail inject error code
