# Test Flag Quarantine

Policy: `src/security/test_flag_policy.sh`.

Dangerous families: `ALLOW_*`, `SKIP_*`, `DISABLE_*`, `FAKE_*`, `FIXTURE_*`, `TEST_*`, `STRICT_SIG` opt-out.

`SOVIEZ_MIG_ALLOW_UNSIGNED_OFFLINE_TEST=1` alone is insufficient — requires `soviez_security_test_bypass_allowed`.
