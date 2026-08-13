# Backup Retention Protocol (Phase 16)

## Default policy
Per Production classification:

- Keep up to **7** distinct daily slots
- Keep up to **4** distinct weekly slots (ISO week)
- Keep up to **12** distinct monthly slots

Independent of Stage retention (14–60 days).

## Protected classes (never auto-deleted)
- `pinned`
- `latest_successful`
- `latest_verified`
- `latest_restore_tested`
- Backups referenced by active operations

## Cleanup
- Dry-run by default for destructive paths
- Manual `--backup-delete` and non-dry retention cleanup require `--confirm` (unless assume-yes test env)
- Pins must be unpinned before delete

## Validity
Integrity verification status informs which backup counts as latest verified; unverified backups are weaker retention anchors.

## CLI
`--backup-retention-status`, `--backup-retention-cleanup`, `--backup-pin`, `--backup-unpin`, `--backup-delete`
