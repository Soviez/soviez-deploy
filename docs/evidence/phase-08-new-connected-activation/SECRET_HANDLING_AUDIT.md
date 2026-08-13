# SECRET_HANDLING_AUDIT — Phase 8

## Scope

Audit of activation keys, device credentials, registry pull passwords, and log redaction in Phase 8 installer.

## Activation key

| Vector | Protection | Test |
|--------|------------|------|
| Process argv | Never passed — stdin staging only | Code review + `activate_orm.sh` |
| Shell history | Not in command line | Code review |
| Logs | `soviez_redact_text` | `test_redact.sh`, `test_secret_handling.sh` |
| events.jsonl | Not written | `test_new_automatic_path.sh` assert_not_contains |
| Staging file | mode 0600, deleted after use | Code review |
| Local storage | `soviez_tenant_secret_write` mode 600 | `test_secret_handling.sh` |
| Mock SaaS response | Redacted in test assertions | Integration tests |

## Device private key

| Vector | Protection |
|--------|------------|
| Transmission | Never sent to SaaS |
| Storage | Planned `/etc/soviez/device/` (Phase 5 paths) |
| Logs | Not referenced in Phase 8 log paths |

## Registry pull password

| Vector | Protection | Test |
|--------|------------|------|
| Persistent storage | Temp docker config only | `pull_client.sh` |
| Post-pull cleanup | Config dir deleted | `test_cleanup_boundaries.sh` |
| Logs | Not logged by `soviez_log_*` with credentials | Code review |

## Redaction module

`src/core/redact.sh` — patterns for activation keys, credentials, tokens.

Unit test: `tests/unit/test_redact.sh` — PASS

## Tenant secrets module

`src/tenant/secrets.sh`:
- Directory permissions enforced
- File mode 600 on write
- Read via secure path only

## Audit result

| Category | Verdict |
|----------|---------|
| Activation key handling | **PASS** (stub-certified) |
| Log redaction | **PASS** |
| Registry temp cred cleanup | **PASS** |
| Device key sovereignty | **PASS** (design + Phase 5 alignment) |

## Residual risk (PARTIAL)

Full Odoo container ORM path not exercised — staging file permissions inside container not runtime-verified against real `docker exec`.
