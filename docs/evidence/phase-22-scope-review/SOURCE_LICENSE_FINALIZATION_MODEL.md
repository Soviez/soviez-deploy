# Source License Finalization Model

## Transition

From `migration_origin_grace` / `rollback_origin` → recommended final state:

```text
migrated_source_archived
```

## Properties

- No Production traffic ownership
- No business writes / updates / Stage creation / clone / second migration / rebind
- No permanent slot / new activation / customer-facing use
- Backup/status/archive/recovery **metadata** available
- Exact License history retained
- Destination remains permanent Production binding
- No second License / second slot

## License Guard after archive (recommended)

| Capability | Policy |
|------------|--------|
| Internal archive diagnostics | Allow |
| Isolated restore verification | Allow (non-Production) |
| Normal ERP login | Deny |
| Migrated-source status UI | Show |
| Controlled support recovery | Permit with audit |
| Offline usability as Production | Deny |

Do **not** deactivate in a way that destroys recovery access.

## One-License / one-slot preservation

```text
migration_token_consumed_count=1
permanent_production_slot_count=1
traffic_owner=destination
```
