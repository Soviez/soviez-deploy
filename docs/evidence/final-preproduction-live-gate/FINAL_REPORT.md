# FINAL_REPORT — final-preproduction-live-gate

- captured_utc: 2026-08-16T15:19:08Z
- platform: 0.24.6.1-platform-cli
- artifact_sha256: dc16a4cde22e2e6142706b0e5937237028931ca1c3e352b356a22bfd966e051b

## Summary

| Area | Status |
|---|---|
| Ubuntu 24.04 live | PASS |
| Ubuntu 22.04 Jammy recreate | PASS |
| Fresh CLI install | PASS |
| Bare PATH CLI | FAIL |
| CLI with SOVIEZ_ROOT=/var/soviez | PASS |
| Self-update negatives | PASS |
| Self-update downgrade | PASS |
| Self-update positive apply | BLOCKED |
| Docker/Odoo listeners | BLOCKED |
| Website preview | PARTIAL |
| Full regression | FAIL |

## Verdict

NOT CLEAR FOR PRODUCTION RELEASE until SOVIEZ_ROOT default and chmod -p install bugs are fixed and positive self-update apply is re-proven; ERP listener proofs remain BLOCKED.
