# Capacity and Performance Model — Phase 16 (Proposed)

## Backup capacity calculation

Before starting, compute and display **required vs available** bytes (no unexplained fixed multipliers as the sole check).

Contributors (sum with documented overhead factors):

| Contributor | Notes |
|-------------|-------|
| Database size | PG size estimate / dump estimate |
| Filestore size | Tree size |
| Metadata / manifest | Small |
| Temporary archive overhead | Staging directory |
| Compression estimate | Conservative (worse-case near uncompressed) |
| Encryption overhead | Small constant + framing |
| Local staging | Required even for remote |
| Remote multipart staging | If remote |
| Verification workspace | If verify-after |
| Safety margin | Explicit configurable bytes/% — legacy 5GiB is a **reference**, not magic |

Return largest contributors in operator output.

## Restore capacity calculation

| Contributor | Notes |
|-------------|-------|
| Archive size | On disk / download |
| Extracted DB | Restore workspace |
| Extracted filestore | Candidate filestore |
| Candidate workspace | Containers/config |
| Current Production preservation | Pre-restore freeze/recovery set |
| Rollback reserve | OD-13 window |
| Image availability | Digest pull/offline present |
| PostgreSQL temp | Restore sort space |
| Logs/evidence | Bounded |

## Compression recommendation

| Layer | Recommendation |
|-------|----------------|
| Database | Keep `pg_dump -Fc` (built-in compression) |
| Filestore | **zstd** (or gzip fallback) in tar/stream — speed vs ratio balance |
| Avoid | Loading full archive into memory; opaque proprietary-only formats as sole option |

Selection criteria: restore reliability, corruption detection (checksums), resumability, large filestore handling, portability (OD-18).

## Large backup behavior

Must support:

- Multi-GB databases and large filestores  
- Low-memory hosts (streaming)  
- Low-disk hosts (fail preflight early)  
- Interrupted transfer + resume  
- Multipart upload + per-part checksum  
- Bandwidth/CPU throttling (OD-12)  
- Progress + estimated completion  

No requirement to hold the full archive in RAM.

## Performance evidence (future implementation)

Measure dump duration, archive duration, verify duration, restore-test duration on lab sizes; do not invent SLA promises in docs as guarantees.
