# FAILURE_INJECTION — Phase 8

## Scope

Documented failure modes and installer behavior. Explicit injection tests limited to test-mode stubs.

## Network / SaaS failures

| Failure | Expected behavior | Certified |
|---------|-------------------|-----------|
| Mock server down at start | Preflight or HTTP error; non-zero exit | Design |
| Drop mid-operation | `--reattach` resumes | **PASS** (`test_disconnect_resume.sh`) |
| Slot TTL expired (pre-provision) | SaaS returns error; op fails | SaaS-side (Phase 6) |

## ORM activation failures

| Failure | Expected behavior | Certified |
|---------|-------------------|-----------|
| Staging file write fail | `soviez_die`; remote cleanup attempted | Code review |
| ORM method raises | State → `failed_retryable`; staging removed | Code review |
| Stub not invoked | Auto test would fail | **PASS** (positive path) |

## Pull failures

| Failure | Expected behavior | Certified |
|---------|-------------------|-----------|
| Digest mismatch | Manifest verify fails before pull | `test_digest.sh` |
| Temp config leak | Zero leftover dirs | **PASS** (`test_cleanup_boundaries.sh`) |

## Secret leakage failures

| Failure | Expected behavior | Certified |
|---------|-------------------|-----------|
| Key in events.jsonl | Test assertion fails | **PASS** (negative assert) |
| Key in redacted log | Test assertion fails | **PASS** (`test_secret_handling.sh`) |

## Guard import failure

| Failure | Expected behavior | Certified |
|---------|-------------------|-----------|
| Missing `SOVIEZ_MIGRATION_SECRET` | Import abort (fail-closed) | Observed |
| With secret set | Fingerprint cert PASS | **PASS** |

## Not injected in certification

- Real Docker daemon failures
- Real PostgreSQL connection failures
- Live Odoo ORM exceptions inside container
- Live SaaS rate limiting / 429 responses

These require owner environment or future hardening phase.

## Retry policy

`failed_retryable` states permit `--reattach` after operator fixes root cause.

`failed_terminal` requires new `--new` operation (new slot reservation).
