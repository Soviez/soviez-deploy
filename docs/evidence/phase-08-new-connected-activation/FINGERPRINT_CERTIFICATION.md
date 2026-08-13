# FINGERPRINT_CERTIFICATION — Phase 8

## Objective

Certify fingerprint format alignment between installer and `local_license_guard` **without modifying the guard**.

## Method

`tests/integration/test_guard_license_tools.py` — imports `license_tools.py` read-only with mock Odoo modules.

**Requires:** `SOVIEZ_MIGRATION_SECRET` env var (guard fail-closed import behavior).

## Certification session

```bash
SOVIEZ_MIGRATION_SECRET=test-certification-secret \
  python3 tests/integration/test_guard_license_tools.py
```

**Result:** PASS

```
GUARD_CERT: PASS fingerprint format + store path callable
GUARD_CERT: fingerprint_sample_prefix=aaaaaaaaaaaaaaaa…
GUARD_CERT_NOTE: full Odoo container ORM E2E not run in this environment
```

## Checks performed

| Check | Result |
|-------|--------|
| `build_odoo_fingerprint(hw, uuid)` format `{64-hex}::{uuid}` | PASS |
| `canonicalize_migration_fingerprint` idempotent | PASS |
| `store_license_activation` with invalid key fails closed | PASS |
| No private key material in mock ICP dump | PASS |

## Installer fingerprint module

`src/license/fingerprint.sh` — computes compound fingerprint for slot bind step.

Aligned with guard format: 64 lowercase hex hardware hash + `::` + database UUID.

## Explicit gap

Full Odoo container with real hardware matrix collection **not** run. Import-level certification only.

## Guard modification status

**NONE** — `local_license_guard` source untouched in Phase 8.
