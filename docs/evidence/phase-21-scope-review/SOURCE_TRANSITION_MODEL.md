# SOURCE_TRANSITION_MODEL.md

## Source state machine (Phase 21)

```text
migration_origin_grace     (Phase 20 entry — traffic active, ops restricted)
        │
        ▼
cutover_freeze             (Phase 21 — quiesce writes; may still serve reads)
        │
        ▼
cutover_maintenance        (Phase 21 — maintenance page; read-only; writes blocked)
        │
        ├──────────────────► rollback_origin   (Phase 21 rollback — traffic restored)
        │
        ▼
archive_ready              (Phase 22 handoff — NOT purge; source idle, auditable)
```

## State definitions

### `migration_origin_grace` (Phase 20 — input)

- **Traffic:** Active on source Production domain.
- **Writes:** Business mutations restricted (no update/clone/Stage/migrate/rebind).
- **License Guard:** Source binding; destination is licensed future owner.
- **Duration:** Until Phase 21 cutover or Phase 22 archive transition.

### `cutover_freeze` (Phase 21)

- **Trigger:** Cutover operation start after readiness revalidation.
- **Traffic:** Still on source.
- **Writes:** Blocked at application layer (ERP maintenance mode soft or write gate).
- **Purpose:** Stable snapshot for optional final sync; prevent drift before DNS.

### `cutover_maintenance` (Phase 21)

- **Trigger:** DNS switch initiated (authoritative records pointed at destination) OR propagation window start.
- **Traffic:** Production DNS may split during propagation; source serves maintenance landing on Production domain if still resolving to source.
- **Writes:** **Blocked** (hard).
- **Purpose:** Prevent split-brain writes while destination accepts traffic.

### `rollback_origin` (Phase 21 exceptional)

- **Trigger:** Rollback within rollback window; health failure; owner abort.
- **Traffic:** Restored to source (`traffic_owner=source`).
- **Writes:** Restored per grace rules unless reverse-migration required.
- **DNS:** Operator reverses authoritative records (manual instruction).

### `archive_ready` (Phase 22 handoff)

- **Not in Phase 21 scope** except as terminal label for handoff report.
- Source idle, backups retained, no purge.

## Transitions (gates)

| From | To | Gate |
|------|-----|------|
| grace | freeze | Cutover op authorized + preflight PASS |
| freeze | maintenance | DNS switch confirmed OR propagation timer start |
| maintenance | (dest owns traffic) | N/A on source — paired with traffic_owner flip |
| any cutover | rollback_origin | Rollback window open + policy satisfied |
| maintenance | archive_ready | Phase 22 only |

## Source nginx / landing

- Production domain maintenance page **distinct** from Phase 18 mig-subdomain landing.
- Activate on source only during `cutover_maintenance` (or earlier if owner policy OD-08).

## OWNER DECISION REQUIRED

**OD-04:** Enter `cutover_maintenance` at DNS instruction emit or at DNS propagation confirm?

**Recommendation:** At **DNS switch confirm** (operator attestation step), not merely instruction emit.

**OD-05:** Allow source to serve read-only ERP during maintenance vs hard maintenance page only?

**Recommendation:** **Hard maintenance page** on Production domain during propagation (cleaner split-brain story).
