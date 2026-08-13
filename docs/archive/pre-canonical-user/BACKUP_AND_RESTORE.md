# Backup and Restore

Production backups capture your database and file attachments so you can recover on the **same server**. Restore builds a temporary candidate first, validates it, then switches — your live system stays untouched until you confirm.

## Common commands
```bash
sudo soviez.sh --backup <production-id>
sudo soviez.sh --backup-list [--production ID]
sudo soviez.sh --backup-show <backup-id>
sudo soviez.sh --backup-verify <backup-id>
sudo soviez.sh --restore <production-id> --backup <backup-id> [--confirm]
sudo soviez.sh --restore-status <operation-id>
sudo soviez.sh --restore-rollback <operation-id> [--confirm]
```

## What is included
A Full backup includes the PostgreSQL dump and filestore. Encryption is on by default for local backups and required for remote destinations. Business data is never uploaded to Soviez SaaS.

## What is not included
Point-in-time / WAL recovery, restoring a backup onto a different host (migration is a later phase), and using database-only advanced backups for a full Production restore.

See also: `BACKUP_DESTINATIONS.md`, `BACKUP_RETENTION.md`, `RESTORE_AND_RECOVERY.md`.
