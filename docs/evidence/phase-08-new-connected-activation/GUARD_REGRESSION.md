# GUARD_REGRESSION — Phase 8

## Policy

Phase 8 **must not modify** `local_license_guard`. Regression = confirm no guard edits + fingerprint compatibility cert.

## Guard source status

| Path | Modified in Phase 8? |
|------|---------------------|
| `Soviez ERP/addons/local_license_guard/**` | **NO** |

Verified by scope review — no guard files in `CHANGED_FILES.md`.

## Certification method

Read-only import test: `tests/integration/test_guard_license_tools.py`

Does **not** execute Odoo. Proves:
- Fingerprint format compatibility
- `store_license_activation` callable with mock ICP
- Fail-closed on invalid key
- No private key leakage in mock store

## Session result

```bash
SOVIEZ_MIGRATION_SECRET=test-certification-secret \
  python3 tests/integration/test_guard_license_tools.py
```

**Output:**
```
GUARD_CERT: PASS fingerprint format + store path callable
GUARD_CERT: fingerprint_sample_prefix=aaaaaaaaaaaaaaaa…
GUARD_CERT_NOTE: full Odoo container ORM E2E not run in this environment
Exit code: 0
```

## Import without migration secret

Without `SOVIEZ_MIGRATION_SECRET`:
```
FATAL SECURITY VIOLATION: SOVIEZ_MIGRATION_SECRET is missing or empty.
```

Confirms guard fail-closed behavior preserved (not a regression — expected guard behavior).

## ORM method contract

Installer calls official method only:
```python
env["soviez.license.mixin"].action_activate_soviez_license(key)
```

No direct ICP manipulation from installer bash (guard internal path used via ORM).

## Verdict

| Check | Result |
|-------|--------|
| Guard unmodified | **PASS** |
| Fingerprint format cert | **PASS** |
| Full Odoo ORM E2E | **NOT RUN** (documented gap) |
