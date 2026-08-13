# CONFLICT_MATRIX.md

| Concurrent activity | Phase 24 hardening | Lock / rule |
|---------------------|--------------------|-------------|
| Connected update | May tighten signature gates | Exact-target; no fleet |
| Offline update / bundle apply | Regression + stricter verify | Reuse Phase 15/23; no second engine |
| Migration transfer/cutover | Do not mutate engines | Security static gates only |
| Rollback / source archive | Untouched | No purge |
| Backup / restore | Secret-handling regression | No backup deletion product |
| Stage create/refresh/delete | Ticket replay cert only | No Stage redesign |
| License rebind / Device replace | Out | No slot mutation |
| Entitlement mutation | Out | Resolver unchanged |
| Registry export | Lockdown harden | Ephemeral creds only |
| Production rollout | **Conflict — forbidden** | Separate auth |
| Final release packaging | Phase 25 | Do not steal scope |
| Destructive cleanup | **Conflict — forbidden** | Exact deny |
| Phase 25 ops | After Phase 24 | Boundary enforced |
| Owner visual acceptance | Independent | No lock required |

Use Phase 14 exact locks only if a remediation operation mutates shared host state; prefer read-only certification where possible.
