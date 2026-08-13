# Backup Encryption and Key Protocol (Phase 16)

## Algorithm
`openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt`  
Decrypt: matching `-d` flags.

## Policy
- **Local:** encryption required by default; advanced opt-out only via `SOVIEZ_BACKUP_DISABLE_ENCRYPTION=1` (warned).
- **Remote (s3/sftp/remote):** encryption always required.

## Passphrase handling
- `SOVIEZ_BACKUP_PASSPHRASE` or `SOVIEZ_BACKUP_PASSPHRASE_FILE`
- OpenSSL `-pass env:SOVIEZ_BACKUP_PASSPHRASE` (not argv)
- Never log, print, or store passphrase in manifest/inventory/ops JSON

## Manifest signing key
Separate local HMAC key (`manifest.key`) for integrity — not the encryption passphrase.

## Destination credentials
Local secrets only. No SaaS administration of backup keys in Phase 16.

## Failure codes
`BACKUP_ENCRYPTION_KEY_REQUIRED`, `BACKUP_ENCRYPTION_FAILED`, `BACKUP_ENCRYPTION_KEY_INVALID`
