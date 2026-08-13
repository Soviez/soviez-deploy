# LIVE_POSTGRES_E2E

**Date:** 2026-07-30  
**Result:** **PASS**

## Topology

- Disposable Docker container from already-present local image `postgres:16`
- Dynamic host port bound to `127.0.0.1`
- Disposable user/password (not recorded in evidence)
- Source DB `soviez_prod_source` with:
  - `ir_config_parameter.database.uuid`
  - `res_partner` / `account_move` (FK integrity)
  - `ir_attachment` pointing at real filestore binary `attachments/doc1.bin`
- Stage DB name from inventory (`stage_<id>`)
- Installer path: `soviez_cmd_stage_create_run` with `SOVIEZ_STAGE_USE_LIVE_PG=1`

## Commands

```bash
bash build/assemble.sh
bash tests/integration/test_stage_live_postgres_e2e.sh
```

## Proven

| Assertion | Result |
|-----------|--------|
| Actual `pg_dump -Fc` (PGDMP magic) | PASS |
| Actual `pg_restore` into new Stage DB | PASS |
| Source invariant unchanged | PASS |
| Source filestore checksum unchanged | PASS |
| Row counts partners=2 moves=3 atts=1 | PASS |
| FK orphans = 0 | PASS |
| Stage UUID ≠ Production UUID | PASS |
| Attachment resolves from cloned filestore | PASS |
| No writable shared filestore / no symlink | PASS |
| Duplicate Stage DB restore denied | PASS |

## Durations (example run)

- Stage create wall time ≈ 5–11s on this workstation
- Snapshot via docker-exec `pg_dump` matching server major 16

## Limitations

- Disposable Odoo HTTP runtime not launched; DB+filestore proven via installer path (acceptance contract allows this when justified).
- Host Homebrew `pg_dump` is PG15; live path uses container-local PG16 clients to avoid version mismatch.
