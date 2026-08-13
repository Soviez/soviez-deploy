# Cross-Command Conflict Model (Phase 14 draft)

**Status:** Scope draft only — not enforced in runtime until Phase 14 implementation is authorized and PASSes.

## Principles

1. Prefer **exact environment** and **exact resource** locks over host-wide locks.
2. Two operations on **unrelated** Stages/environments should not block each other by default.
3. Destructive or mutating ops on the **same** target must be exclusive unless the matrix explicitly allows coexistence.
4. Ambiguous ownership → deny new conflicting start; preserve in-flight safer op; surface Needs Action / recovery.
5. Stale locks must be detectable via heartbeat / worker liveness and recoverable without deleting unrelated state.

## Draft conflict matrix

| Op A | Op B | Same target? | Verdict |
|------|------|--------------|---------|
| Stage retention deletion | Stage backup | Same Stage | **CONFLICT** |
| Stage retention deletion | Stage restore | Same Stage | **CONFLICT** |
| Stage retention deletion | Manual `--stage-drop` | Same Stage | **CONFLICT** |
| Stage retention deletion | Stage create | Different Stage | **ALLOW** |
| Stage retention extend/status | Stage start/stop | Same Stage | **ALLOW** (non-destructive) |
| SSL renew/repair | ERP runtime | Same env | **ALLOW** (renewal must not stop ERP) |
| SSL renew | Nginx config replacement | Same domain/env | **CONFLICT** (exclusive Nginx mutation) |
| SSL renew | Unrelated Stage SSL | Different env | **ALLOW** |
| Production `--update` (future) | Backup restore (future) | Same Production | **CONFLICT** |
| Production `--update` | Migration (future) | Same Production | **CONFLICT** |
| Migration | Unrelated Stage lifecycle | Different env | **ALLOW** |
| `--new` | Existing Stage ops | Different tenant/env | **ALLOW** |
| Stage create | Unrelated Stage backup | Different Stage | **ALLOW** |
| Two Stage creates | Same Stage ID / domain | Same | **CONFLICT** |
| Retention scheduler | Manual retention run | Same Stage | **CONFLICT** (single active deletion) |
| SSL scheduler | Manual SSL renew | Same env | **CONFLICT** or coalesce (document one policy) |

## Lock classes (proposed)

| Lock class | Granularity | Examples |
|------------|-------------|----------|
| `env` | environment_id | Stage A, Production P |
| `resource.db` | exact DB name | Stage DB only |
| `resource.filestore` | exact path | Stage filestore |
| `resource.nginx` | exact domain/config | Stage/Prod vhost |
| `resource.cert` | cert inventory id | shared wildcard awareness |
| `host.scheduler` | optional soft | scan fairness — not destructive mutex |

## Deadlock / stale recovery (scope)

- Acquire locks in documented global order (e.g. env → db → filestore → nginx → cert)
- Heartbeat + worker PID/unit checks
- Stale exclusive lock → reconcile: resume if safe, else `recovery_required`
- Never steal lock while verified live worker holds it

## Non-goals for this model

- Host-wide “one operation only” mutex as default
- SaaS-mediated locking
- Automatic remote cancel of customer operations
