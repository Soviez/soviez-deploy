# IMPLEMENTATION_DECOMPOSITION.md

Proposed modules (future implementation — not created now):

```text
src/security/
  policy.sh          # STRICT_SIG / TEST_MODE gates
  secret_scan.sh     # local scanner wrapper
  registry_lockdown.sh
  key_hygiene.sh     # per OD
  readiness.sh       # PASS/WARNING/BLOCKED optional
  codes.sh

tests/security/
  test_phase24_unsigned_self_update_absent.sh
  test_phase24_signed_update_enforcement.sh
  test_phase24_ticket_replay_matrix.sh
  test_phase24_registry_lockdown.sh
  test_phase24_secret_scan.sh
  test_phase24_no_service_role_credentials.sh
  test_phase24_sovereignty_regression.sh

.github/workflows/
  secret-scan.yml    # or equivalent
  security.yml
```

Wire into `tests/run_all.sh` and optional `tests/phase24_authoritative_certification.sh` patterned after Phase 23 ephemeral lifecycle.

**Do not** put Phase 24 logic inside a second update/backup/migration engine.
