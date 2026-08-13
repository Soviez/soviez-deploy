# Stage Operation Authorization Model (Phase 10.5)

**Status:** PASS (Phase 10.5) — **wired by Phase 11 runtime**  
**Migration:** `086_stage_operation_authorization.sql` (soviez-saas)  
**Signing domain:** `soviez.stage-operation.v1`  
**Protocol:** `stage-operation/v1`  
**Helper:** `soviez-sh/services/stage-operation-helper` (Node TypeScript verifier — **not** Bash-only)  
**Dev protocol:** `docs/dev/STAGE_OPERATION_TICKET_PROTOCOL.md`  
**Tooling:** `docs/dev/STAGE_TOOLING_ARTIFACT.md`  
**Runtime:** `docs/ai/MULTI_STAGE_RUNTIME_MODEL.md`, `docs/dev/STAGE_RUNTIME_PROTOCOL.md`

---

## 1. Purpose

Authorize **gated Stage operations** (`stage_create`, `stage_clone`, `stage_refresh`, `stage_rebuild`) with a short-lived, tightly bound **Stage Operation Ticket**, after Stage License entitlement (Phase 10) and Device Auth (Phase 5) succeed.

Phase 10.5 delivered the ticket/helper foundation. **Phase 11 wires** `--stage` create to obtain, verify (helper), consume, neutralize, and complete using this model.

---

## 2. Separation of signing domains

| Domain | Purpose |
|--------|---------|
| `soviez.device-auth.v1` | Device credential / PoP |
| License / activation materials | ERP license crypto |
| `soviez.release-manifest.v1` | Release catalog signatures |
| `soviez.registry-pull-ticket.v1` | Private image pull |
| Migration HMAC | License migration receipts |
| Stripe webhook signing | Payments |
| **`soviez.stage-operation.v1`** | **Stage Operation Tickets only** |

Keys and env vars for Stage operations are separate (`SOVIEZ_STAGE_OPERATION_*`). The helper ships **public keys only**.

---

## 3. Online API surface

Base: `/api/installer/stage/operations/`

| Method | Path | Role |
|--------|------|------|
| POST | `authorize` | Issue ticket (idempotent) after entitlement + bindings |
| POST | `consume` | Mark ticket consumed (one-use online) |
| POST | `complete` | Record neutralization + origin metadata |
| POST | `status` | Query authorization state |
| POST | `revoke` | Revoke unused authorization |
| POST | `offline/package` | Issue offline authorization package |

Auth: Device PoP. Account from device binding — body `account_id` never overrides.

---

## 4. Ticket bindings

Claims bind all of:

- `license_id`, `device_id`, `device_pubkey_fingerprint`, `host_pubkey_fingerprint`
- `production_fingerprint`, `database_uuid`
- `stage_id`, `stage_domain`
- `release_id` / `release_digest`, `tooling_artifact_id` / `tooling_digest`
- `architecture`, `operation_type` / `operation_id`
- `entitlement_decision_ref`
- Traceability: `delivery_trace_id`, `subject_pseudonym` (license hash — **no** name/email/business data)
- `jti`, `iat`, `exp`, `nonce`, `signer_key_id`

Mismatch → stable denial codes (`TICKET_BINDING_MISMATCH`, `PRODUCTION_FINGERPRINT_MISMATCH`, `DATABASE_UUID_MISMATCH`, `STAGE_DOMAIN_CONFLICT`, `RELEASE_NOT_APPROVED`, `TOOLING_NOT_APPROVED`, `ARCHITECTURE_NOT_SUPPORTED`, `OPERATION_NOT_ALLOWED`, …).

---

## 5. Expiry semantics (critical)

- `exp` / ticket TTL (~15 minutes) gates **START** of the gated operation only.
- Expiry **never** stops an already-running Stage.
- Stage License expiry **never** stops or deletes existing Stages (Phase 10 invariant preserved).
- Stage-origin certificate is **local evidence**, does not phone home, and **survives** entitlement expiry.

---

## 6. Offline authorization

1. Device requests `offline/package` while online (or via admin path as designed).
2. Package type `soviez.stage-offline-auth.v1` carries a signed ticket (or equivalent signed payload).
3. Helper verifies signature + bindings, then records one-use consumption in a **local ledger**.
4. **Residual:** Full Root can rewrite the ledger or replace the helper.

---

## 7. Local helper contract

Phase 11 wired flow:

```
Bash → obtain ticket + private tooling → soviez-stage-helper
     → verify / consume / neutralize / write origin cert
     → Bash does infrastructure only (snapshot, runtime, SSL)
```

Bash cannot produce a certified Stage by flipping a local Boolean.

Honest residual: Root can replace the verifier. Soviez does **not** claim unbreakable DRM.

---

## 8. Neutralization

Before completion, tooling certifies controls including:

- outgoing email / SMS / payment providers / webhooks disabled
- external cron isolated; production URL callbacks blocked
- stage identity marker set; database neutralized flag

Failure → `NEUTRALIZATION_FAILED`. Runtime clone of Production is **not** implemented in 10.5.

---

## 9. Non-goals (this phase)

| Excluded (10.5 scope) | Notes |
|----------------------|-------|
| Installer `--stage` wiring | Deferred then — **done in Phase 11** |
| Stage containers / networks / domains | **Phase 11** |
| `local_license_guard` changes | None |
| Continuous phone-home / kill-switch | Forbidden |
| Unbreakable DRM claims | Forbidden |

---

## 10. Progress weighting

Phase 10.5 weight **4** → PASS **52%**. Phase 11 weight **8** → PASS **60%** (`52+8`).
