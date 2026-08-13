# Immediate Migration Rollback

If something goes wrong shortly after Production cutover, you may roll back traffic to the source **within the rollback window** (default 30 minutes after cutover completes).

## When rollback is safe (automatic)

Rollback tier **R1** applies when:

- Cutover completed and traffic owner is destination
- Rollback window is still open
- No meaningful business writes occurred on the destination
- No payment capture side effects

The installer restores DNS to the previous target, disables the destination public route, and sets traffic owner back to **source**.

## When rollback is not safe

Rollback is **denied** (`MIGRATION_ROLLBACK_NOT_SAFE`) when:

- Meaningful destination writes occurred after cutover
- Payment providers captured transactions on the destination
- The rollback window expired

In these cases, contact support for a guided reverse-migration plan (Phase 22 scope). Your migration token is **not** restored — it was consumed once at Phase 20 commit.

## Pre-commit abort (tier R0)

If cutover failed before traffic owner switched to destination, abort may not require DNS restoration.

## Dual control (tier R2)

After 15 minutes within the window, rollback may require an additional confirmation (operator dual-control policy OD-24).

## Automatic triggers

The installer monitors split-brain (AR-04) and health flapping (AR-01). Split-brain may require immediate rollback during the window.

## Important

- Rollback does **not** undo Phase 20 token consumption
- Source purge/archive is **not** part of rollback — source returns to rollback-origin state for operator review

## Related

- [Production cutover](MIGRATION_CUTOVER.md)
