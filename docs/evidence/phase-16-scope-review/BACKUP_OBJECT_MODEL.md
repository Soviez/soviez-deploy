# Backup Object Model — Phase 16 (Proposed)

**Status:** Scope proposal — not implemented.

## Definition

A **Production backup** is an inventoried, addressable object with stable `backup_id`, ownership metadata, content components, integrity material, and optional encryption envelope.

## Default restore-capable unit: Full backup

**Full backup** = Database (`pg_dump -Fc`) + Filestore archive + Manifest (+ optional config/routing refs without private keys).

This is the **default** and the only unit advertised as restore-capable for Production.

## Backup types

| Type | Status in Phase 16 proposal | Notes |
|------|-----------------------------|-------|
| Full (DB+filestore+manifest) | **Default product** | Restore-capable |
| Database-only | **Advanced-only** | Hard confirmation + explicit warning; not default |
| Filestore-only | **Unsupported** except documented repair workflows | Not a restore unit |
| Incremental / WAL | **DEFERRED** (later phase) | Too complex for Phase 16 |
| Update recovery set | Out of product | Phase 15-internal |
| Stage/retention archive | Out of Production product | Separate Stage semantics |

## Logical schema (minimum)

```text
backup_id                 # stable id
schema_version
created_at                # UTC
production_id / tenant_id
license_id                # exact License when applicable
database_uuid
host_fingerprint          # same-host affinity
backup_type               # full | database_only (advanced)
components[]              # db, filestore, manifest, ...
checksums                 # per-component + aggregate
encryption                # none | age | aes-256-gcm-envelope
destination_id / location
size_bytes
compression
consistency_mode          # quiesce | snapshot_assist | ...
verification_status       # none | integrity | restore_tested | ...
retention                 # policy, expires_at, pinned
rpo_metadata              # last success markers (derived)
operation_id              # creating op
```

**Forbid in manifest:** passwords, private keys, Device credentials, customer business payloads, plaintext backup keys.

## On-disk layout (local destination sketch)

```text
/var/soviez/backups/production/<production-id>/<backup-id>/
  manifest.json
  db.dump                 # pg_dump -Fc
  filestore.tar.zst       # or chosen compression
  checksums.txt
  envelope.meta           # if encrypted
  evidence/               # privacy-preserving verify aggregates only
```

Exact filenames are implementation-owned; schema_version must migrate safely.

## Identity and ownership rules

- Backup is bound to **exact** Production identity + `database_uuid` + License context.  
- Restore must refuse cross-tenant / wrong License / wrong UUID mismatches.  
- Import of foreign archives requires explicit import op + validation (`backup_import`).

## Portability

Long-term supported portable unit = **full backup archive** with versioned manifest (owner decision OD-18 for format freeze).  
Cross-host restore of that unit is **out of Phase 16** (migration/reactivation).
