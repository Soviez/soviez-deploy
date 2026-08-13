# BASELINE — Phase 21 Production Cutover

**Status:** STUB — populate after test run

## Design facts

- Prior installer: `0.20.0-phase20` (Phase 21 unauthorized)
- Target installer: `0.21.0-phase21`
- Phase 21 scope review: `docs/evidence/phase-21-scope-review/FINAL_REPORT.md`
- Implementation modules: `src/migration/cutover/`, `rollback/`, `production_domain/`, `final_cutover_sync/`, `source_transition/`, `destination_go_live/`, `phase22_readiness/`

## Baseline artifacts to capture

- [ ] `dist/soviez.sh` version + SHA256
- [ ] Smoke test output (`.tmp/smoke_p21*.sh`)
- [ ] Pre-cutover Phase 20 fixture state snapshot
