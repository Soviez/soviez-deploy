# DISCONNECT_RESUME_MATRIX — Phase 8

**Commands:** `soviez.sh --reattach <operation-id>`  
**Module:** `src/commands/reattach.sh` + idempotent guards in `src/commands/new.sh`

## Mechanism

1. Operation state persisted in `ops/operations/<id>/state.json`
2. Append-only `events.jsonl` audit trail
3. File lock prevents concurrent workers
4. `soviez_sm_should_run_step` skips completed steps on re-entry

## Certified scenario

`tests/integration/test_disconnect_resume.sh`:

| Step | Action |
|------|--------|
| 1 | Create operation `resume-test-op` |
| 2 | Advance to `device_authorization_pending` |
| 3 | Run `--reattach resume-test-op --activation automatic --domain resume.local` |
| 4 | Assert final state `completed` |

Simulates disconnect after device auth started but before completion.

## Resume matrix

| Interrupted at | Expected resume behavior | Certified |
|----------------|-------------------------|-----------|
| `device_authorization_pending` | Continue auth → full chain | **PASS** |
| `slot_reserved` | Skip reserve, continue pull | Design (idempotent guards) |
| `image_pulled` | Skip pull, continue provision | Design |
| `license_issued` | Skip issue, continue activate | Design |
| `activation_pending` | Retry ORM only | Design |

Only first row explicitly certified in test suite; others follow same idempotent step pattern.

## Lock / stale worker

`soviez_op_acquire_lock` + heartbeat detection in engine (prevents split-brain on resume).

## User documentation

`docs/user/INSTALLATION.md` — `--reattach` usage documented.

## Failure recovery

States `failed_retryable` allow reattach after fixing underlying issue (network, pull failure, etc.).
