# FIXTURE_PRECHECK_AND_RESET.md

Helper: `tests/helpers/fixture_preflight_reset.sh`

- Colima/Docker health check + start if needed
- Exact-owned network GC: `soviez-bk-rtest-net-*`, `soviez-upd-net-*`, `soviez-p19-stg-*`
- Exact-owned exited container GC: `soviez-upd-cand-*`, `soviez-p19-erp-*`, `soviez-p19-pg-*`, `p18*`
- Stale freeze markers under disposable `/tmp/soviez-*` and `.tmp/p19-*` only
- SFTP port 2222 readiness check
- Mid-run soft GC when network count ≥ 20

**Hard bans obeyed:** no `docker system prune`, no broad volume/network wipe, no wildcard process kill.
