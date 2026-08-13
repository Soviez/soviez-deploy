# PHASE_4_ENTITLEMENT_OVERLAP.md

Phase 4 delivered provider-neutral commercial ledger + capability foundation.

**Reuse:** `resolve_capability_entitlement`, `commercial_grants`/`transactions`, `CAPABILITY_MIGRATION_TOKEN`, dual-write on purchase, refund/dispute ledger hooks.

**Conflict:** Burn still on wallet RPCs; grant `quantity_consumed` not updated → shadow entitlement can disagree with wallet.

**Phase 20 must:** make entitlement resolver + grant consumption the authz gate (or dual-write with grant authoritative), without treating Stripe as truth.
