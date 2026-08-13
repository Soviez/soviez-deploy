# Stage License Commercial Model (Phase 10)

**Status:** Implemented — **PASS** (2026-07-30)  
**Implementation repo:** `soviez-saas`  
**Migration:** `085_stage_license_monthly.sql`  
**Developer protocol:** `docs/dev/STAGE_LICENSE_PROTOCOL.md`

---

## Objective

Deliver a **monthly recurring**, **exact-license-bound** Stage Environments entitlement where:

1. **Exact license binding** — every quote, checkout, grant, and entitlement row is tied to one `license_id` owned by the account. No account-level fallback.
2. **Unlimited commercially** — no per-license Stage count cap in the commercial layer; server resource limits are enforced locally in a later phase.
3. **Expiration does not stop existing Stages** — entitlement expiry blocks **new** gated operations only; existing Stage containers/data remain unaffected.
4. **Provider-neutral resolution** — `stage_license_resolve(license_id)` answers entitlement without inspecting Stripe objects at read time.
5. **Gated vs local operations** — create/clone/refresh/rebuild require entitlement; list/status/stop/backup/drop are always allowed locally.

---

## Non-goals (this phase)

| Excluded | Notes |
|----------|-------|
| Installer `soviez.sh --stage` wiring | **Phase 11 PASS** — wired in `soviez-sh` |
| Stage runtime (containers, domain, SSL) | **Phase 11 PASS** (trusted SSL); further DNS/challenge UX may deepen in Phase 12 |
| 60-day Stage retention / Safe Shield | Phase 13 — boundary documented only |
| Live Stripe / Supabase migration apply | Migration `085` certified in isolated Docker only |
| License slot consumption | Stage License does not consume License Slots |

---

## Architecture

```
Customer quote/checkout/grant
        │
        ▼
stage_license_quotes (short-lived, server-priced)
        │
        ▼
purchases (subscription, pricing_snapshot, stage_license_quote_id)
        │
        ▼
stage_license_upsert_entitlement RPC ──► stage_license_entitlements
        │                                      │
        ▼                                      ▼
user_addons mirror (compatibility)     stage_license_events (audit)
        │
        ▼
syncCommercialLedgerForPurchase ──► commercial_grants (stage_environments)
        │
        ▼
stage_license_resolve / stage_license_evaluate_operation (provider-neutral read)
```

**Capability:** `stage_environments` via addon slug `stage-license-monthly` and grant type `stage_license`.

---

## Operation gating

| Operation | Commercially gated |
|-----------|-------------------|
| `stage_create`, `stage_clone`, `stage_refresh`, `stage_rebuild` | Yes |
| `stage_list`, `stage_status`, `stage_stop`, `stage_backup`, `stage_drop` | No |

Device PoP check: `POST /api/installer/entitlements/stage/check`

---

## One-active supersession

At most one open entitlement per license (`pending`, `active`, `past_due`, `canceled`, `requires_admin_review`). New upserts supersede prior open rows to `expired`.

---

## Denial codes (stable)

`LICENSE_REQUIRED`, `STAGE_LICENSE_DISABLED`, `STAGE_LICENSE_NOT_FOUND`, `STAGE_LICENSE_PAST_DUE`, `STAGE_LICENSE_EXPIRED`, `STAGE_OPERATION_NOT_ALLOWED`, `PARTIAL_REFUND_REQUIRES_REVIEW`, `DEVICE_AUTH_REQUIRED`, etc. — see `src/lib/stage-license/codes.ts`.

---

## Test certification

| Suite | Result |
|-------|--------|
| `npm run test:phase10` | Unit + route contracts |
| `npm run test:phase10-db` | Docker Postgres certification |

Evidence: `docs/evidence/phase-10-stage-license/FINAL_REPORT.md`

---

## Phase 10.5 — commercial hardening (additive)

Phase 10 remains the **entitlement** layer. Phase 10.5 adds **operation authorization**:

| Layer | Mechanism |
|-------|-----------|
| Entitlement | Stage License (`085`, `stage_license_resolve`) |
| Operation ticket | `soviez.stage-operation.v1` (`086`, separate signing domain) |
| Local verifier | `soviez-sh/services/stage-operation-helper` (Node TS) |
| Tooling | Digest-pinned `signed_package` via private registry |

Ticket expiry gates **START** only. Expired Stage License still does **not** stop/delete Stages. Not DRM; Full Root residual documented.

See `STAGE_OPERATION_AUTHORIZATION_MODEL.md`, `STAGE_COMMERCIAL_ENFORCEMENT_THREAT_MODEL.md`.

---

## Phase 11 — multi-stage runtime (additive)

Phase 10 entitlement + Phase 10.5 tickets are consumed by installer `--stage`:

| Topic | Rule |
|-------|------|
| Multiple Stages | Allowed per exact License |
| Commercial count | Unlimited |
| Local limit | Resource admission |
| Core Slot | Not consumed |
| Networks | Dedicated `soviez-net-stage-<id>` |
| Expiry | Deny gated create; keep local lifecycle |

Docs: `MULTI_STAGE_RUNTIME_MODEL.md`, evidence `phase-11-multi-stage-runtime/`.  
**Next:** Phase 12 unauthorized until owner approval.
