# Generated types audit

## Tables added to `src/types/database.ts`

- `commercial_transactions` — Row/Insert/Update/Relationships
- `commercial_grants` — Row/Insert/Update/Relationships
- `commercial_grant_allocations` — Row/Insert/Update/Relationships
- `commercial_capabilities` — Row/Insert/Update/Relationships
- `commercial_capability_mappings` — Row/Insert/Update/Relationships

## RPCs updated

- `materialize_capability_grants_from_commercial` → structured return type
- `resolve_capability_entitlement` → `Json`
- Existing Phase 3/4 RPCs retained

## `as never` status

| Path | Status |
|------|--------|
| `src/lib/commercial/` | **Zero** `as never` |
| `src/lib/entitlements/` | **Zero** `as never` |

Unrelated legacy `as never` outside Phase 3/4 scope were not modified.
