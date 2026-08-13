# Payment and grant abstraction (developer)

## Phase 3–4 status: **PASS** (consolidated hardening)

Authoritative SaaS doc: `soviez-saas/docs/COMMERCIAL_LEDGER_PHASE3.md`  
Capability model: `docs/ai/CAPABILITY_AND_ENTITLEMENT_MODEL.md`  
Closure evidence: `docs/evidence/phase-03-04-consolidated-hardening/`

## Phase 9 — Annual Support prepaid grants

Prepaid Annual Support extends the grant abstraction:

| Path | Provider | Settlement |
|------|----------|------------|
| Stripe prepaid checkout | `stripe` | Real Checkout session; `mode=payment` |
| Admin grant | `admin_grant` / `manual_offline` / `complimentary` | No Stripe payment; synthetic session ID |
| Coverage extension | RPC `support_extend_annual_coverage` | Idempotent; advisory lock per license |
| Refund full | Reverse coverage + expire user_addons | Existing refund pipeline |
| Refund partial | `requires_admin_review` | No auto proration (D015) |

Protocol: `docs/dev/ANNUAL_SUPPORT_PROTOCOL.md`

## Phase 10 — Stage License subscription grants

Stage License extends the grant abstraction for monthly recurring entitlement:

| Path | Provider | Settlement |
|------|----------|------------|
| Stripe subscription checkout | `stripe` | Checkout `mode=subscription`, monthly |
| Admin grant | `admin_grant` / `manual_offline` / `complimentary` | No Stripe payment; synthetic session ID |
| Entitlement upsert | RPC `stage_license_upsert_entitlement` | Idempotent; one-active supersession per license |
| Refund full | `markStageEntitlementStatus` → `refunded` | Refund pipeline + user_addons expiry |
| Refund partial | `requires_admin_review` | No auto proration (D015) |

Protocol: `docs/dev/STAGE_LICENSE_PROTOCOL.md`

## Source of truth relationship

| Concern | SoT |
|---------|-----|
| Slot mint authorization | Legacy `purchases` RPCs |
| Commercial origin / grant audit | Phase 3 commercial ledger |
| Capability semantics / strict resolve | Phase 4 catalog + resolver (shadow) |
| Support ticket premium | Legacy support RPCs |

## Tests

```bash
cd soviez-saas && npm run test:commercial-closure && npm run typecheck && npm run lint
```
