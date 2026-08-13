# CONFLICT_MATRIX.md

## Concurrent operations

| Op A | Op B | Result | Notes |
|------|------|--------|-------|
| `migration_cutover_*` | `migration_transfer_*` | **DENY** | Cutover requires stable staging |
| `migration_cutover_*` | `migration_authorization_*` | **DENY** | Phase 20 must be committed |
| `migration_cutover_*` | `domain_*` (Phase 18) | **DENY** | Domain plan frozen at cutover |
| `migration_cutover_*` | `ssl_renewal` (dest Production) | **SERIALIZE** | Queue after cutover or before plan |
| `migration_cutover_*` | `backup_full` (source) | **ALLOW read** | Backup OK during freeze |
| `migration_cutover_*` | `backup_restore` (source Production) | **DENY** | Corrupts cutover state |
| `migration_cutover_*` | `update_switch` | **DENY** on both hosts | Version drift |
| `migration_cutover_rollback` | `migration_cutover_commit` | **DENY** concurrent | Exclusive epoch |
| `migration_cutover_*` | `stage_create` | **DENY** | Phase 20 grace rule extends |
| `migration_cutover_stage_public` | `migration_cutover_integrations` | **ORDER** | Health → integrations → stages (default) |
| Phase 22 archive | cutover in progress | **DENY** | 22 unauthorized until 21 complete |

## Cross-host conflicts

| Resource | Conflict | Policy |
|----------|----------|--------|
| Production DNS zone | Manual edit outside installer | Drift detector → BLOCKED |
| nginx ownership (same FQDN) | Source + dest both claim | Impossible if split hosts; WARN if misconfigured |
| License slot | Duplicate bind | Phase 20 prevents |
| Migration Token | Re-consume | Denied |

## Phase overlap conflicts

| Phase | Conflict with 21 | Resolution |
|-------|------------------|------------|
| 18 | Re-run domain challenge mid-cutover | Forbidden |
| 19 | Restart transfer | Forbidden without abort cutover |
| 20 | Re-authorization | Forbidden; use reversal exceptional path |
| 22 | Early archive/purge | Forbidden |

## Drift invalidating cutover

- `authorization_id` / pair / fingerprint / digest mismatch
- Phase 21 readiness expired
- Backup pin removed
- Unexpected `public_route=true` before commit plan
- `traffic_owner` ledger vs local JSON mismatch

## Recovery priority

1. Human safety (stop writes)
2. traffic_owner truth from ledger
3. Rollback window policy
4. Idempotent resume
