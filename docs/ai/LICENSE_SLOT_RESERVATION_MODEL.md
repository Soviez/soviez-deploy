# License Slot Reservation Model

**Status:** Implemented (Phase 6) — **wired in Phase 8 `--new`**. Soft-commit policy: hold until `key_issued`, then existing purchase/`license_slots_used` increment via exact-purchase mint.

## Objective

Allow `soviez.sh --new` (authorized device) to atomically reserve exactly one License Slot, progress through provisioning/activation methods, bind a stable fingerprint, issue exactly one License, and acknowledge local ERP activation — with concurrency safety, idempotency, and recovery.

## Non-goals

~~Installer orchestration~~ → **Phase 8 wired**; ~~private registry~~ → **Phase 7+8 wired**; full live Odoo ORM E2E (Phase 8 PARTIAL gap); Stage; Annual multi-year; Docker private cutover; live migrate; `local_license_guard` changes.

## Provider neutrality

Selection uses commercial `license_slot` grants (settled/manually_approved) when present, with purchase fallback. Never asks “was it Stripe?”.

## Consumption semantics (compatibility decision)

Owner-confirmed **soft_commit_at_key_issued**:

| State | Capacity |
|-------|----------|
| reserved / instance_provisioned / manual_pending / failed_retryable | **Hold** — counted against reservable qty; does NOT bump `purchases.license_slots_used` |
| key_issued / activation_pending / activated | **Soft-committed** via `generate_secure_license_for_purchase` (+ commercial grant sync) |
| released / expired / revoked (pre-issue) | Hold released; qty restored |

Portal `generate_secure_license_1to1` unchanged for legacy manual path. Reservation path uses additive exact-purchase mint. Manual bridge: portal mint matching `manual_pending`/`instance_provisioned` fingerprint+purchase → claim to `key_issued`.

## State machine

`reserved → instance_provisioned → (manual_pending|) → key_issued → activation_pending → activated`

Also: `reserved→released|expired|revoked`; `instance_provisioned→failed_retryable→instance_provisioned`; terminal: activated/released/expired/failed_terminal/revoked.

Immutable events in `license_slot_reservation_events`.

## TTL

- Pre-provision (`reserved`): **30 minutes** (`SLOT_RESERVATION_TTL_SECONDS`)
- After `instance_provisioned`: do not blind-expire; expiry pushed forward; cleanup only expires `reserved`
- key_issued / activation_pending: never auto-free to another instance

## Concurrency / idempotency

DB advisory lock per account + row locks; unique `(account_id,idempotency_key)` on create; operation ledger for mutations; crypto nonce (Phase 5) independent of business idempotency key.

## Device Authorization

All installer slot APIs require Phase 5 signed PoP. Account derived from device. Slot entitlement checked separately.

## Failure / recovery / commercial reversal

See protocol doc. Prefixed refunds revoke open holds via `revoke_open_reservations_for_purchase`. After key issuance, existing refund/license revoke behavior applies — no phone-home ERP stop.

## ERP runtime

Offline and unaffected by reservation, SaaS outage, or device revoke mid-flight.

## Phase 7 — registry pull (orthogonal)

Pull sessions and private registry authorization do not interact with slot reservation state. Both require Device PoP; pull additionally requires `private_image_pull` capability. Neither stops running ERP if SaaS/registry unavailable.

## Phase 8 — installer wiring

`soviez.sh --new` invokes the full slot API chain: reserve → instance-provisioned → activation-method → bind-fingerprint → issue-license → activation-ack (automatic path). Manual path skips ORM activation and ack timing may differ. See `NEW_INSTANCE_CONNECTED_ACTIVATION_MODEL.md`.
