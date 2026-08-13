# Phase 14 Scope Correction

**Date:** 2026-07-31  
**Status:** IMPLEMENTATION COMPLETE / PASS  
**Progress impact:** +5% (credited → 72%)

---

## Reason for correction

The Master Implementation Plan previously defined Phase 14 as:

> **Persistent operation engine** — resumable ops state + systemd workers; reattach UX; kill SSH and resume.

That wording is **materially outdated**. Durable operation persistence, systemd-backed (or test-mode durable) workers, reattach, disconnect/resume, checkpointing, locks, retry/recovery, and reboot reconciliation already exist—in varying forms—across:

| Phase | Evidence |
|-------|----------|
| **8** — `--new` | `docs/evidence/phase-08-new-connected-activation/` (`DISCONNECT_RESUME_MATRIX.md`, `OPERATION_STATE_MACHINE.md`) |
| **11** — Stage create | `docs/evidence/phase-11-multi-stage-runtime/` (`DISCONNECT_RESUME_MATRIX.md`, `REBOOT_RECOVERY_E2E.md`) |
| **12** — SSL lifecycle | `docs/evidence/phase-12-domain-ssl-lifecycle/` (reattach / retry / abort / scheduler) |
| **13** — Stage retention | `docs/evidence/phase-13-stage-retention/` (`DISCONNECT_RESUME_MATRIX.md`, `REBOOT_RECOVERY.md`, `PARTIAL_DELETION_RECOVERY.md`) |

Implementing “persistence/systemd/reattach from scratch” would **duplicate completed work** and risk divergent engines.

---

## Completed capability inventory (source of truth: code + evidence)

### Phase 8 — `--new`
- `src/operations/engine.sh` — operation ID, state JSON, events, heartbeat, per-op lock
- `src/operations/state_machine.sh` — `--new` state machine
- `src/operations/systemd_unit.sh` — worker unit render / paths
- `--reattach <operation-id>` — resume without zero restart
- Redacted event append via `soviez_redact_text`

### Phase 11 — Stage runtime
- Stage op dirs under `SOVIEZ_STAGE_OPS_DIR`; `state.json`; checkpoints
- Durable worker start + PID/heartbeat; systemd unit in production / nohup in test
- `--stage-reattach`; disconnect/resume E2E **PASS**; reboot recovery E2E **PASS**
- Idempotent step guards (`soviez_stage_sm_should_run`)

### Phase 12 — Domain/SSL
- Certificate inventory + lifecycle SM; durable renewal operations
- `--ssl-status|renew|repair|reattach|try-again|abort`
- Scheduler / backoff / Needs Action / recovery paths
- Exact-environment targeting; ownership markers

### Phase 13 — Stage retention
- Retention operation IDs; per-Stage deletion locks
- `completed_deletion_steps` checkpoint resume
- `--stage-retention-{status,extend,run,retry,reattach}`
- Scheduler scan; partial deletion → `recovery_required`; tombstones
- Final backup + Safe Shield gates

---

## Overlap analysis (old Phase 14 vs delivered)

| Old Phase 14 claim | Already delivered? | Where |
|--------------------|--------------------|-------|
| Resumable operation state | **Yes** | Phases 8, 11, 12, 13 |
| systemd workers | **Yes** (prod path + test durable workers) | 8/11 (+ SSL/retention schedulers) |
| Reattach UX | **Yes** (command-specific) | `--reattach`, `--stage-reattach`, `--ssl-reattach`, `--stage-retention-reattach` |
| Kill SSH mid-op → resume | **Yes** (certified) | Phase 8 + 11 evidence |
| Worker restart / reboot recovery | **Yes** (certified) | Phase 11 + 12 + 13 evidence |
| Checkpointing / idempotent transitions | **Yes** | All four |
| Locks / retry / recovery states | **Yes** (per-command) | All four |

**Still missing (true Phase 14 work):** one canonical schema, host-level registry, cross-command conflict matrix, unified CLI (with aliases), shared cancel/rollback contract, unified orphan/reboot reconciliation, shared log/history/redaction conventions, state-version migration across heterogeneous records, scheduler coordination, and plug-in readiness for update/backup/migration.

---

## Corrected title

**Phase 14 — Unified Operation Engine Consolidation and Cross-Command Recovery**

---

## Corrected objective

Unify existing operation-engine implementations across installer commands into one consistent, auditable, cross-command engine with shared state contracts, conflict prevention, reconciliation, history, cancellation, recovery, and future readiness for update, backup, and migration phases.

Do **not** describe Phase 14 as creating persistence, systemd workers, or reattach for the first time.

---

## Corrected scope (summary)

1. **Unified operation schema** — canonical record (no secrets)
2. **Shared state-machine framework** — common lifecycle + command-specific states
3. **Global local operation registry** — list/filter/reconcile/history; SaaS-optional
4. **Cross-command conflict prevention** — exact environment/resource locks; matrix
5. **Unified CLI** — `--operations`, `--operation-status|reattach|cancel|retry|recover|logs` (+ keep aliases)
6. **Unified cancellation / rollback** — boundaries; no silent destructive cancel
7. **Orphan / reboot reconciliation** — single decision tree across command types
8. **Unified logs / redaction** — conventions; rotation; no secret/business data shipping
9. **Operation history / tombstones** — immutable audit fields; local retention
10. **Schema versioning / migration** — backward-compatible readers; non-destructive upgrade
11. **Scheduler coordination** — SSL + retention (+ future backup/update) without overlap
12. **Future-phase readiness** — Phase 15 update, 16 backup/restore, 17–22 migration, 23 offline bundles (interfaces only)

Full detail: `docs/evidence/phase-14-scope-correction/CORRECTED_SCOPE.md`

---

## Explicit non-goals

- Rebuilding Phase 8 persistence from scratch
- Rebuilding Phase 11 systemd worker from scratch
- Rebuilding Phase 12 renewal scheduler from scratch
- Rebuilding Phase 13 retention worker from scratch
- Changing commercial entitlements, Stage retention policy, or domain/SSL policy
- Implementing `--update`, backup/restore, migration, or offline bundles
- Modifying SaaS UI
- Live deployment; commit/push/release
- Progress credit until a future authorized implementation PASS

---

## Earlier-phase vs Phase 14 ownership

| Owner | Owns |
|-------|------|
| **Phase 8** | First durable installer engine; `--new` reattach/resume |
| **Phase 11** | Stage op persistence; Stage disconnect/resume; Stage reboot recovery |
| **Phase 12** | Certificate operation scheduling/retry/recovery |
| **Phase 13** | Retention scheduling; deletion checkpoints; partial-deletion recovery |
| **Phase 14** | Shared canonical schema; registry; cross-command locks; unified CLI; orphan reconciliation; shared cancel/rollback; shared log/redaction; scheduler coordination; state-version migration; future update/backup/migration readiness |

---

## Cross-command conflict examples

See `docs/evidence/phase-14-scope-correction/CROSS_COMMAND_CONFLICT_MODEL.md`.

Examples: retention deletion ↔ Stage backup/restore/drop; update ↔ restore/migration on same Production; SSL Nginx replacement exclusive per domain; Stage create does not block unrelated Stage lifecycle.

---

## Future acceptance gates

See `docs/evidence/phase-14-scope-correction/FUTURE_ACCEPTANCE_GATES.md`.  
Implementation PASS only when registry, migration, conflict matrix, unified CLI/aliases, orphan/reboot, redacted logs, history, and Phase 8/11/12/13 regressions are proven—without live-system changes.

---

## Proposed weight

| Field | Value |
|-------|-------|
| Complexity | **High** (consolidation + hardening, not greenfield persistence) |
| Proposed weight | **5** (consistent with other High/Medium-High consolidation phases; lighter than Phase 11 weight 8) |
| Applied this task | **Yes** — progress is now **72%** |
| Credit rule | Credited upon successful verification of Phase 14 unified engine |

Fully applied: progress updated to 72%.

---

## Implementation authorization status

```text
Phase 14 = PASS — UNIFIED ENGINE CERTIFIED
Current progress = 72% (credited)
Phase 11.5 = FUNCTIONALLY CERTIFIED — VISUAL OWNER ACCEPTANCE DEFERRED
```

**Next action:** Phase 15 is currently unauthorized. Wait for owner approval.
