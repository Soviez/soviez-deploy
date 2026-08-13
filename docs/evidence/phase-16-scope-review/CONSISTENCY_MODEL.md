# Consistency Model — Phase 16 (Proposed)

## Goal

Produce a restore-capable Full backup whose database dump and filestore archive correspond to a short, controlled consistency window — without requiring exotic filesystem features.

## Default (recommended)

**Short controlled quiesce / maintenance mode**, then:

1. `pg_dump -Fc` of Production database  
2. Filestore archive of the Production filestore tree  
3. Manifest + checksums  
4. Optional encryption + transfer  
5. Resume Production

### Properties

| Property | Default proposal |
|----------|------------------|
| Requires ZFS/LVM | **No** |
| FS snapshots | **Optional enhancement** if present and tested |
| Application state during dump | Quiesced / maintenance — writes blocked or drained |
| Dump format | PostgreSQL custom (`-Fc`) |
| Filestore | Archive after DB dump starts or within same quiesce window (document ordering) |
| Crash consistency without quiesce | **Not** claimed for default Full backup |

## Ordering recommendation

```text
enter_maintenance
→ fence writers / drain short transactions
→ pg_dump -Fc
→ archive filestore
→ write manifest + checksums
→ exit_maintenance (or leave marked until verify if owner policy says so)
```

Exact fence mechanism is implementation-owned; must integrate with Phase 14 ops and conflict matrix.

## Optional enhancement: filesystem snapshot assist

If host provides a trustworthy snapshot of DB volume + filestore volume:

- May reduce quiesce duration  
- Must still produce `pg_dump -Fc` **or** document snapshot-boot restore path (prefer dump for portability)  
- Never **require** ZFS/LVM for Phase 16 PASS

## Non-goals

- Continuous WAL archiving / PITR (deferred)  
- Claiming zero-downtime Full backup as guaranteed  
- Copying live PostgreSQL data directories as the primary method  

## Failure during consistency window

| Failure | Behavior |
|---------|----------|
| Dump fails | Abort; discard partial; restore service; `failed_retryable` or terminal |
| Filestore read fails | Abort; do not publish backup_id as valid |
| Quiesce timeout | Fail closed; do not silently continue hot forever |

## Relation to Stage create

Phase 11 snapshot already uses `pg_dump -Fc` for Production→Stage. Phase 16 should align dump semantics with those primitives while adding maintenance/ops productization for Production backups.
