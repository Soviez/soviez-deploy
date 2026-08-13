# Stage License Protocol (Phase 10)

**Migration:** `soviez-saas/supabase/migrations/085_stage_license_monthly.sql`  
**Library:** `soviez-saas/src/lib/stage-license/`  
**Model:** `docs/ai/STAGE_LICENSE_COMMERCIAL_MODEL.md`

---

## Schema (085)

### Tables

| Table | Purpose |
|-------|---------|
| `stage_license_settings` | Singleton policy: product_enabled, billing_interval, calculation_version |
| `stage_license_entitlements` | Exact-license Stage entitlement rows |
| `stage_license_events` | Audit trail: activated, past_due, revoked, refunded, superseded |
| `stage_license_quotes` | Server-priced, short-lived monthly quotes |

### Purchase columns (additive)

| Column | Type | Notes |
|--------|------|-------|
| `stage_license_quote_id` | UUID | FK to quote used at checkout |

### RPCs

| Function | Access | Purpose |
|----------|--------|---------|
| `stage_license_resolve(license_id, as_of?)` | authenticated, service_role | Provider-neutral coverage JSONB |
| `stage_license_evaluate_operation(license_id, operation, as_of?)` | authenticated, service_role | Gated vs local operation decision |
| `stage_license_upsert_entitlement(...)` | **service_role only** | Idempotent upsert + supersession |
| `stage_license_mark_status(idempotency_key, status, event_type, ...)` | **service_role only** | Status transitions + event |

---

## API contracts

### POST `/api/stage-license/quote`

**Auth:** authenticated customer  
**Body:** `{ licenseId, countryCode? }`  
**Response:** quoteId, monthlyPriceCents, currency, expiresAt, runtimeNote

### GET `/api/stage-license/coverage?licenseId=`

**Auth:** authenticated customer (must own license)  
**Response:** status, newStageCreation, commercialLimit, notes (exact license, unlimited, existing stages, runtime)

### POST `/api/checkout/stage-license`

**Auth:** authenticated customer  
**Body:** `{ licenseId, quoteId?, countryCode?, idempotencyKey }`  
**Rate limit:** `checkout-stage-license`  
**Response:** Stripe Checkout URL (subscription mode, monthly)

### GET/POST `/api/admin/stage-license`

**Auth:** admin session  
**GET:** entitlements list + settings  
**POST grant:** `{ accountId, licenseId, source, reason, months?, idempotencyKey }`  
**POST revoke:** `{ action: "revoke", idempotencyKey, reason }`

### POST `/api/installer/entitlements/stage/check`

**Auth:** Device PoP (no browser login)  
**Body:** `{ license_id, operation, account_id? }` — account_id from body never overrides Device account  
**Response:** allowed, denial_code, commercially_gated, existing_stages_unaffected

---

## Library modules

| Module | Role |
|--------|------|
| `codes.ts` | Slugs, denial codes, GATED/LOCAL operations — **client-safe** |
| `quote.ts` | Server quote creation |
| `entitlement.ts` | Coverage read, upsert, mark status |
| `checkout.ts` | Stripe subscription checkout + fulfill |
| `admin-grant.ts` | Admin/offline grant + revoke |
| `index.ts` | Server-only barrel |

**Client components must import `@/lib/stage-license/codes` only.**

---

## Refund / dispute hooks

- Full refund → `markStageEntitlementStatus` → `refunded`
- Partial refund → `requires_admin_review`
- Stripe subscription pipeline fulfill branch for Stage slug
- `user_addons` expiry mirror on refund pipeline

---

## RLS

- `anon`: no access to stage license tables
- `authenticated`: SELECT own rows (account_id = auth.uid())
- `service_role`: full access

---

## Certification harness

`src/lib/stage-license/e2e/harness.ts` — Docker Postgres, migrations 078–085.

Run: `npm run test:phase10-db`

---

## Phase 10.5 additive note

Stage License entitlement remains the commercial gate. Phase 10.5 adds **Stage Operation Tickets** (`soviez.stage-operation.v1`, migration `086`, APIs under `/api/installer/stage/operations/`) so gated ops also require a short-lived bound ticket + approved tooling digest.

- Ticket expiry gates **START** only — does not stop existing Stages.
- Stage License expiry still does not stop/delete Stages.
- Protocol: `docs/dev/STAGE_OPERATION_TICKET_PROTOCOL.md`
- Model: `docs/ai/STAGE_OPERATION_AUTHORIZATION_MODEL.md`
- Installer `--stage` wiring: **Phase 11 PASS** — see `docs/dev/STAGE_RUNTIME_PROTOCOL.md`.
