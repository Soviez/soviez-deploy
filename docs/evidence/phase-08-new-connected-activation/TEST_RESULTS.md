# TEST_RESULTS — Phase 8

**Date:** 2026-07-30  
**Command:** `bash tests/run_all.sh`  
**Host:** darwin 25.5.0

## Summary

| Category | Count | Result |
|----------|-------|--------|
| Unit tests | 6 | **ALL PASS** |
| Integration tests | 5 | **ALL PASS** |
| Guard cert (separate) | 1 | **PASS** |
| **Total installer tests** | **11** | **PASS** |

## Build / static

| Check | Result |
|-------|--------|
| `build/assemble.sh` | PASS → v0.8.0-phase8 |
| `bash -n dist/soviez.sh` | PASS |
| ShellCheck | **UNAVAILABLE** — not claimed PASS |

## Unit tests

| Test | Result |
|------|--------|
| `tests/unit/test_digest.sh` | PASS |
| `tests/unit/test_domain_ssl.sh` | PASS |
| `tests/unit/test_redact.sh` | PASS |
| `tests/unit/test_secret_handling.sh` | PASS |
| `tests/unit/test_signing.sh` | PASS |
| `tests/unit/test_state_machine.sh` | PASS |

## Integration tests

| Test | Result | Notes |
|------|--------|-------|
| `test_cleanup_boundaries.sh` | PASS | No leftover docker config dirs |
| `test_disconnect_resume.sh` | PASS | Resume from `device_authorization_pending` |
| `test_new_automatic_path.sh` | PASS | ORM stub; state `completed`; no key in events |
| `test_new_manual_path.sh` | PASS | State `completed_activation_pending` |
| `test_ssl_local_ca.sh` | PASS | Local CA cert chain |

## Guard certification (auxiliary)

| Test | Result | Notes |
|------|--------|-------|
| `test_guard_license_tools.py` | PASS | Requires `SOVIEZ_MIGRATION_SECRET` env |

## Not executed

| Test | Reason |
|------|--------|
| ShellCheck on `src/` or `dist/` | Binary not installed on host |
| Full Odoo ERP container ORM E2E | No disposable Odoo container in certification env |
| Live soviez-saas API calls | Mock server used |
| Real Docker Hub pull | Test mode stubs |
| Live Supabase migrate | Out of scope |

## Raw run output (abbreviated)

```
Built dist/soviez.sh (version 0.8.0-phase8)
SHA256: 34ab9413ae86d2b66adcdeed0ea16c9e92c4a1485bd8c15528c939c9d06fabb2
==> tests/unit/test_*.sh — all OK
==> tests/integration/test_*.sh — all OK
run_all: PASS
```

## Verdict contribution

All modular installer gates **PASS** except:
1. ShellCheck — unavailable (not failed)
2. Full Odoo ORM E2E — not run (PARTIAL reason)
