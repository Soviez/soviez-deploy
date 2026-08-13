# Backup Import / Export Protocol (Phase 16)

## Export
```bash
sudo soviez.sh --backup-export <backup-id> --output PATH
```
Packages the backup directory into a portable archive; records SHA-256 of the export file. Does **not** upload to SaaS.

## Import
```bash
sudo soviez.sh --backup-import PATH [--confirm]
```
Imports a packaged backup into local inventory/storage after structural checks. Same-host restore rules still apply after import.

## Security
- Treat import path as untrusted until verified (manifest signature + checksums)
- Encryption passphrase remains operator-supplied locally
- Export must not embed destination credentials or passphrases in clear side-car files beyond what the backup already stores encrypted

## Op types
`backup_export`, `backup_import` (Phase 14 registry integration where wired)
