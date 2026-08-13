# Destination Policy — Phase 16 (Proposed)

## Hard rules

1. **Local destination required** for every Production that enables backup.  
2. **Soviez-hosted backup is OUT OF SCOPE.** No customer backup payloads to Soviez SaaS.  
3. Remote destinations are **optional**, owner-controlled, and never the sole copy if policy can require local retention of latest N (owner OD).  
4. Credentials for remote destinations stay **on the customer host** by default (OD-15).

## Destination classes

| Class | Phase 16 | Notes |
|-------|----------|-------|
| Local filesystem under `/var/soviez/backups/...` | **Required** | Structured inventory |
| S3-compatible object storage | **Recommended first remote** | Owner-controlled endpoint |
| SFTP | **Recommended first remote** | Owner-controlled |
| Other cloud proprietary APIs | Later | Not required for Phase 16 MVP |
| Soviez-operated backup vault | **Forbidden** | Sovereignty |

## Local destination requirements

- Directory ownership/permissions: root-only or dedicated backup user; **not** world-readable  
- Capacity preflight before write  
- Atomic publish of `backup_id` (temp → finalize)  
- No write into update candidate workspaces or live DB/filestore paths  

## Remote destination requirements

- Encryption **mandatory** before/at upload (see `ENCRYPTION_OPTIONS.md`)  
- Multipart / resumable transfer for large objects  
- Per-part checksums  
- Credential failure → clear ops failure, no silent skip  
- Configuration scope: global vs per-Production (**OD-14**)

## Export / import

| Op | Purpose |
|----|---------|
| `backup_export` | Copy backup unit to operator path (encrypted if policy requires) |
| `backup_import` | Admit external archive into inventory after validation |

Import is not automatic trust — treat as untrusted until integrity + ownership checks pass.

## Recommendation summary

**Ship:** local required + S3-compatible + SFTP optional.  
**Defer:** Soviez-hosted, exotic remotes, SaaS-proxied upload.
