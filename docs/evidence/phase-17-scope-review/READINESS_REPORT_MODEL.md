# Readiness Report Model — Phase 17

Local **signed** readiness report. No business payloads or secrets.

## Contents

- Source summary (IDs, versions, digests, sizes aggregates)  
- Destination summary (bootstrap ID, host, capacity)  
- Trust state (pair ID, fingerprints refs, expiry)  
- Compatibility matrix  
- Capacity matrix  
- Connectivity matrix  
- Selected scope (default: Production only; Stages unselected)  
- Selected Stages **proposal** (owner must confirm later)  
- Exclusions (explicit Phase 18–22 items)  
- Warnings / blockers / required owner actions  
- Estimated transfer size / duration / downtime class (planning only)  
- Migration Token status (`eligible` / …; `consumed=false`)  
- Domain/SSL readiness (inspect)  
- Backup readiness  
- Rollback prerequisites (future phases)  
- Report signature + expiry (OD-18)  

## Binding outcome lines

Report must be able to assert:

```text
SOURCE DISCOVERY — COMPLETE
DESTINATION BOOTSTRAP — COMPLETE
MIGRATION PAIR — TRUSTED
READINESS — PASS | BLOCKED | NEEDS ACTION
NO DATA TRANSFER STARTED
SOURCE REMAINS ACTIVE
MIGRATION TOKEN NOT CONSUMED
```

## Codes

Stale/forged: treat as `MIGRATION_PAIR_SIGNATURE_INVALID` / readiness fail — never authorize transfer on unsigned/expired report.
