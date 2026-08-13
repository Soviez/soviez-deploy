# IDEMPOTENCY_MODEL.md

Every irreversible request requires:

- account ID, License ID
- migration-pair ID, source/destination environment IDs
- Phase 19 readiness / transfer-manifest / staging IDs
- token entitlement/grant ID
- operation ID, idempotency key, request hash
- source + destination fingerprints

## Rules

| Case | Behavior |
|------|----------|
| same key + same request hash | same signed result |
| same key + different hash | fail closed (`MIGRATION_TOKEN_IDEMPOTENCY_CONFLICT`) |
| retry after timeout | return committed result; **no second consume** |
| wrong device/pair/account | deny |
| stale readiness | deny |
| expired authorization | deny |

## Retention (recommended default for OD)

Retain idempotency records for **License lifetime** (or permanent). Slot machine pattern (`license_slot_operation_idempotency`) is the template.
