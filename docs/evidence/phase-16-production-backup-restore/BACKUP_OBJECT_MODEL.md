# Backup object model
Schema `soviez.backup.v1`. IDs `bk-*` / ops `bkop-*`. Object JSON mode 600 under per-backup dir 700.
Artifacts: dump, filestore archive, HMAC-SHA256 signed manifest (secrets scrubbed).
See `docs/dev/BACKUP_OBJECT_AND_MANIFEST_PROTOCOL.md`.
