# Commercial entitlement model

## Question the system must answer

> Does this account, license, or resource have a valid commercial grant for this capability or quantity?

Not: “Was this paid through Stripe?”

Authoritative Phase 4 doc: `CAPABILITY_AND_ENTITLEMENT_MODEL.md`.

## Existing (legacy authorization — unchanged)

- Support tickets: `has_active_support_subscription*`
- Slots: `get_available_license_slots` / mint RPC
- Migration burn: begin/migrate RPCs

## Phase 6 — Slot reservation (additive)

`license_slot_reservations` holds capacity without early permanent consume. Soft-commit at `key_issued` via exact-purchase mint. See `LICENSE_SLOT_RESERVATION_MODEL.md`.

## Phase 3 — commercial grants

`commercial_transactions` / `commercial_grants` dual-write; shadow slot RPC.

## Phase 4 — capability foundation

- Catalog: `commercial_capabilities`
- Mappings: `commercial_capability_mappings`
- Materialize annual+license → `product_updates`
- Strict resolver: `resolve_capability_entitlement` (service-role)
- Monthly ≠ product_updates; unbound ≠ product_updates; exact-license enforced

## Phase 9 — Annual Support multi-year (implemented)

Prepaid multi-year Annual Technical Support with exact `license_id` binding:

- **New sales:** Annual prepaid only; monthly new checkout blocked (`MONTHLY_NEW_SALES_DISABLED`)
- **Pricing:** admin term discount rules + floor rounding; immutable `pricing_snapshot`
- **Coverage:** `support_coverage_periods` history; extension stacks from `max(valid_until, settlement)`
- **Stripe:** Checkout `mode=payment` (`annual_support_prepaid`), not N-year subscription
- **Legacy:** existing monthly/recurring annual subscriptions preserved; monthly ≠ product_updates
- **Partial refund:** `requires_admin_review` — no automatic proration (D015)
- **Runtime:** expiration does not stop ERP; no installer `--update` wiring this phase

See `ANNUAL_SUPPORT_MULTI_YEAR_MODEL.md`, `docs/dev/ANNUAL_SUPPORT_PROTOCOL.md`.

## Phase 10 — Stage License monthly (implemented)

Monthly Stage Environments entitlement with exact `license_id` binding:

- **Billing:** recurring monthly subscription (`stage-license-monthly`)
- **Commercial limit:** unlimited; server resources limit actual Stage count (later phase)
- **Gated ops:** create, clone, refresh, rebuild require entitlement
- **Local ops:** list, status, stop, backup, drop never blocked by entitlement
- **Expiration:** blocks new gated ops only; existing Stages unaffected
- **One-active supersession** per license via `stage_license_upsert_entitlement`
- **Device check:** `POST /api/installer/entitlements/stage/check` (PoP; no `--stage` wiring)
- **Runtime:** no containers/domain/SSL/retention this phase

See `STAGE_LICENSE_COMMERCIAL_MODEL.md`, `docs/dev/STAGE_LICENSE_PROTOCOL.md`.

## Confirmed product rules

Monthly must not grant product_updates. Annual linked to license_id for updates. Stage linked to license_id. No account-level fallback for license-scoped caps.
