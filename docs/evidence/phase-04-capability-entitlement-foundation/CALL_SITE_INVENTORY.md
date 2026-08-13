# Call-site inventory — Phase 4 discovery

Recorded 2026-07-30. Authorization SoT remains legacy until a later cutover phase.

## Support RPC callers

| Symbol | Sites |
|--------|-------|
| `has_active_support_subscription` | `support-subscription.server.ts`, dashboard support-subscription/tickets APIs, Nancy ecosystem context, DB ticket insert trigger (048) |
| `has_active_support_subscription_for_ip` | `support-subscription.server.ts`, `support-ticket-create.ts`, Nancy create ticket, support-tickets POST |

## Slug / interval

- Auth SQL ignores `billing_interval`; monthly vs annual differ by slug + stored `current_period_end`.
- TS slugs: `technical-support-monthly`, `technical-support-annual`.
- Legacy SQL also accepts `technical-support-subscription`.

## Slots

- Auth: `get_available_license_slots` / `generate_secure_license_1to1`.
- Dashboard + license generate route.
- Commercial shadow only: `get_neutral_available_license_slots`.

## Migration tokens

- Wallet: `profiles.ip_migration_credits`, `licenses.ip_migration_credits`.
- Burn: `begin_license_migration` / cancel / migrate (070).
- Commercial `migration_token` grants are shadow dual-write.

## Phase 3 integration

- Entitlement foundation must resolve from `commercial_grants` (+ catalog/mappings), not Stripe IDs.
- Do not cut over support ticket RPCs, slot mint, or migration burn in Phase 4.
