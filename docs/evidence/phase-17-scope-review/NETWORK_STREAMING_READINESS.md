# Network / Streaming Readiness — Phase 17

Phase 17 **does not** transfer DB/filestore/addons. It assesses readiness for future **direct** streaming (Phase 19).

## Assess

- Source can reach destination (and auth model)  
- Preferred transfer protocol (SSH and/or mTLS — OD-16)  
- Ports, firewall changes required  
- Bandwidth / latency estimates  
- Resumability capability (planning)  
- Disk staging on both sides  
- Encryption in transit  
- Host-key / certificate pinning  
- **No SaaS relay**  
- **No giant source archive requirement** as primary design  

## Connectivity test

Synthetic non-sensitive payload only (e.g. fixed nonce echo). Codes: `MIGRATION_CONNECTIVITY_FAILED`.

## Explicit bans

- Business payload transfer  
- Backup dump relay through SaaS  
- Trust without pinning/owner confirm  
