# Shared primitive refactor
Stage live backup and Production backup share `pg_dump -Fc` helpers via `soviez_backup_pg_dump_fc` / availability checks.
`soviez_backup_stage_live_backup` closes Stage live-DB debt by attempting live dump when Postgres is available (fixture fallback in test mode).
