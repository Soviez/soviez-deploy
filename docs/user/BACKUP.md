# Backup

## What is backed up

- PostgreSQL database dump
- Filestore
- Config
- Addon / version manifest
- Integrity manifest

## Encryption

Local backups encrypt when passphrase configured (`SOVIEZ_BACKUP_PASSPHRASE` or better `SOVIEZ_BACKUP_PASSPHRASE_FILE`). Disabling encryption is an advanced local-only acknowledgment path and weakens posture.

## Critical terminology

```text
LOCAL_ONLY =
backup available
NOT disaster recovery
```

Off-host destinations (S3-compatible, SFTP) can be classified as DR-capable when configured and validated. Off-host is **not** mandatory for engineering certification; release policy `OD-RELEASE-OFFHOST-BACKUP` may still be PENDING.

## Commands

```bash
./dist/soviez.sh --backup <production-id> [--type full|database-only] [--destination PROFILE]
./dist/soviez.sh --backup-list [--production ID]
./dist/soviez.sh --backup-show|verify|pin|unpin|delete <backup-id>
./dist/soviez.sh --backup-export <backup-id> --output PATH
./dist/soviez.sh --backup-import PATH [--confirm]
./dist/soviez.sh --backup-destination-list|show|test
./dist/soviez.sh --security-backup-check
```

## Integrity

Use `--backup-verify` and security backup checks. Corrupt backups fail integrity gates.
