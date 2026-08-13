# Migration Preparation (Phase 17)

Prepare a migration without moving data or changing DNS.

1. On the **source**: `sudo soviez.sh --migration-discover <production-id>`  
2. On the **destination**: `sudo soviez.sh --migration-bootstrap-destination --confirm`  
3. Note the destination bootstrap code.  
4. On the source: pair with fingerprints confirmed.  
5. Run readiness and fix WARNINGs/BLOCKERs.  
6. Abort anytime with `--migration-abort`.

Data transfer and domain cutover are later phases.
