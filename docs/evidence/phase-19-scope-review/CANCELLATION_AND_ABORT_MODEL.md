# CANCELLATION_AND_ABORT_MODEL.md

**Date:** 2026-08-02

## Abort triggers

- Operator Abort CLI/UI  
- Pair revoke/expiry mid-flight  
- Unrecoverable integrity failure  
- Conflict preemption (higher-priority deny → abort or park)

## Default abort behavior (**recommended**)

| Artifact | Default |
|----------|---------|
| Destination staging data | **Preserve** |
| Exact-delete staging | **Optional** explicit flag (destructive — owner-pending) |
| Source | Remain **ACTIVE**; release write freeze if held |
| Resume registry | Retain for forensics unless exact-delete |
| Phase 18 DNS/landing | Unchanged (Phase 18 abort rules separate) |
| Token | Still not reserved/consumed |

## Cancel vs Abort

- **Cancel** planned/precheck before bytes: clean no-op  
- **Abort** after bytes: preserve staging by default  

## Safety

Never auto-purge source; never consume token on abort; never Production-activate on abort.
