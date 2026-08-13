# OPERATION_GATING_MATRIX — Phase 10 Stage License

| Operation | Commercially gated | Allowed without entitlement |
|-----------|-------------------|----------------------------|
| `stage_create` | Yes | No |
| `stage_clone` | Yes | No |
| `stage_refresh` | Yes | No |
| `stage_rebuild` | Yes | No |
| `stage_list` | No | Yes |
| `stage_status` | No | Yes |
| `stage_stop` | No | Yes |
| `stage_backup` | No | Yes |
| `stage_drop` | No | Yes |

RPC: `stage_license_evaluate_operation(license_id, operation)`
