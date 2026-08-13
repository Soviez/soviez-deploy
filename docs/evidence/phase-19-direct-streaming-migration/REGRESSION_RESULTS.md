# REGRESSION_RESULTS.md

Inside authoritative `run_all: PASS`:

- Phase 12 SSL lifecycle / local CA: OK
- Phase 14 ops engine / unified / canonical sync: OK
- Phase 15 update e2e + final certification (deferred Colima): OK
- Phase 16 local backup/restore e2e: OK
- Phase 16 S3 real: OK
- Phase 16 SFTP real: OK
- Phase 16 restore-test real: OK
- Phase 17 pair/mTLS/bootstrap/token non-consumption/destination host: OK
- Phase 17 reboot matrix: OK
- Phase 17 security static gates (allowlist includes Phase 19 stages/staging): OK
- Phase 18 DNS/landing/TLS/routing + isolation + reboot: OK
- Stage retention/live postgres/offline/multi: OK
- Phase 19 full focused set: OK
- Multi-tenant isolation (17/18/19): OK
- Static no-SaaS-relay / no-token-mutation / no-cutover: OK
