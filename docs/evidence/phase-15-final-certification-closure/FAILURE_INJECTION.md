# Failure Injection

| Injection | Outcome |
|-----------|---------|
| Incompatible addon `p15_bad_addon` | `UPDATE_CANDIDATE_UPGRADE_FAILED`; Production digest unchanged |
| Interrupt at `upgrading_candidate` | exit 42 → `UPDATE_RECOVERY_REQUIRED` |
| Colima restart during `switching` / `rollback_running` | `UPDATE_RECOVERY_REQUIRED` |
| Guard bypass env set | `UPDATE_LICENSE_VALIDATION_FAILED` |
| Image still referenced | skip delete; remain protected |

PASS — fail-closed behaviors confirmed in final cert + unit paths.
