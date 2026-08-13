# TRANSFER_MANIFEST_MODEL.md

**Date:** 2026-08-02

## Purpose

Durable, pair-bound inventory of what will be / was transferred — for resume, audit, and Ready-for-20.

## Manifest identity

| Field | Notes |
|-------|-------|
| `migration_pair_id` | Phase 17 exact pair |
| `transfer_id` | Unique per transfer attempt/session lineage |
| `schema` | e.g. `soviez.transfer.manifest.v1` |
| `created_at` / `updated_at` | UTC |
| `strategy` | `option_b_multipass` |
| `source_backup_pin` | Phase 16 Full backup ID (final-pass gate) |

## Entries (logical)

Each entry: `payload_class`, `logical_path` or object id, `content_digest`, `size`, `chunk_plan_ref`, `required|optional`, `stage_id?`, `state` (`pending|inflight|done|failed|skipped`).

## Relationship to Phase 16 backup manifest

- Backup manifest describes a **recovery unit** on source/off-box  
- Transfer manifest describes **cross-host chunk progress**  
- Digests should be comparable where objects align (final DB dump file, filestore files)

## Signing / integrity

- Manifest updates authenticated under pair mTLS / local HMAC as implemented  
- Tamper → BLOCKED resume until operator reconcile  

See also: `PAYLOAD_CLASSIFICATION.md`, `CHUNKING_AND_RESUME_MODEL.md`.
