# Device Authorization Protocol (implementer)

**Protocol version:** `device-auth/v1`  
**Signing domain:** `soviez.device-auth.v1`  
**Disclosure version:** `device-egress/v1`

No real secrets in this document.

---

## 1. Key material

- Algorithm: Ed25519
- Public key wire format: **raw 32-byte public key**, base64url (no PEM on the wire)
- Fingerprint: first 32 hex chars of `SHA-256(raw_public_key)`, grouped `xxxx:xxxx:…`
- Private key never leaves the host

Planned paths (future installer):

- `/etc/soviez/device/device-private-key` (root, mode `600`)
- `/etc/soviez/device/device.json` (public metadata only)

---

## 2. Start

`POST /api/installer-auth/device/start`

```json
{
  "public_key": "<base64url-raw-32>",
  "public_key_fingerprint": "abcd:ef01:...",
  "display_label": "optional ≤64",
  "protocol_version": "device-auth/v1",
  "nonce": "<≥8 chars>"
}
```

Response (example shape):

```json
{
  "device_code": "<64 hex>",
  "user_code": "WXYZ-2345",
  "verification_uri": "https://example/installer/authorize",
  "verification_uri_complete": "https://example/installer/authorize?user_code=WXYZ-2345",
  "expires_in": 900,
  "interval": 5,
  "session_id": "<uuid>"
}
```

Server stores **SHA-256 hashes** of `device_code` and normalized `user_code`.

---

## 3. Browser

1. Open verification URI; Supabase Auth login if needed.
2. `GET /api/installer-auth/device/decision?user_code=XXXX-XXXX`
3. Explicit Approve/Deny via `POST` with `Origin`/`Referer` CSRF check:

```json
{ "action": "approve", "session_id": "<uuid>" }
```

---

## 4. Token poll

`POST /api/installer-auth/device/token`

Proof message (UTF-8), signed with device private key:

```
soviez.device-auth.v1
token-proof
device-auth/v1
<device_code>
<proof_nonce>
```

Request:

```json
{
  "device_code": "<64 hex>",
  "proof_signature": "<base64url ed25519 sig>",
  "proof_nonce": "<nonce>"
}
```

Errors use `error` field: `authorization_pending` | `slow_down` | `access_denied` | `expired_token` | `invalid_grant`.

Success returns `device_id`, `credential_id`, `credential` (once), `expires_at`. Session becomes `consumed`.

---

## 5. Authenticated request signing

Headers (recommended for future ops):

- `X-Soviez-Device-Id`
- `X-Soviez-Credential-Id`
- `X-Soviez-Credential` (opaque secret)
- `X-Soviez-Timestamp` (unix seconds)
- `X-Soviez-Nonce`
- `X-Soviez-Signature` (base64url)

Canonical string:

```
device-auth/v1
\n
METHOD
\n
/path
\n
timestamp
\n
nonce
\n
hex(sha256(body_bytes))
\n
device_id
\n
credential_id
```

Sign: Ed25519 over `soviez.device-auth.v1\n` + canonical.

Clock skew: ±300 seconds. Nonce unique per device for TTL (default 15 minutes).

---

## 6. Revocation

`DELETE /api/installer-auth/device/devices` with `{ "device_id": "..." }` (cookie + CSRF).

Immediate for future signed requests. Does not stop ERP runtime.

---

## 7. Shell Ed25519 note

Node/OpenSSL 3 provide Ed25519 reliably for SaaS verification. Future shell installer may use `openssl`/`libsodium`/`python3` — smallest secure dependency TBD at installer phase; SaaS accepts raw Ed25519 only.

---

## 8. Phase 7 registry signed requests

Registry pull APIs (`/api/installer/registry/*`) use the **same Device PoP verifier** as slot reservation (`requireDeviceSignedRequest`).

Additional requirements beyond signature:

- Active device credential
- `private_image_pull` capability (commercial grant)
- Allowed `operation_type`

Pull ticket signing domain (`soviez.registry-pull-ticket.v1`) is **separate** from device auth domain — tickets are issued by SaaS after capability pass, consumed by gateway.

See `docs/dev/PRIVATE_REGISTRY_PROTOCOL.md`.

---

## 9. Phase 8 `--new` installer wiring

Device authorization is the **first connected SaaS step** after user consent in `soviez.sh --new`:

1. `soviez_device_client_start` → `POST /api/installer-auth/device/start`
2. Browser approve (or test-mode auto credential in mock)
3. `soviez_device_client_authorize` → token poll with PoP
4. Credential stored locally; all subsequent slot/registry calls signed

Implementation: `src/auth/device_client.sh`, `src/commands/new.sh`

Certified: `tests/integration/test_new_automatic_path.sh`, `test_new_manual_path.sh`, `test_disconnect_resume.sh`
