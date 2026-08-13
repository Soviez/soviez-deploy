# Conflict Matrix — Phase 17

## Principles

- Read-only discovery may coexist with normal ERP runtime.  
- Discovery must **not** coexist with identity mutation (activation, License rebind, purge).  
- Destination bootstrap must not collide with another bootstrap on same host.  
- Trust pairing targets one exact source + destination.  
- Abort always available.  
- No global host lock for pure read-only inspection; exact locks for identity/bootstrap state.  

## Matrix (proposed)

| Incoming \ Active | update / production_update | production_backup / restore | stage clone/refresh/delete | ssl mutate | license activate | another discovery | another bootstrap | another pairing | purge |
|-------------------|----------------------------|-----------------------------|----------------------------|------------|------------------|-------------------|-------------------|-----------------|-------|
| source discovery (RO) | deny if identity-changing update mid-flight; allow idle ERP | deny if quiesce/restore | allow inventory if Stage ops don’t mutate selected Prod identity | allow inspect | deny | deny same Prod | N/A | deny same Prod | deny |
| destination bootstrap | N/A on dest | N/A | N/A | deny if mutating nginx for Prod | deny permanent activate | N/A | deny | deny | N/A |
| trust pairing | deny if source updating identity | deny restore mid-pair | allow | deny DNS/ssl mutate | deny | deny | deny | deny | deny |
| readiness | allow if snapshots frozen | deny if backup mutating inventory relied upon | allow | allow inspect | deny | allow read | allow read | deny if pair changing | deny |
| abort | allow | allow | allow | allow | allow | allow | allow | allow | allow |

Existing Phase 14 denies for `migrate`↔`production_update|backup|restore|update` remain authoritative once migrate ops exist.

## Code

`MIGRATION_ACTIVE_OPERATION_CONFLICT`
