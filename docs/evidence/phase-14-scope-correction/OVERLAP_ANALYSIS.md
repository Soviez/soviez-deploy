# Overlap Analysis — Old Phase 14 vs Delivered Work

## Old Phase 14 (obsolete)

| Field | Old content |
|-------|-------------|
| Title | Persistent operation engine |
| Objective | Resumable ops state + systemd workers |
| Scope | `src/ops`; state JSON; reattach UX |
| Acceptance | Kill SSH mid-op; reattach resumes; no zero restart |
| Complexity | High |

## Overlap matrix

| Old acceptance / scope item | Status | Notes |
|----------------------------|--------|-------|
| Durable resumable state | **DONE** | Phase 8/11/12/13 |
| systemd / durable workers | **DONE** | Phase 8/11 units; SSL/retention workers/schedulers |
| Reattach UX | **DONE** | Four command-specific CLIs |
| Kill SSH → resume | **DONE** | Phase 8 + 11 certified |
| No zero restart | **DONE** | Checkpoint/idempotent resume |
| Single `src/ops` rewrite | **HARMFUL if greenfield** | Would fork or replace working engines |
| Cross-command registry | **MISSING** | Phase 14 |
| Cross-command conflict matrix | **MISSING** | Phase 14 |
| Unified cancel/rollback contract | **MISSING / partial** | Some abort (SSL); no host-wide cancel model |
| Unified orphan reconciliation | **MISSING / fragmented** | Per-command recovery only |
| Schema version migration across kinds | **MISSING** | Heterogeneous records today |
| Scheduler coordination | **MISSING** | SSL + retention run independently |
| Unified log/history conventions | **PARTIAL** | Events/redaction exist for `--new`; not standardized |

## Conclusion

> ~70% of the **old** Phase 14 acceptance narrative is already satisfied by Phases 8–13.  
> Remaining work is **consolidation and cross-command hardening**, not first-time persistence.

Risk of leaving old wording in place: agents re-implement `src/ops` from scratch, break working reattach paths, or claim progress for duplicated capability.
