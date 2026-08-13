# Migration Transfer Protocol (Phase 19)

## Channel

- Pair-bound mTLS (Phase 17 certs) or local channel (`SOVIEZ_MIG_TRANSFER_LOCAL=1`)
- Chunk put/get with SHA-256 sidecar + replay prevention
- No SaaS relay; no `StrictHostKeyChecking=no`

## Chunks

Fixed 64 MiB (`SOVIEZ_MIG_CHUNK_SIZE_BYTES`), states: planned → receiving → received → verifying → verified → assembled.

## CLI

`--migration-transfer-plan`, `--migration-presync`, `--migration-transfer-start`, pause/resume/cancel/abort/recover/cleanup, `--migration-destination-verify`.
