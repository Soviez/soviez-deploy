# Update Cutover and Rollback Protocol

## Pre-switch
Revalidate target digest, candidate health, rollback set, locks, confirm flag.

## Switch
Preserve previous digest; retarget exact Production only; measure downtime_ms; do not delete old runtime immediately.

## Rollback
Restore previous digest + recovery-set DB/filestore into exact recorded Production paths; cleanup candidate; Phase 14 recovery contract.

## Post-switch write boundary
After business writes on switched Production, rollback restores pre-switch snapshot only (not lossless catch-up). Documented honestly.

## Safety window
Default 24h. Manual cleanup with `--confirm`; never auto-delete sole rollback set immediately.

## Reboot during cutover
If the host/VM restarts during `switching` or `rollback_running`, reconcile yields `UPDATE_RECOVERY_REQUIRED` — do not blind-replay irreversible steps.

## Image retention after switch
Current + previous digests retained for the safety window. Post-window exact cleanup is `update_image_cleanup` (never broad prune). See `SOVIEZ_IMAGE_RETENTION_AND_CLEANUP_PROTOCOL.md`.
