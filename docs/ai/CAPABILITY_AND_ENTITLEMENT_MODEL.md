# Capability and entitlement model (Phase 4)

## Separation of concerns

| Layer | Question |
|-------|----------|
| Phase 3 commercial grants | What valid commercial transaction/grant exists? |
| Phase 4 capabilities | What capability, quantity, target, and validity does that grant confer? |

Entitlement code must not query Stripe objects or branch on provider names.

## Capability catalog (`commercial_capabilities`)

Stable codes (seeded, not auto-granted):

| Code | Scope | Value | Notes |
|------|-------|-------|-------|
| `license_slot` | account | quantity | Shadow; auth still legacy slots RPC; Phase 6 reservation uses grants + purchase holds |

## Phase 6 note

Reservation checks commercial `license_slot` grants when selecting an originating grant, while reservable quantity is `get_available_license_slots − open holds`. Soft-commit updates purchase usage + grant consumption sync. No cutover of portal mint.
| `technical_support` | account | boolean | Compat with legacy support RPCs (no cutover) |
| `product_updates` | license | boolean | Strict; fail closed unbound/monthly |
| `stage_environments` | license | boolean | **Phase 10 PASS** — monthly subscription entitlement |
| `migration_token` | account | quantity | Shadow; burn still legacy |
| `private_image_pull` | operation | boolean | Seed only |
| `automatic_activation` | license | boolean | Seed only |
| `offline_update_bundle` | license | boolean | Seed only |

## Target scopes

`account` | `license` | `commercial_grant` | `device` (future) | `operation` (future)

License-scoped capabilities **require** exact `license_id` belonging to the evaluated account.

## Materialization strategy (hybrid — chosen)

1. **Primary truth:** Phase 3 `commercial_grants` rows (capability_code already present).  
2. **Catalog + mappings:** define semantics and product→capability expansion.  
3. **Mapped expansion:** `materialize_capability_grants_from_commercial()` creates idempotent `product_updates` grants from annual technical_support grants that have `target_license_id`.  
4. **Resolver:** reads grants + catalog; never Stripe.

Why safer: reuses Phase 3 idempotency/reversal; avoids a second parallel entitlement table that can drift; mappings stay admin-configurable without Price IDs.

## Product / grant mapping

| Source | Capabilities |
|--------|--------------|
| `technical-support-monthly` | `technical_support` only |
| `technical-support-annual` | `technical_support`; `product_updates` **iff** exact license bound |
| `technical-support-subscription` (legacy) | `technical_support` only; **fail closed** for updates |
| license purchase / `license_slot` grant | `license_slot` |
| `ip-migration-token` | `migration_token` |

## Resolver contract

SQL: `resolve_capability_entitlement(account, capability, license?, qty?, at?)` → JSONB  
TS: `resolveCapabilityEntitlement` / pure `resolveCapabilityPure`

Output fields: `allowed`, quantities, validity, `decision_reason` / `denial_reason`, `supporting_grant_ids`, `resolver_version=phase4-v1`.

Time: **UTC**, `valid_from` inclusive, `valid_until` **exclusive**.

## Denial reasons

`NO_ENTITLEMENT`, `WRONG_ACCOUNT`, `LICENSE_REQUIRED`, `WRONG_LICENSE`, `EXPIRED`, `NOT_YET_VALID`, `REVOKED`, `REFUNDED`, `REVERSED`, `DISPUTED`, `INSUFFICIENT_QUANTITY`, `UNBOUND_LEGACY_GRANT`, `CAPABILITY_DISABLED`, `INVALID_TARGET_SCOPE`

## Compatibility vs strict

| Mode | Behavior |
|------|----------|
| Legacy support/slots/tokens | Unchanged RPCs remain production authorization |
| Strict resolver | Used for foundation tests + future cutover; not wired to installer or ticket gate |

`past_due`: legacy support RPCs still allow; **strict `product_updates` does not broaden** past_due beyond grant settlement/status windows already on commercial grants.

## Reversals

Refund/dispute/revoke on Phase 3 grants propagate: resolver excludes refunded/disputed/revoked; materialize copies parent status onto mapped product_updates.

Partial refunds: **preserve legacy**; no new allocation rule (D015).

## RLS

- Capabilities: authenticated may SELECT active catalog rows; no writes  
- Mappings: service_role only  
- Resolver RPCs: service_role only  

## Later-phase hooks

Device auth, slot reservation, registry pull, auto-activation, Stage product — consume this catalog/resolver; do not invent parallel entitlement systems.

## Phase 7 — `private_image_pull` (implemented)

| Field | Value |
|-------|-------|
| Code | `private_image_pull` |
| Kind | operation / boolean |
| Resolver | `resolveCapabilityEntitlement(…, "private_image_pull")` |
| Seed | Migration `083` inserts `commercial_capability_mappings` seed — **does not auto-grant** |
| Tests | Explicit `commercial_grants` inserted in certification harness |
| APIs | `/api/installer/registry/*` — all require Device PoP + capability |
| Denial | `CAPABILITY_REQUIRED` when no active grant |

Device authorization alone is insufficient for pull — capability check is separate (same pattern as slot reservation).

## Phase 9 — Annual Support coverage (implemented)

| Field | Value |
|-------|-------|
| Prepaid annual | `technical_support` + `product_updates` (exact license) |
| Legacy monthly | `technical_support` only via legacy RPC; **no** `product_updates` |
| Legacy recurring annual | Both via `user_addons` fallback + materialization |
| Coverage SoT | `support_coverage_periods` (active status); not Stripe subscription state |
| Resolver | `support_resolve_annual_coverage` + `readAnnualCoverageForLicense` |
| Denial codes | `MONTHLY_DOES_NOT_INCLUDE_UPDATES`, `COVERAGE_EXPIRED`, `PARTIAL_REFUND_REQUIRES_REVIEW` |
| Runtime | Expiration does **not** revoke ERP runtime; update gate deferred to `--update` phase |

Prepaid fulfillment syncs commercial ledger via existing `syncCommercialLedgerForPurchase` pattern.
