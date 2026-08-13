# Safe Shield Matrix
| Check | Failure result |
|---|---|
| Missing/mismatched identity or origin certificate | `STAGE_IDENTITY_MISMATCH` |
| Production DB/container collision | `STAGE_PRODUCTION_COLLISION` |
| Wrong network, shared/ambiguous resource | `STAGE_RESOURCE_OWNERSHIP_AMBIGUOUS` / `STAGE_SHARED_RESOURCE_DETECTED` |
| Symlink, `..`, or path outside Stage root | Fail closed |
| Active conflicting deletion lock | `STAGE_ACTIVE_OPERATION_CONFLICT` |

Integration and unit tests exercise Production-name, container, and symlink rejection. No failed validation deletes a Stage.
