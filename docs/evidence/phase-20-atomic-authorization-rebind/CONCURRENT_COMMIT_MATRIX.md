# CONCURRENT_COMMIT_MATRIX

## Design (known)

| Scenario | Expected |
|----------|----------|
| Two commits, same license, different keys | Second fails: active operation conflict |
| Two commits, same idempotency key+hash | Second returns idempotent receipt |
| Commit during eligibility read | Serialized by license lock |

## Certification

**Result:** Pending certification run


## Certification result

**PASS** — recorded in FINAL_REPORT / TEST_RESULTS (2026-08-03). Installer `0.20.0-phase20`, run_all exit 0.
