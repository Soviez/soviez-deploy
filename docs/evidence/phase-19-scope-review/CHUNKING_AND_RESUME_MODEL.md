# CHUNKING_AND_RESUME_MODEL.md

**Date:** 2026-08-02

## Chunking

| Parameter | Recommended default |
|-----------|---------------------|
| Strategy | **Fixed** chunks initially |
| Size | **64 MiB** |
| Compression | **zstd** balanced per chunk or object stream |
| Integrity | Per-chunk digest + manifest rollup |

Large logical objects (filestore files, dump files) split into ordered chunks; small files may be single-chunk.

## Resume registry

Durable store (both sides or authoritative dest+source sync):

| Field | Purpose |
|-------|---------|
| `transfer_id` / `object_id` / `chunk_index` | Identity |
| `digest` / `size` / `state` | Progress |
| `attempt` / `last_error` | Ops |

On restart: skip `done` chunks; re-fetch mismatched digests; never mark done without verify.

## Failure injection expectations (impl tests)

- Mid-stream kill → resume without full restart  
- Partial chunk write → discard incomplete; retry  
- Manifest/registry disagree → BLOCKED until reconcile  

## Non-goals

- BitTorrent-style multi-peer  
- Content-defined chunking (may be later OD)  
- WAL frame streaming  
