# Backup Object and Manifest Protocol (Phase 16)

## Schema
- Object schema: `soviez.backup.v1`
- IDs: `bk-<UTC>-<hex>`, ops `bkop-<localts>-<hex>`
- Object file under backup dir; mode `600`; parent dir `700`

## Object fields (core)
`backup_id`, `production_id`, `operation_id`, `backup_type` (`full` | `database_only`), `status`, `created_at`, `license_id`, `database_uuid`, `host_identity`, `erp_major`, destination metadata, encryption flag/alg, sizes, `verification_status`, `restore_test_status`, `pinned`, artifact paths.

## Artifacts (Full)
- Database: `pg_dump -Fc`
- Filestore: compressed archive (zstd preferred, gzip/tar fallback)
- Manifest: JSON + `signature_alg=HMAC-SHA256` + `signature`

## Manifest rules
- Canonical JSON: sorted keys, no whitespace variance; signature fields stripped before sign
- Local HMAC key under backup secrets dir (`manifest.key`, mode `600`)
- **Forbidden in manifest:** passwords, passphrases, private keys, destination secrets, encryption key material

## Inventory
Host inventory indexes backups by `backup_id` / `production_id` for list/show/retention.

## Verification
Integrity verify (checksums + manifest signature) before treating a backup as retention-valid / preferred restore source.
