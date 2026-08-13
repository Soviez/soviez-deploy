# License Slot Reservation Protocol

**Version:** `slot-reservation/v1`  
**Auth:** Phase 5 device signed requests (headers)

## Headers (all mutating installer routes)

- `X-Soviez-Device-Id`
- `X-Soviez-Credential-Id`
- `X-Soviez-Credential`
- `X-Soviez-Timestamp`
- `X-Soviez-Nonce`
- `X-Soviez-Signature` (Ed25519 over `soviez.device-auth.v1` + canonical request including body hash)

## Routes

| Method | Path |
|--------|------|
| POST | `/api/installer/slots/reserve` |
| POST | `/api/installer/slots/status` |
| POST | `/api/installer/slots/release` |
| POST | `/api/installer/slots/instance-provisioned` |
| POST | `/api/installer/slots/activation-method` |
| POST | `/api/installer/slots/bind-fingerprint` |
| POST | `/api/installer/slots/issue-license` |
| POST | `/api/installer/slots/activation-ack` |
| GET | `/api/installer/slots/list` (browser session, sanitized) |

### reserve body

```json
{
  "operation_id": "op-...",
  "idempotency_key": "idem-...",
  "protocol_version": "slot-reservation/v1",
  "activation_method": "automatic|manual|undecided"
}
```

### Denial codes

`NO_LICENSE_SLOT`, `INSUFFICIENT_QUANTITY`, `RESERVATION_NOT_FOUND`, `RESERVATION_EXPIRED`, `RESERVATION_RELEASED`, `INVALID_STATE_TRANSITION`, `IDEMPOTENCY_CONFLICT`, `WRONG_DEVICE`, `WRONG_ACCOUNT`, `FINGERPRINT_REQUIRED`, `INVALID_FINGERPRINT`, `FINGERPRINT_CONFLICT`, `LICENSE_ALREADY_ISSUED`, `LICENSE_ISSUANCE_FAILED`, `ACTIVATION_ACK_MISMATCH`, `COMMERCIAL_GRANT_INVALID`, `DEVICE_REVOKED`, `RECOVERY_REQUIRED`, `UNAUTHORIZED`, `INVALID_REQUEST`

### issue-license key reveal

Returns `activation_key` under policy `recovery_same_device_before_activation_ack`. Never log. Retries with same idempotency (or re-issue while key_issued/activation_pending) reuse same License row.

## Schema

- `license_slot_reservations`
- `license_slot_reservation_events` (immutable)
- `license_slot_operation_idempotency`

RPCs: `reserve_license_slot`, `generate_secure_license_for_purchase`, `cleanup_expired_license_slot_reservations`, `revoke_open_reservations_for_purchase`, `get_reservable_license_slots`, `append_license_slot_reservation_event`

## Concurrency

`pg_advisory_xact_lock(hashtext('license_slot_reserve:'||account_id))` + `FOR UPDATE` on purchase/grant selection. Holds exclude free qty via `get_reservable_license_slots`.

## Cleanup

Only `status=reserved AND expires_at <= now()` → `expired`. Bounded batch. Never expires key_issued/activation_pending.

---

## Phase 8 installer wiring

`soviez.sh --new` calls slot APIs in order:

| Installer step | Route | State after |
|----------------|-------|-------------|
| Reserve | `POST /reserve` | `slot_reserved` |
| Instance provisioned | `POST /instance-provisioned` | `instance_provisioned` |
| Activation method | `POST /activation-method` | `waiting_for_activation_method` |
| Bind fingerprint | `POST /bind-fingerprint` | `fingerprint_bound` |
| Issue license | `POST /issue-license` | `license_issued` |
| Activation ack (auto only) | `POST /activation-ack` | after `activated` |

Client: `src/api/slots_client.sh`  
Orchestration: `src/commands/new.sh`  
Protocol: `docs/dev/NEW_COMMAND_PROTOCOL.md`
