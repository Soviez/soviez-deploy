# TRY_AGAIN_MODEL.md

## Canonical operation

`migration_dns_try_again` / CLI `--migration-dns-try-again <challenge-id>`

## Requirements

- Exact challenge ID + migration pair + expected records  
- Idempotent: re-check only; **no** new challenge unless expired/aborted  
- No duplicate ACME order; no duplicate bootstrap identity  
- No DNS mutation; no source routing mutation  
- Bounded backoff (reuse Phase 12 backoff profile adapted): e.g. min 30s, max OD-25  
- Authoritative + public resolver checks  
- Structured codes: `MIGRATION_DNS_PROPAGATION_PENDING`, `…_RECORD_MISMATCH`, `…_AUTHORITATIVE_MISMATCH`, etc.  
- Reboot: challenge state on disk; resume check  
- Offline: show last local status + manual dig instructions  

## Propagation waits (recommended defaults)

- WARNING after 15 minutes still pending  
- BLOCKED / failed_retryable after 60 minutes (OD-07/08) — owner may Try Again after fixing DNS  
