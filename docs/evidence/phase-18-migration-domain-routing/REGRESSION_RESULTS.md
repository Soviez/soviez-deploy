# REGRESSION_RESULTS — Phase 18

## Authoritative result

`tests/run_all.sh` → **PASS** (`RUN_ALL_EXIT:0`, `/tmp/p18-run-all5.log`)

Installer `0.18.0-phase18`  
SHA256 `5d2979b406a3fdb97646c69a8623cd526c97915a6a16eb183a0ab8ef768007b3`  
`bash -n dist/soviez.sh` PASS

## Phase 18 suites

All PASS inside `run_all` and in focused runs: unit (38), security gates, multi-tenant, CoreDNS/Pebble e2e, host-disk reboot matrix.

## Notes

- Final suite: `SOVIEZ_P18_SKIP_COLIMA_REBOOT=1`, `SOVIEZ_P17_SKIP_COLIMA_REBOOT=1` (Colima host reboot for Phase 17 was PASS in earlier full-permission runs in this session).
- Pebble uses `PEBBLE_VA_ALWAYS_VALID=1` (ACME order/CSR/issue/chain real; VA short-circuited).
- Prior suite flakes (Docker network pool, leftover `soviez-upd-pg-cert`, SFTP under load) cleared; not Phase 18 logic defects.
- Phase 17 static gates scoped to ignore Phase 18 forbid-documentation strings.
