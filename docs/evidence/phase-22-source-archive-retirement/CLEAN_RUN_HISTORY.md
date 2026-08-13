# CLEAN_RUN_HISTORY

| Attempt | Scope | Result | Notes |
|---------|-------|--------|-------|
| prior | implementation run_all | PASS 87 OK | PARTIAL certification (sim reboot / shallow network / SaaS incomplete) |
| gap G1 | SaaS proofs + typecheck/lint/build | PASS | disposable PG only |
| gap G2 | real Colima reboot matrix | PASS | /tmp/p22_reboot_real.out |
| gap G2 | autostart + persistence | PASS | real reboot |
| gap G3 | S3/SFTP/lost-ack/response-loss | PASS | focused suites |
| final | authoritative aggregate | PASS | AUTH_EXIT=0; run_all 104 OK; SaaS exit 0 |

Log: /tmp/p22_authoritative.out
