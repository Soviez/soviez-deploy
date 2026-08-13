# OPERATION_ENGINE_PROPOSAL.md

Phase 24 is mostly **verification/hardening**, not a new business workflow engine.

## Prefer
- Local verification commands + CI jobs (stateless)
- Existing Phase 14 operations when a remediation needs durable state

## If remediation ops are required (optional)

| operation_type | States | Notes |
|----------------|--------|-------|
| `security_hardening_scan` | queued→running→completed/failed | Local scan |
| `security_registry_lockdown_check` | queued→running→completed/failed | Ephemeral docker audit |
| `security_key_hygiene_migrate` | queued→running→completed/failed/needs_recovery | Exact-target secret rewrite per OD |

Rules: exact-target; idempotent; status/retry/recover; reboot-safe if mutating secrets; **no** duplicate entitlement/update/backup engines.
