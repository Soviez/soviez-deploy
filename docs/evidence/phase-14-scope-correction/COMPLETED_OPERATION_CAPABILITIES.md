# Completed Operation Capabilities (Phases 8 / 11 / 12 / 13)

Source of truth: modular `soviez-sh/src/**` and phase evidence under `docs/evidence/phase-0{8,11,12,13}-*/`.

## Phase 8 — `--new` connected activation

| Capability | Location / evidence |
|------------|---------------------|
| Durable operation directory + `state.json` | `src/operations/engine.sh`, paths under ops root |
| Stable operation ID generation | `soviez_op_generate_id` |
| State machine + asserted transitions | `src/operations/state_machine.sh` |
| Event log with redaction | `soviez_op_append_event` + `soviez_redact_text` |
| Heartbeat file | `soviez_op_heartbeat` |
| Per-operation lock (mkdir) | `soviez_op_acquire_lock` / `release` |
| systemd worker unit render | `src/operations/systemd_unit.sh` |
| `--reattach` resume | `src/commands/reattach.sh`; `DISCONNECT_RESUME_MATRIX.md` |
| Idempotent step resume | `new.sh` guards; disconnect/resume test PASS |
| Failure classes | `failed_retryable`, `failed_terminal`, `recovery_required`, `canceled` |

## Phase 11 — Multi-stage runtime

| Capability | Location / evidence |
|------------|---------------------|
| Stage operation state under `SOVIEZ_STAGE_OPS_DIR` | `src/stage/engine.sh`, `paths.sh` |
| Stage-specific SM | `src/stage/state_machine.sh` |
| Checkpoints (`checkpoint_*` markers) | `src/stage/checkpoint.sh` |
| Durable worker + PID + heartbeat | `soviez_stage_start_durable_worker` |
| systemd enable/start (prod); nohup worker (test) | same |
| `--stage-reattach` | CLI + create resume |
| Disconnect/resume E2E | `test_stage_disconnect_resume_e2e.sh` PASS |
| Reboot recovery E2E | `test_stage_reboot_recovery_e2e.sh` PASS |
| Offline request/import ops | `commands/stage_offline.sh` |

## Phase 12 — Domain/SSL lifecycle

| Capability | Location / evidence |
|------------|---------------------|
| SSL inventory + lifecycle SM | `src/ssl/*` |
| Durable renewal/repair operations | engine + inventory merge |
| Scheduler / backoff / retry | `ssl/monitor.sh`, `backoff.sh` |
| `--ssl-reattach`, `--ssl-try-again`, `--ssl-abort` | `commands/ssl.sh` |
| Exact environment targeting | ownership + inventory |
| Needs Action / recovery | codes + evidence FINAL_REPORT |

## Phase 13 — Stage retention

| Capability | Location / evidence |
|------------|---------------------|
| Retention op ID + deletion lock | `retention_engine.sh`, `retention_inventory.sh` |
| Step checkpoint list `completed_deletion_steps` | engine |
| Scheduler scan | `soviez_retention_scheduler_scan` |
| `--stage-retention-reattach` / `--retry` | `commands/stage_retention.sh` |
| Partial deletion → `recovery_required` | PARTIAL_DELETION_RECOVERY |
| Reboot-style scheduler resume | REBOOT_RECOVERY |
| Tombstones | retention tombstone protocol |

## Shared patterns already present (but not unified)

- Multiple op directory roots (`--new` ops vs Stage ops vs SSL inventory vs retention sidecar)
- Multiple SMs without a shared lifecycle vocabulary layer
- Multiple reattach CLIs without a host-wide registry
- Per-command locks without a published cross-command conflict matrix
- Schedulers (SSL + retention) without a documented coordination/priority contract
