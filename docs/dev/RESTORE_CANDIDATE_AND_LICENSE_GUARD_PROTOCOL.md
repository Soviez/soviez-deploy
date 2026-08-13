# Restore Candidate and License Guard Protocol (Phase 16)

## Candidate layout
`$SOVIEZ_RESTORE_ROOT/candidates/<op_id>/{db,filestore,runtime,network}`  
Identity files record: temporary role, no license slot, Production tenant, license_id, database_uuid, backup_id.

## Neutralization
Candidate env disables mail/cron/webhooks/payments/outbound and marks background jobs neutralized (`SOVIEZ_RESTORE_CANDIDATE=1`).

## License Guard
- Reuses Phase 15 temporary candidate identity writer when available (`soviez.update-candidate-identity.v1` style binding)
- **No second permanent Core License Slot**
- No Guard bypass env vars
- Candidate is disposable; Production remains authoritative until switch

## Compatibility guards
`RESTORE_WRONG_PRODUCTION`, `RESTORE_LICENSE_BINDING_MISMATCH`, `RESTORE_BACKUP_OWNERSHIP_MISMATCH`, `RESTORE_HOST_IDENTITY_MISMATCH`, `RESTORE_DATABASE_ONLY_BACKUP_DENIED`, `RESTORE_BACKUP_NOT_VERIFIED`, `RESTORE_ERP_VERSION_INCOMPATIBLE`

## Restore-as-Stage
`--restore-as-stage` creates a Stage from a backup under Stage entitlement/domain rules — separate from Production switch restore.
