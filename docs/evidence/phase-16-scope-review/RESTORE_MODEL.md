# Restore Model — Phase 16 (Proposed)

## Core principle

**Candidate-first restore** (reuse Phase 15 Safe Update pattern).  
**No direct overwrite of live Production by default.**

## Restore modes

| Mode | Phase 16 | Notes |
|------|----------|-------|
| Same-host Production restore (candidate → switch) | **In scope** | Default product |
| Cross-host restore | **Out of scope** → Phase 17 / migration | Needs migration/reactivation |
| Restore-as-Stage | **Conditional** | Stage entitlement + Stage License rules; separate from Production restore |
| Direct in-place overwrite | **Forbidden by default** | Emergency-only would need explicit future owner authorization (not proposed now) |
| DB-only restore from advanced backup | Advanced path | Same candidate-first; warn incomplete filestore |
| Filestore-only | Unsupported as restore product | Repair workflows only |

## Happy path (Production)

```text
validate backup ownership + compatibility
→ preflight capacity
→ preserve current Production (recovery set / freeze)
→ create restore candidate workspace
→ restore DB (pg_restore) + filestore + metadata
→ start candidate
→ validate candidate (app, LG, aggregates)
→ explicit switch confirmation
→ switch routing to candidate
→ post-switch validation
→ retain rollback window (OD-13)
```

## Destructive boundaries

| Boundary | Rule |
|----------|------|
| Before candidate valid | Cancel → cleanup candidate; Production untouched |
| After switch | Cancel not silent; may enter `recovery_required` / rollback |
| Rollback | Uses preserved pre-restore Production artifacts within safety window |

## Compatibility checks

- `production_id` / License / `database_uuid` affinity  
- PostgreSQL major compatibility  
- Image digest / addon presence expectations from manifest  
- Encryption key availability  
- Same-host fingerprint for Phase 16  

Fail closed on mismatch.

## Restore-as-Stage

Allowed **only** when:

1. Stage entitlement present  
2. Stage License rules satisfied  
3. Op is distinct from `production_restore`  
4. UUID rotation / Stage isolation rules from Phase 11 apply  

Not a shortcut to free Production clones.

## Cross-host

Documented exclusion: package may be exportable, but applying on another host is **migration** (Phase 17+), not Phase 16 restore.
