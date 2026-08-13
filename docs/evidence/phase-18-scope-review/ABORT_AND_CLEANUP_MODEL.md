# ABORT_AND_CLEANUP_MODEL.md

## Abort must

- Leave source traffic / ERP / License unchanged  
- Not reserve/consume Migration Token  
- Not activate destination Production  
- Revoke temporary domain challenge (local consume/abort)  
- Revoke/remove **migration-subdomain** certificate material for this operation  
- Remove **exact** destination migration-site Nginx config / landing if owned by this op  
- Preserve diagnostics/evidence  
- Preserve unrelated certs/routes  
- Leave destination host reusable  
- Avoid broad Nginx cleanup / cert-store wipe  
- Idempotent + reboot-safe  

## DNS cleanup policy (recommended default)

| Record creator | On Abort |
|----------------|----------|
| Owner-managed (manual) | **Preserve**; print exact cleanup instructions |
| Phase 18 provider adapter | **Exact** delete of records it created |

## CLI

`--migration-dns-abort <challenge-id>` and `--migration-domain-abort <pair-id>` (aborts all Phase 18 ops for pair).
