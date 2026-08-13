# Stage Retention Model (Phase 13)

**Status:** Implemented — PASS (2026-07-30)  
**Version:** `0.13.0-phase13`  
**Scope:** Local, per-Stage retention; not an entitlement or runtime kill-switch.

## Policy

- Each Stage receives a default **14 calendar-day** lifetime from its immutable original `created_at`.
- The absolute ceiling is **60 calendar days** from that same creation timestamp.
- `--days` means requested **total lifetime**, not additional days. An extension never resets the clock and cannot shorten the current deadline.
- UTC timestamps are persisted; calendar dates, end-of-day deadlines, and countdown use the configured host timezone.
- Retention is independent of Stage License and Stage Operation Ticket entitlement. Entitlement expiry never stops or deletes an existing Stage.

## Durable local record

`/var/soviez/stages/<stage-id>/retention.json` records immutable creation and maximum deadline, requested total days, current deadline, derived countdown/status, warning/deletion state, final-backup evidence, Safe Shield result, and completed deletion steps. Immutable fields are rejected if changed.

The neutralized Stage receives an English status banner with a daily countdown and scheduled deletion date. Warning thresholds are locally ledgered at 30, 14, 7, 3, 1, and 0 days, preventing duplicate warnings.

## Deletion safety

When due, the local scheduler or explicit command first creates and verifies a final backup, then runs Safe Shield. Any ambiguity, ownership conflict, failed backup, or failed validation moves the record to **Needs Action** or recovery-required state; it does not delete.

Deletion is exact-resource only: Stage container, database, filestore, volumes, network, Stage config/secrets, unshared certificate material, and inventory entry. It never globally prunes Docker, targets Production, or deletes another Stage. A local tombstone retains non-secret audit evidence and final-backup reference.

## Recovery and limits

Per-Stage locks prevent concurrent deletion. Completed steps are durable and retries/reattach resume only unfinished steps. A partial deletion requires recovery and preserves the remaining evidence. Full Root can alter local files; this mechanism is a safety protocol, not DRM and never phones home.

See `docs/dev/STAGE_RETENTION_PROTOCOL.md`, `docs/dev/STAGE_SAFE_SHIELD_PROTOCOL.md`, and `docs/user/STAGE_RETENTION.md`.
