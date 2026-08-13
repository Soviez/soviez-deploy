# COMMERCIAL_MODEL.md

## Provider neutrality

Migration Token capability key: **`migration_token`** (catalog / `CAPABILITY_MIGRATION_TOKEN`).

May originate from: Stripe purchase (`ip-migration-token` addon), other gateways, manual/admin grant, complimentary grant, offline signed entitlement, migration bundle, future providers.

**Stripe is never source of truth.** Entitlement resolver + commercial ledger grants are the commercial model; live burn today still uses wallet RPCs — Phase 20 must cut over burn to ledger+grant consumption (or dual-write with grant `quantity_consumed` authoritative for eligibility after cutover).

## Entitlement fields to track

| Field | Notes |
|-------|-------|
| capability / entitlement key | `migration_token` |
| quantity / remaining | `quantity - quantity_consumed` on grants; wallet dual-write until cutover complete |
| validity / expiry | grant status + settlement |
| account / License binding | account-scoped consumable; optional `target_license_id` |
| consumption state | available vs exhausted |
| grant source | provider metadata boundary only |
| revocation / dispute / refund | ledger settlement + revoke paths |
| offline/manual | pre-issued signed package; no local token invention |

## Quantity

Exactly **one** token consumed per successful Phase 20 authorization for one License binding transition.
