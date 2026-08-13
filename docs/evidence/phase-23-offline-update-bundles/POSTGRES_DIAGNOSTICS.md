# POSTGRES_DIAGNOSTICS

## Prior failures
Disposable `postgres:16` / `postgres:16-alpine` fixtures died under Colima ENOSPC (see DOCKER_COLIMA_DIAGNOSTICS.md). Secondary harness defect: `SOVIEZ_TEST_PG_CONTAINER: unbound variable` in old `stage_live_pg.sh` on failed start under `set -u`.

## Corrections
- `stage_live_pg.sh`: inspect by local name before export; log + fail if container dies mid-readiness; optional disk gate hook
- `soviez_phase23_postgres_preflight`: pull/start labeled disposable, `pg_isready` bounded wait, remove
- Schema upgrade / transfer e2e: no `--rm` until ready; labels for exact reset
- Phase 23 SaaS schema test applies migration 090 on disposable PG with readiness + death detection

## Classification
Primary: ENVIRONMENT_FLAKE (ENOSPC). Secondary: TEST_HARNESS_DEFECT (unbound variable) — fixed.
