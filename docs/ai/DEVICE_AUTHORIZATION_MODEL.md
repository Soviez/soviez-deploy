# Device Authorization Model

**Status:** Implemented (Phase 5) — **wired in Phase 8 `--new`**.  
**Does not grant commercial entitlement.**  
**Repos:** `soviez-saas` migration `081`, `src/lib/device-auth/*`, `/installer/authorize`, `/dashboard/devices`.

---

## Purpose

Enable a customer to authorize a specific server public key to their Soviez account via a browser-assisted device grant, without typing the portal password into a terminal, without embedding SaaS secrets in the installer, and without continuous phone-home.

## Non-goals (this phase)

- License Slot reservation / entitlement decisions
- Private-registry pull sessions
- ~~Automatic activation / installer runtime wiring~~ → **wired Phase 8 `--new`**
- Annual multi-year checkout / Stage License product
- Changing `local_license_guard`, Docker publishing, or migrations against live Supabase

## Sovereignty boundaries

1. No periodic phone-home.
2. No hidden telemetry.
3. Device authorization starts only after an explicit user/device-link request.
4. Revoking a CLI device revokes **future connected operations only** — it does not stop Production or Stage.
5. SaaS unavailability must not affect existing ERP runtime.
6. Offline workflows remain first-class.

**Device authorization proves only:** this server key was approved by this account for future authenticated connected requests.

It does **not** imply License ownership, slots, updates, Stages, Migration Tokens, or annual support.

## Data-egress contract (`device-egress/v1`)

Explicit application metadata for **start** only:

- Ed25519 public key (raw, base64url)
- Public-key fingerprint
- Optional sanitized device label
- Protocol version
- Request nonce

Standard HTTPS infrastructure metadata (e.g. source IP) may be visible — not application telemetry.

Never transmitted: ERP/business data, dumps, filestore, passwords, activation keys, private key, hostname/inventory by default.

## Schema

| Table | Role |
|-------|------|
| `cli_devices` | Account-bound registered public keys (`active|revoked|replaced|compromised|disabled`) |
| `device_auth_sessions` | Short-lived device grant (`pending|approved|denied|expired|consumed`); codes **hashed** |
| `device_credentials` | Opaque renewables; **hashed**; bound to device; revocable; TTL |
| `device_request_nonces` | Cryptographic nonces with TTL; distinct from commercial idempotency keys |

RLS: anon denied; authenticated may SELECT own devices only; all writes go through service-role APIs.

## Cryptographic model

- **Algorithm:** Ed25519 (dedicated Device Authorization domain `soviez.device-auth.v1`)
- **Not reused:** ERP license signing keys, Migration HMAC, Stripe webhook secrets, entitlement ticket keys
- **Private key:** generated and stored only on the server (planned `/etc/soviez/device/device-private-key`); never sent to SaaS
- **Credential:** opaque random secret hashed at rest + mandatory PoP signature on every authenticated request
- **Copied credential without private key:** fails verification

## Browser authorization flow

1. Device `POST /api/installer-auth/device/start`
2. Terminal shows verification URI + user code + disclosure (future installer)
3. User opens `/installer/authorize` → existing Supabase Auth login
4. Explicit Approve / Deny (no preselect)
5. Device polls `POST /api/installer-auth/device/token` with PoP over `device_code`
6. On success: device registered + credential issued once
7. Manage/revoke at `/dashboard/devices`

## API contracts

| Route | Auth | Purpose |
|-------|------|---------|
| `POST /api/installer-auth/device/start` | Unauthenticated (narrow) | Create pending session |
| `POST /api/installer-auth/device/token` | Device code + PoP | Poll / exchange |
| `GET/POST /api/installer-auth/device/decision` | Session cookie + CSRF | Lookup / approve / deny |
| `GET/DELETE /api/installer-auth/device/devices` | Session cookie (+ CSRF on DELETE) | List / revoke |

Token poll states: `authorization_pending`, `slow_down`, `access_denied`, `expired_token`, `invalid_grant`, success.

## Request-signing canonicalization

Canonical payload (then domain-prefixed):

```
device-auth/v1
METHOD
/canonical/path
unix_timestamp
nonce
sha256(body)
device_id
credential_id
```

Verifier: load public key, verify Ed25519, clock skew ≤ 5 minutes, reject reused nonce, reject revoked/expired credential/device.

## Replay protection

Unique `(device_id, nonce)` with TTL; cleanup via `cleanup_device_auth_ephemera`. Cryptographic nonce ≠ future operation idempotency key.

## Rate limiting

DB-backed sliding windows via existing `api_rate_limits` / `checkSlidingWindowRateLimit` for start, token, lookup, approve/deny, revoke, signature-fail buckets.

**Limitation:** in multi-instance production this is authoritative only insofar as the shared Postgres rate-limit table is used (current project pattern). Documented: do not treat a hypothetical in-memory limiter as sufficient.

## Credential lifecycle

Issue (90-day TTL) → use with PoP → renew/reauth via new device authorization if needed → revoke/compromise/replace → expire via cleanup. Account deletion cascades devices/credentials.

## Offline-mode relationship

Unaffected. Device auth is optional connected foundation. Offline activation and local license verification remain required paths.

## Future installer integration points

- Generate key at `/etc/soviez/device/device-private-key`
- Persist metadata at `/etc/soviez/device/device.json`
- Call start/token; store credential securely; sign future entitlement requests
- **Phase 6 slot APIs** — **wired in Phase 8 `--new`**
- **Phase 7 registry APIs** — **wired in Phase 8 `--new`**
- **Phase 8 `--new`** — device auth is first connected step after consent

## Explicit commercial statement

**Device authorization alone grants no commercial entitlement** — no License Slot consumption, purchase, updates, Stages, or Migration Tokens. Slot reservation (Phase 6) and private image pull (Phase 7) are separate capability checks.
