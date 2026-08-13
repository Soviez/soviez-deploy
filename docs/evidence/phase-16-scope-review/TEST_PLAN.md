# Test Plan — Phase 16 (Implementation-Ready Outline)

**Status:** Plan only — no tests added this task.

## Backup unit tests

- Exact Production target selection / wrong target refusal  
- Destination validation (local/remote)  
- Capacity preflight math and fail-closed  
- Consistency/quiesce enter+exit  
- Database dump success/failure  
- Filestore archive success/failure  
- Manifest schema + checksums  
- Encryption/decryption round-trip  
- Retention eligibility / pin protection  
- Operation state transitions  
- Secret redaction in logs  

## Backup integration tests

- Real PostgreSQL `pg_dump -Fc`  
- Real filestore archive  
- Restore-capable Full backup publish  
- Interrupted backup + resume/discard  
- Disk full / inode exhaustion  
- Destination unavailable / remote credential failure  
- Encryption envelope validation  
- Remote upload fixture (S3-compatible/SFTP fake)  
- Reboot recovery of durable op  
- Multi-tenant isolation  
- Scheduled backup without duplicate  

## Restore unit tests

- Exact backup ownership checks  
- Compatibility matrix  
- Capacity for candidate + preservation  
- Candidate isolation  
- License Guard temporary identity behavior  
- Switch / rollback / cancel boundaries  
- Import validation of untrusted archives  

## Restore integration tests

- Real `pg_restore` + filestore restore  
- Real ERP startup, login, module registry  
- Attachment reference sanity (aggregates)  
- Incompatible addon / missing image digest  
- Wrong encryption key  
- Corrupted archive  
- Switch failure → recovery  
- Post-switch rollback within window  
- Reboot during restore  
- Cross-tenant denial  
- Cross-host refusal (Phase 16)  

## Security tests

- Path traversal / archive bomb / symlink escape  
- Arbitrary overwrite prevention  
- Tampered manifest  
- Wrong tenant restore  
- Secret exposure (argv/logs)  
- Malicious imported archive  
- Broad deletion prevention  
- World-readable mode regression  

## Performance tests

- Large DB / large filestore  
- Low disk / low memory streaming  
- Throttled transfer  
- Compression comparison notes  
- Restore-time measurement (observability only)  

## Regression gates

- Phase 11 Stage create  
- Phase 13 retention  
- Phase 14 ops engine  
- Phase 15 safe update + LG candidate  
- No version drift off authorized artifact when assembling  

## Explicit non-tests this review

No test files created or executed as part of scope review.
