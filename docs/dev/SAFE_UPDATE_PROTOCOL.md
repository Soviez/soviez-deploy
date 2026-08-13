# Safe Update Protocol (Phase 15)

## CLI
```bash
sudo soviez.sh --update <production-id> [--release <id>] [--offline-package <path>] [--confirm]
sudo soviez.sh --update-status|reattach|cancel|retry|recover|rollback <operation-id>
sudo soviez.sh --update-cleanup <operation-id> --confirm
sudo soviez.sh --update-image-cleanup <production-id> [--dry-run] [--confirm]
```

## Operation types
- `production_update` — Phase 14 canonical sync, locks, conflicts, cancel/retry/recover
- `update_image_cleanup` — post-window exact image delete (superseded by new `production_update` on same env)

## States
created → validating_target → checking_entitlement → resolving_release → validating_manifest → running_preflight → acquiring_artifact → validating_artifact → creating_backup → preparing_candidate → upgrading_candidate → validating_candidate → waiting_for_switch → switching → validating_production → image_cleanup → completed

Failure: failed_retryable | retry_scheduled | rollback_running | recovery_required | failed_terminal | canceled

## License Guard candidate
See `UPDATE_LICENSE_GUARD_CANDIDATE_PROTOCOL.md` (`soviez.update-candidate-identity.v1`).

## Image cleanup
See `SOVIEZ_IMAGE_RETENTION_AND_CLEANUP_PROTOCOL.md`.

## Reboot
`switching` / `rollback_running` after host restart → `UPDATE_RECOVERY_REQUIRED`.

## Entitlement request (connected)
POST `/api/installer/entitlements/product-updates/check`
Fields: capability, license_id, production_environment_id, account_id, operation

## Release / registry
Resolve signed release; create short-lived pull session; digest pull; credential cleanup marker (no token persisted).

## Offline package
signed, signature, digest, license_id, production_environment_id?, capability=product_updates, entitlement_ok, architecture, erp_major, expires_at, package_id/nonce (replay DB).

## Candidate layout
`$SOVIEZ_UPDATE_ROOT/candidates/<op_id>/{db,filestore,runtime,network,candidate.json}`

## Cancel boundaries
cancelable: preflight/pull/waiting; rollback: upgrading/backup/prepare; irreversible: switching/validating_production

## Codes
See `src/update/codes.sh` (UPDATE_* + DESTRUCTIVE_CONFIRMATION_REQUIRED).
