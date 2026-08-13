# Update Reboot Matrix

## Method
Persist operations at checkpoints, then **one** Colima VM `stop`/`start` batch; reconcile from disk.

| Checkpoint | After Colima restart |
|------------|----------------------|
| `upgrading_candidate` | Reconcile → recovery/retry contract (`UPDATE_*`) |
| `waiting_for_switch` | Reconcile → `UPDATE_*` |
| `switching` | **`UPDATE_RECOVERY_REQUIRED`** (no blind replay) |
| `rollback_running` | **`UPDATE_RECOVERY_REQUIRED`** |
| `image_cleanup` | Reconcile → `UPDATE_*` |

Also: synthetic interrupt at `upgrading_candidate` exits 42 → reconcile `UPDATE_RECOVERY_REQUIRED`.

## Result
PASS — shared host reboot batch exercised; irreversible checkpoints fail closed.
