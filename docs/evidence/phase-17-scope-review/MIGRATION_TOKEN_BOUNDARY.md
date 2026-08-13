# Migration Token Boundary — Phase 17

## States (required distinction)

```text
eligible
reserved_if_supported
consumed
```

## Phase 17 allowed

- Resolve whether a valid `migration_token` capability exists (SaaS entitlement resolver / local cache of last check).  
- Display commercial status to owner.  
- Soft **reserve** **only if** an explicit non-consuming reservation API is approved (OD-07) — default recommendation: **no reserve in Phase 17**.  
- Keep `migration_token_consumed = false` on migration-pair object.

## Phase 17 forbidden

- Burn / mark consumed  
- Irreversible bind  
- Deactivate source  
- Activate destination  
- Charge / create payment  

## SaaS reality (inspected)

| API | Behavior | Phase |
|-----|----------|-------|
| `resolve_capability_entitlement(... migration_token ...)` | Eligibility | 17 may call read-only |
| `begin_license_migration` | **Reserves** token into pending session | Soft reserve — OD-07; prefer Phase 20 |
| `migrate_license_ip` | Completes rebind; uses reserved token | **20** |
| `cancel_license_migration` | Restores reserved token | **20** / abort path later |
| `consume_ip_migration_token` | **Obsolete** vs session lock | Do not wire |

Installer does **not** call these today.

## Exact burn point (Phase 20 — not 17)

**Recommended (pending OD-23):** Migration Token is consumed when Phase 20 cutover completes the approved License hardware migration session (`migrate_license_ip` success after valid deactivation receipt) — **not** at discovery, bootstrap, pairing, readiness, DNS landing, or stream start.

Document for owners: Phase 17 outcome string includes `MIGRATION TOKEN NOT CONSUMED`.

## Codes

`MIGRATION_TOKEN_REQUIRED`, `MIGRATION_TOKEN_INELIGIBLE`, `MIGRATION_TOKEN_NOT_CONSUMED` (informational success/assert).
