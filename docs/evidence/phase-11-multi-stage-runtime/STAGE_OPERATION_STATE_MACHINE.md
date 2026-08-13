# STAGE_OPERATION_STATE_MACHINE — Phase 11

Canonical list: `SOVIEZ_STAGE_STATES` in `src/stage/state_machine.sh`.

Happy path: `created` → `preflight` → `production_selected` → `identity_reserved` → `resource_admission` → (`waiting_for_connection_consent` →) `device_authorized` → `entitlement_checked` → `operation_authorized` → `tooling_authorized` → `tooling_pulled` → `ticket_verified` → `snapshot_preparing` → `database_snapshot_created` → `filestore_snapshot_created` → `database_restoring` → `filestore_restoring` → `stage_runtime_created` → `neutralization_running` → `neutralization_validated` → `authorization_consumed` → `domain_pending` → `ssl_pending` → `runtime_validating` → `origin_certificate_issued` → `remote_completion_pending` → `completed`.

Any state may transition to `failed_retryable` | `failed_terminal` | `canceled` | `recovery_required`.

Unit coverage: `test_stage_unit.sh` asserts legal/illegal transitions.
