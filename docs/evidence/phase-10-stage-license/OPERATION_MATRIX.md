# OPERATION_MATRIX — Phase 10

| Operation | Commercially gated? | Active entitlement | Inactive |
|-----------|---------------------|--------------------|----------|
| `stage_create` | Yes | Allowed | Denied |
| `stage_clone` | Yes | Allowed | Denied |
| `stage_refresh` | Yes | Allowed | Denied |
| `stage_rebuild` | Yes | Allowed | Denied |
| `stage_list` | No | Allowed | Allowed |
| `stage_status` | No | Allowed | Allowed |
| `stage_stop` | No | Allowed | Allowed |
| `stage_backup` | No | Allowed | Allowed |
| `stage_drop` | No | Allowed | Allowed |

Entitlement expiry never emits stop/delete signals for existing Stages.
RPC: `stage_license_evaluate_operation` — DB cert PASS.
