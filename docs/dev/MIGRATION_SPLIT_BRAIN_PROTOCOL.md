# Migration Split-Brain Protocol

## Definition

Split-brain: source and destination both serving **public production traffic** for the same license/domain simultaneously.

Phase 20 **forbids** this state before Phase 21 authorization.

## Enforcement

`soviez_migration_split_brain_validate` (`rebind/engine.sh`):

1. Destination `binding.json` must exist.
2. Source `grace.json` must exist.
3. `public_route` must be `false` on destination binding.
4. `production_domain` must be null/empty on destination binding.
5. Injection test hook `SOVIEZ_MIG_P20_INJECT_SPLIT_BRAIN=1` → `MIGRATION_SPLIT_BRAIN_DETECTED`.

## Traffic ownership model

| Side | Traffic | License slot |
|------|---------|--------------|
| Source | **Active** public production | Grace (no slot) |
| Destination | Internal only | Licensed pre-cutover |

Receipt fields: `traffic_owner=source`, `licensed_future_owner=destination`.

## Static gates

`soviez_migration_assert_no_cutover_dns_purge`:

- `SOVIEZ_MIG_ALLOW_CUTOVER=1` → `MIGRATION_CUTOVER_NOT_AUTHORIZED`
- `SOVIEZ_MIG_DNS_CUTOVER=1` → `MIGRATION_CUTOVER_NOT_AUTHORIZED`

## Phase 21 readiness

Readiness report blocks if `public_route=true` or DNS/cutover flags set.

## Expected outcome

Validation returns:

```json
{"status":"active","traffic_owner":"source","licensed_future_owner":"destination","public_destination":false}
```
