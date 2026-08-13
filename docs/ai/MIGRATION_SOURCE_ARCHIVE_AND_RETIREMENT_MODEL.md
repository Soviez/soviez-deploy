# Migration Source Archive and Retirement Model

## Phase boundary
Phase 22 = reversible archive and safe retirement readiness.  
Purge / host termination / backup deletion / certificate revocation = **forbidden**.  
Phase 23 (master plan) = Offline bundles — not purge; not implemented by Phase 22.

## Binding outcome
After Phase 22 PASS:
- traffic_owner=destination
- rollback_window=closed; automatic_rollback_allowed=false; manual recovery available
- source archive created, encrypted, checksummed, verified
- DB restore test PASS; filestore manifest verified
- source License = migrated_source_archived
- source ERP suspended; host/data/backups/certs/DNS evidence retained
- purge_authorized=false; deletion_performed=false
- READY FOR PHASE 23 = PASS|WARNING|BLOCKED (report only)

## One-License / one-slot
migration_token_consumed_count=1 · permanent_production_slot_count=1 · destination_binding_active=true

## Modules
stabilization · rollback_closure · source_archive · source_finalization · retirement · phase23_readiness
