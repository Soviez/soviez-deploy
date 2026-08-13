# SLOT_RESERVATION_INTEGRATION — Phase 8

**Client:** `src/api/slots_client.sh`  
**Protocol:** `docs/dev/LICENSE_SLOT_RESERVATION_PROTOCOL.md`

## API call sequence in `--new`

| Order | Installer function | Route | Operation state after |
|-------|-------------------|-------|----------------------|
| 1 | `soviez_slots_reserve` | `POST /api/installer/slots/reserve` | `slot_reserved` |
| 2 | `soviez_slots_instance_provisioned` | `POST .../instance-provisioned` | `instance_provisioned` |
| 3 | `soviez_slots_activation_method` | `POST .../activation-method` | (during `waiting_for_activation_method`) |
| 4 | `soviez_slots_bind_fingerprint` | `POST .../bind-fingerprint` | `fingerprint_bound` |
| 5 | `soviez_slots_issue_license` | `POST .../issue-license` | `license_issued` |
| 6 | `soviez_license_send_activation_ack` | `POST .../activation-ack` | after `activated` (auto only) |

## Idempotency

Each call carries `operation_id` + idempotency key derived from operation context.

Resume re-invokes only steps not yet completed per `soviez_sm_should_run_step`.

## Activation key handling

- Received from `issue-license` response
- Stored via `soviez_tenant_secret_write "activation_key"` (mode 600)
- Never written to `events.jsonl` (certified in integration tests)

## Test matrix

| Scenario | Test | Result |
|----------|------|--------|
| Full auto chain | `test_new_automatic_path.sh` | PASS — ack sent |
| Manual chain (no ack) | `test_new_manual_path.sh` | PASS — ends `completed_activation_pending` |
| Resume mid-chain | `test_disconnect_resume.sh` | PASS |
| Key not in events | `test_new_automatic_path.sh` assert | PASS |

## Phase 6 regression

Phase 6 SaaS tests unchanged; installer consumes existing APIs without schema changes.
