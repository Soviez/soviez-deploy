# Final Backup
Deletion requires a final Stage backup before Safe Shield. The engine requires a produced archive outside the Stage directory and a matching SHA-256 sidecar; it copies archive/checksum plus retention evidence to local retention-backup storage.

Failure or injected checksum/backup failure records `FINAL_RETENTION_BACKUP_FAILED`, preserves the Stage, and moves to Needs Action. Unit coverage verifies failure blocks deletion and retry succeeds after the fault clears.
