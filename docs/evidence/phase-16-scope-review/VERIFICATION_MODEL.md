# Verification Model — Phase 16 (Proposed)

Three distinct levels. Evidence must remain privacy-preserving.

## Level 1 — Archive integrity verification

Op: `backup_verification` (integrity class)

Checks:

- Manifest present and schema-valid  
- Checksums match  
- Encryption envelope validates (if encrypted)  
- Archive readable / components present  
- Size sanity  
- Metadata ownership fields coherent  

Does **not** start ERP.

## Level 2 — Restore verification (restore-test)

Op: `backup_restore_test`

- Restore into **disposable** candidate (not Production switch)  
- Database starts  
- Filestore mounts  
- Application starts  
- Login responds  
- Module registry loads  
- UUID behavior valid  
- License Guard valid under temporary identity  
- No severe traceback loop  

Candidate destroyed or retained briefly per policy; **no** Production switch.

## Level 3 — Business consistency (aggregates only)

Privacy-preserving counts/metadata only, for example:

- company count  
- user count  
- installed module count  
- attachment reference count  
- selected metadata-table counts  
- schema version  
- filestore missing-reference count  

**Forbid** business records, names, invoice/payroll values, customer PII in evidence packs or SaaS uploads.

## Automated restore drills (OD-05)

**Open owner decision** whether periodic Level 2 drills are in Phase 16.  
Recommendation: support the op type now; enable schedule only if OD-05 = yes.

## RPO / RTO reporting (non-guarantee)

Report observables; do **not** promise contractual RPO/RTO unless enforced:

- last successful backup  
- last verified backup  
- last restore-tested backup  
- backup age / duration  
- verification duration  
- estimated restore time  
- actual restore-test duration  
- total size  
- destination availability  
- retention deadline  

## Retention interaction (OD-17)

Whether integrity verification is mandatory before retention treats a backup as valid — owner decision.
