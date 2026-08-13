# Retention Options — Phase 16 (Proposed)

## Independence from Stage retention

Production backup retention is **independent** of Stage 14–60 calendar-day policy (Phase 13).  
Do not reuse Stage `--days` clock for Production backups.

## Proposed policy knobs

| Knob | Meaning |
|------|---------|
| Keep last N full backups | Count-based |
| Keep last D days | Time-based |
| Minimum verified count | Prefer verified over unverified when pruning |
| Pin | Exempt from automated deletion until unpin |
| Indefinite pin | Allowed only if owner approves (**OD-03**) |

## Default retention (OD-04)

**Open owner decision.** Review recommendation for discussion (not silent policy):

- Keep last **7** successful Full backups **or** **30** days, whichever retains more;  
- Never delete the sole remaining restore-capable backup without confirmation;  
- Prefer deleting unverified before verified when both eligible.

Final numbers require OD-04.

## Pinning

| Behavior | Proposal |
|----------|----------|
| `--backup-pin` | Sets `pinned=true`; cleanup skips |
| `--backup-unpin` | Clears pin |
| Indefinite | Allowed iff OD-03 = yes |
| Abuse | Pins still consume disk; capacity warnings mandatory |

## Cleanup operation

Op type: `backup_retention_cleanup`

- Conflicts with restore using same `backup_id`  
- Automated deletion confirmation policy = **OD-16**  
- Must not broad-delete `/var/soviez/backups`  

## Interaction with verification (OD-17)

If OD-17 = yes: retention considers a backup “valid” only after integrity verification (and optionally restore-test class).  
Unverified backups may be retained shorter or excluded from “last successful” RPO reporting.
