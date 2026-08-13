# Entitlement API contract

## Phase 4 note

Capability catalog + strict resolver now exist (`079`, `src/lib/entitlements/`).  
Public installer **commercial** entitlement HTTP APIs remain **not** implemented.

Internal (service-role / server-only):

- `resolve_capability_entitlement`
- `materialize_capability_grants_from_commercial`
- TS `resolveCapabilityEntitlement` / `resolveCapabilityPure`

See `docs/ai/CAPABILITY_AND_ENTITLEMENT_MODEL.md`.

Denial reasons are structured codes (not free-text contract).

## Phase 5 — Device authorization APIs (implemented)

Auth foundation only — **no commercial entitlement**:

| Method | Path | Caller |
|--------|------|--------|
| POST | `/api/installer-auth/device/start` | Device (unauthenticated, rate-limited) |
| POST | `/api/installer-auth/device/token` | Device + PoP |
| GET/POST | `/api/installer-auth/device/decision` | Browser session (+ CSRF on POST) |
| GET/DELETE | `/api/installer-auth/device/devices` | Browser session (+ CSRF on DELETE) |

Browser: `/installer/authorize`, `/dashboard/devices`.

Protocol: `docs/dev/DEVICE_AUTHORIZATION_PROTOCOL.md` · Model: `docs/ai/DEVICE_AUTHORIZATION_MODEL.md`.

Signed-request verifier: `verifyDeviceSignedRequest` (service-role) for **future** ops.

## Phase 6 — License Slot reservation APIs (implemented)

Installer-facing (Device PoP required): `/api/installer/slots/{reserve,status,release,instance-provisioned,activation-method,bind-fingerprint,issue-license,activation-ack}` plus browser `GET /api/installer/slots/list`.

Soft-commit at `key_issued`. See `LICENSE_SLOT_RESERVATION_PROTOCOL.md`.

## Phase 7 — Private registry APIs (implemented)

Installer-facing (Device PoP + `private_image_pull` capability required):

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/installer/registry/releases/resolve` | Digest + signed release manifest |
| POST | `/api/installer/registry/pull-sessions` | Create pull session + ticket |
| POST | `/api/installer/registry/pull-sessions/refresh` | Refresh credentials |
| POST | `/api/installer/registry/pull-sessions/complete` | Complete session |
| POST | `/api/installer/registry/pull-sessions/revoke` | Revoke session |

Protocol: `PRIVATE_REGISTRY_PROTOCOL.md`. Model: `PRIVATE_REGISTRY_AND_PULL_AUTHORIZATION_MODEL.md`.

No Docker Hub credentials returned. Gateway URL + pull ticket only.

## Phase 9 — Annual Support APIs (implemented)

Customer-facing (authenticated session):

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/support/annual/quote` | Server-priced quote for license + years |
| POST | `/api/checkout/support/annual` | Prepaid Stripe Checkout (`mode=payment`) |
| GET | `/api/support/annual/coverage?licenseId=` | Provider-neutral coverage read |

Admin (admin session):

| Method | Path | Purpose |
|--------|------|---------|
| GET/POST/PATCH | `/api/admin/support/term-discounts` | Discount rules + commercial settings |
| POST | `/api/admin/support/annual-grant` | Offline/admin/complimentary grant |

Protocol: `ANNUAL_SUPPORT_PROTOCOL.md`. Model: `ANNUAL_SUPPORT_MULTI_YEAR_MODEL.md`.

Denial codes are structured (`AnnualSupportError.code`), not free-text contract.

Monthly new sales blocked: `POST /api/checkout/support-subscription` with `interval=month` → 403.

## Phase 10 — Stage License APIs (implemented)

Customer-facing (authenticated session):

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/stage-license/quote` | Server-priced monthly quote for license |
| POST | `/api/checkout/stage-license` | Stripe Checkout subscription (monthly) |
| GET | `/api/stage-license/coverage?licenseId=` | Provider-neutral Stage coverage read |

Admin (admin session):

| Method | Path | Purpose |
|--------|------|---------|
| GET/POST | `/api/admin/stage-license` | List entitlements; grant / revoke |

Installer (device PoP — no browser login):

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/installer/entitlements/stage/check` | Gated vs local operation decision |

Protocol: `STAGE_LICENSE_PROTOCOL.md`. Model: `STAGE_LICENSE_COMMERCIAL_MODEL.md`.

## Planned (later phases — not fully implemented)

- POST /entitlements/install/check
- POST /entitlements/activate/auto
- POST /entitlements/update/check

Auth: device credential + server pubkey binding. Never service-role in client.  
Do not call `has_active_support_subscription*` for update/stage.

## Public API compatibility (Phase 3–6)

No breaking public commercial response contract changes. Device auth + slot reservation routes are additive.
