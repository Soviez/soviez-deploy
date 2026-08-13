# Security Invariants

- S1–S6 certified composition remains mandatory
- Untrusted restore/migration → quarantine before Production
- Update success ≠ containers Up
- Apt: wait-or-fail only
- Secret scan / signed updates / short-lived Registry credentials
- Scanner statuses PASS/REVIEW/FAIL with fail-closed promotion
- Evidence local-only, redacted
