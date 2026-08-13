# CONFLICT_MATRIX.md

**Date:** 2026-08-02  
**Extends:** Phase 14 conflict stub foreshadowing `migrate`

## Active \ Incoming (Phase 19 relevant)

| Active \ Incoming | transfer_* | domain/routing (18) | production_backup (16) | production_restore/switch | update/production_update | stage_* | pair revoke |
|-------------------|------------|---------------------|------------------------|---------------------------|--------------------------|---------|-------------|
| transfer_* | Deny duplicate / allow resume same id | Deny or serialize | Deny during FINAL_FREEZE | Deny | Deny | Deny mutating | Abort/BLOCK transfer |
| domain/routing | Serialize; prefer routing stable | Phase 18 rules | OK if non-disrupt | Deny switch | Deny | OK read | — |
| production_backup | Deny overlap final; pre-sync WARNING/deny OD | OK | Phase 16 | Deny | Deny | Careful | — |
| restore/switch | **Deny** | Deny cutover-ish | Deny | Phase 16 | Deny | Deny | — |
| update | **Deny** | Deny | Deny | Deny | Phase 15 | Deny | — |

## Principles

- Exact-target pair ops only  
- Never concurrent Production switch + transfer apply  
- Source write freeze exclusive with backup/update that needs writes  

Implementation wires `migration_transfer_*` into `soviez_ops_conflict_decide`.
