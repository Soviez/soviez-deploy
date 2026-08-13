# CLEAN_RUN_HISTORY — Phase 19 certification gap closure

## Run 1 — FAILED (environment dirty / incomplete)

- **Log:** `/tmp/p19-auth-run-all-FAIL1.log`
- **SHA256:** `a82119c14e4c6f9282839de357da6cae6256d8a391cc0ede3e5b61182da395f6`
- **Failures:** SFTP; destination_host; restore_test (`address pools fully subnetted`)
- **Notes:** Orphaned Docker networks; Colima disruption mid-stage suites

## Run 2 — FAILED (static security allowlist)

- **Log:** `/tmp/p19-auth-run-all-FAIL2.log`
- **SHA256:** `eb7f29235d352db6cfe47a0c065d3eaa81104047d80ab7e3ab351dd6f51c25fc`
- **Failures:** Phase 17 forbidden/no-payload static gates (authorized `stages/` + `staging/` not yet allowlisted)
- **Notes:** SFTP/destination_host/restore_test PASS after preflight; all Phase 19 real suites + Colima reboot matrices PASS

## Run 3 — FAILED (SFTP flake + mid-run script edit)

- **Log:** `/tmp/p19-auth-run-all-FAIL3.log`
- **Failure:** `test_backup_sftp_real.sh` (fixture race); later `suites: command not found` after `run_all.sh` edited while running
- **Notes:** Isolation re-run of SFTP PASS; security allowlists already fixed

## Run 4 — PASS (authoritative)

- **Log:** `/tmp/p19-auth-run-all-CLEAN.log`
- **SHA256:** `eb7f29235d352db6cfe47a0c065d3eaa81104047d80ab7e3ab351dd6f51c25fc`
- **Result:** `run_all: PASS`
- **Exit code:** `0`
- **OK:** 73 / **FAIL:** 0
