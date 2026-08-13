# License Slot state machine

## Existing
AVAILABLE (paid, used=0) → CONSUMED at `generate_secure_license_1to1` (KEY_ISSUED≈ACTIVATED in SaaS).
Soft revoke ≠ release. Admin purge can reset used.

## Planned
AVAILABLE → RESERVED → KEY_ISSUED → ACTIVATED | RELEASED | FAILED.
Concurrency: FOR UPDATE / SKIP LOCKED; idempotency keys.

## Requires owner decision
Commit consumption at KEY_ISSUED vs ACTIVATED.
