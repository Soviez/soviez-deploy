# ATOMICITY_AND_TRANSACTION_MODEL.md

## Authoritative system of record

**Soviez SaaS commercial/licensing ledger** (plus License binding tables under the same commit).

Local runtime verifies signed authorization results; **must not invent commercial truth**.

## Invariants

```text
token_consumed = true
IFF
destination_binding_created = true
AND migration_authorization_committed = true

destination_production_activated = true   # means production_licensed_pre_cutover
ONLY IF signed committed authorization exists

source_protected_migration_state = true   # migration_origin_grace
ONLY IF destination binding commit exists
```

## Distributed reality

If Postgres cannot cover ERP/host state in one DB transaction: **saga** with:

1. **Commit point** on SaaS (authoritative).
2. Local apply states: `authorization_committed_local_apply_pending` → convergent apply.
3. Compensating policy only for exceptional pre-cutover admin reversal (owner OD).

No second token consumption on retry.
