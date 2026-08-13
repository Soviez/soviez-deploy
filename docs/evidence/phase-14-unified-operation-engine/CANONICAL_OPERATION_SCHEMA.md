# Canonical Operation Schema Reference

**Phase:** 14  
**Verdict:** PASS  
**Schema Version:** `1`  

## 1. Schema Layout

The authoritative JSON schema model mapped strictly by `src/ops/schema.sh` contains the following fields:

```json
{
  "schema_version": 1,
  "engine_version": "0.14.0-phase14",
  "adapter_version": "1",
  "operation_id": "op_uuid_string",
  "operation_type": "stage_create",
  "command": "stage_create",
  "requested_action": "stage_create",
  "environment_id": "stage-target-1",
  "environment_type": null,
  "parent_production_id": null,
  "license_id": null,
  "resource_scope": [],
  "host_identity": "target-host-fqdn",
  "request_source": "local",
  "created_at": "UTC_timestamp",
  "queued_at": null,
  "started_at": null,
  "updated_at": "UTC_timestamp",
  "heartbeat_at": null,
  "completed_at": null,
  "canceled_at": null,
  "failed_at": null,
  "next_retry_at": null,
  "current_state": "created",
  "previous_state": null,
  "state_entered_at": "UTC_timestamp",
  "current_checkpoint": "created",
  "progress_percent": 0,
  "progress_message": null,
  "terminal": false,
  "success": null,
  "controller_pid": null,
  "worker_pid": null,
  "worker_identity": null,
  "systemd_unit": null,
  "systemd_invocation_id": null,
  "worker_started_at": null,
  "worker_generation": 0,
  "lock_ids": [],
  "lock_owner": null,
  "lock_acquired_at": null,
  "lock_lease_until": null,
  "lock_generation": 0,
  "retry_count": 0,
  "retry_policy": "default",
  "retryable": true,
  "last_retry_at": null,
  "cancel_requested": false,
  "cancel_requested_at": null,
  "cancel_requested_by": null,
  "cancel_reason": null,
  "cancellation_boundary": null,
  "cancel_safe": true,
  "rollback_available": false,
  "rollback_state": null,
  "rollback_checkpoint": null,
  "recovery_required": false,
  "recovery_reason": null,
  "recovery_checkpoint": null,
  "failure_code": null,
  "failure_class": null,
  "failure_message_safe": null,
  "failure_step": null,
  "failure_retryable": null,
  "state_path": null,
  "events_path": null,
  "log_path": null,
  "artifact_paths": [],
  "evidence_refs": [],
  "migrated_from_schema": null,
  "migration_timestamp": null,
  "sequence": 0,
  "meta": {}
}
```

## 2. Secrets Erasure Contract

A Python-backed validator inside `src/ops/schema.sh` inspects every JSON record recursively before it is saved to disk. If keys matching regular expressions such as `password`, `token`, `secret`, `private_key`, `activation`, `credential`, or strings matching private key blocks (`BEGIN PRIVATE KEY`) are discovered, the save process is terminated immediately with `OPERATION_STATE_CORRUPT`.
