# Stage Operation Ticket Protocol (Phase 10.5)

**Protocol version:** `stage-operation/v1`  
**Ticket type / signing domain:** `soviez.stage-operation.v1`  
**SaaS library:** `soviez-saas/src/lib/stage-operation/`  
**Migration:** `086_stage_operation_authorization.sql`  
**Local helper:** `soviez-sh/services/stage-operation-helper`  
**Model:** `docs/ai/STAGE_OPERATION_AUTHORIZATION_MODEL.md`

No private keys in this document.

---

## 1. Crypto

- Algorithm: Ed25519.
- Signed message: `soviez.stage-operation.v1\n` + canonical JSON claims.
- Token form: `base64url(canonicalJson).base64url(signature)`.
- Verifier uses public keys by `signer_key_id` only.

Env (SaaS signing side):

- `SOVIEZ_STAGE_OPERATION_PRIVATE_KEY`
- `SOVIEZ_STAGE_OPERATION_PUBLIC_KEYS_JSON`
- `SOVIEZ_STAGE_OPERATION_KEY_ID`

Default TTL: **15 minutes** (`STAGE_OPERATION_TICKET_TTL_SECONDS`). TTL gates START only.

---

## 2. Claims schema

| Field | Role |
|-------|------|
| `typ` | Must be `soviez.stage-operation.v1` |
| `protocol_version` | Must be `stage-operation/v1` |
| `jti` | Unique ticket id |
| `operation_id` | Caller correlation |
| `operation_type` | One of gated ops |
| `subject_pseudonym` | License-derived hash (not PII) |
| `account_id` | Bound account |
| `license_id` | Exact Stage License subject |
| `device_id` | Device row |
| `device_pubkey_fingerprint` | Device key fp |
| `host_pubkey_fingerprint` | Host binding |
| `production_fingerprint` | Production FP |
| `database_uuid` | DB UUID |
| `stage_id` | Stage identity |
| `stage_domain` | Mandatory domain binding |
| `release_id` / `release_digest` | Approved ERP release |
| `tooling_artifact_id` / `tooling_digest` | Approved Stage tooling |
| `architecture` | e.g. `linux/amd64` |
| `entitlement_decision_ref` | Entitlement snapshot ref |
| `delivery_trace_id` | Pseudonymous delivery ID |
| `iat` / `exp` | Issue / expiry unix |
| `nonce` | Freshness |
| `signer_key_id` | Key lookup |

---

## 3. Gated operations

`stage_create` | `stage_clone` | `stage_refresh` | `stage_rebuild`

Local (not ticket-gated commercially): list, status, stop, backup, drop (Phase 10).

---

## 4. HTTP API

All under `/api/installer/stage/operations/`. Device PoP required.

### POST `authorize`

Issue (or return idempotent) authorization + ticket token.  
Checks Stage License entitlement, device/account ownership, and binding fields.

### POST `consume`

Mark issued ticket consumed. Replay → `TICKET_ALREADY_CONSUMED`.

### POST `complete`

Accept neutralization result + write/register Stage-origin certificate metadata.  
Does not phone home from the Stage host beyond this explicit user-initiated complete call (online path).

### POST `status`

Return authorization status for `operation_id` / jti.

### POST `revoke`

Revoke unused authorization → `TICKET_REVOKED`.

### POST `offline/package`

Issue `soviez.stage-offline-auth.v1` package for air-gapped consumption via helper + local ledger.

---

## 5. Local verification (helper)

Package: `@soviez/stage-operation-helper` / CLI `soviez-stage-helper`.

```text
soviez-stage-helper verify --ticket <file> --keys <json> --expect <json> [--ledger <path>]
soviez-stage-helper neutralize --claims <json> --controls <json> [--cert-out <path>]
```

`assertBindings` compares expected local facts to claims. Ledger path enables offline one-use.

---

## 6. Denial codes (stable)

Including: `STAGE_ENTITLEMENT_REQUIRED`, `STAGE_ENTITLEMENT_EXPIRED`, `DEVICE_AUTH_REQUIRED`, `DEVICE_REVOKED`, `LICENSE_REQUIRED`, `WRONG_ACCOUNT`, `WRONG_LICENSE`, `PRODUCTION_FINGERPRINT_REQUIRED`, `PRODUCTION_FINGERPRINT_MISMATCH`, `DATABASE_UUID_MISMATCH`, `STAGE_ID_REQUIRED`, `STAGE_ID_CONFLICT`, `STAGE_DOMAIN_REQUIRED`, `STAGE_DOMAIN_CONFLICT`, `OPERATION_NOT_ALLOWED`, `RELEASE_NOT_APPROVED`, `TOOLING_NOT_APPROVED`, `ARCHITECTURE_NOT_SUPPORTED`, `TICKET_EXPIRED`, `TICKET_REVOKED`, `TICKET_ALREADY_CONSUMED`, `TICKET_SIGNATURE_INVALID`, `TICKET_BINDING_MISMATCH`, `IDEMPOTENCY_CONFLICT`, `OFFLINE_PACKAGE_INVALID`, `OFFLINE_PACKAGE_ALREADY_USED`, `NEUTRALIZATION_FAILED`, `ROOT_TAMPER_RISK_DETECTED`.

---

## 7. Origin certificate

Type: `soviez.stage-origin-certificate.v1`  
Local evidence only. Survives Stage License expiry. No continuous phone-home.  
Retention timestamps may be null until Phase 13.

---

## 8. Replay and idempotency

- Online: consume is one-use; authorize supports idempotency keys (conflict → `IDEMPOTENCY_CONFLICT`).
- Offline: local ledger keyed by ticket/package hash and `(operation_id, stage_id)`.
- Expired ticket cannot START; does not affect running Stages.

---

## 9. Phase boundary

Phase 10.5 delivered tickets/helper without installer wiring.  
**Phase 11 PASS** wires `--stage` to verify/consume/neutralize via this protocol. No `local_license_guard` change. Phase 12 unauthorized.
