# Abort and Recovery Model — Phase 17

## Abort must (any Phase 17 point)

- Leave source ERP running  
- Leave source License valid  
- Not consume Migration Token  
- Not change DNS  
- Not enable maintenance  
- Not delete backups  
- Not delete Stages  
- Remove/revoke temporary trust  
- Disable destination bootstrap identity if required  
- Preserve diagnostics/evidence  
- Clean temporary secrets  
- Leave destination host reusable  
- Not run broad cleanup  

## Idempotent abort

`migration_pair_abort` / `--migration-abort <pair-id>`: safe to re-run; second call reports already aborted.

## Reboot recovery

- Phase 14 reattach/reconcile for in-flight discovery/bootstrap/pairing/readiness  
- Checkpoints before irreversible local writes  
- After reboot: no automatic token burn; no automatic DNS; no automatic activation  
- `recovery_required` if trust mid-issue; owner confirms fingerprint again if needed  
- Code: `MIGRATION_RECOVERY_REQUIRED`, `MIGRATION_ABORTED`
