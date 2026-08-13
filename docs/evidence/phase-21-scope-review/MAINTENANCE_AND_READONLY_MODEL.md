# MAINTENANCE_AND_READONLY_MODEL.md

## Two maintenance surfaces

| Surface | Domain | Phase | Purpose |
|---------|--------|-------|---------|
| Mig landing | `migrate.<production>` | 18 | Neutral info during transfer/grace |
| Production maintenance | Production FQDN | **21** | Customer-facing during cutover propagation |

Phase 21 activates **Production maintenance on source**, not mig landing replacement on destination (destination serves ERP after health).

## Source read-only / write block

### `cutover_freeze`

- Block ERP write RPCs (create/update/delete business records).
- Allow read-only web for operators (optional — OD-05).
- Backup/status/diagnostics allowed.

### `cutover_maintenance`

- Production FQDN serves maintenance page if DNS still points to source.
- **All writes blocked** (database + filestore).
- Cron business jobs paused on source.
- Outbound mail/webhooks from source **disabled**.

## Destination during cutover

- Before health PASS: no customer maintenance page on Production domain; either connection refused, staging, or nginx default until route live.
- After health PASS: full ERP (not maintenance).

## Implementation reuse

- Phase 18 maintenance landing templates → adapt copy for Production maintenance (RTL per Soviez standard).
- Nginx ownership on **source** Production site for maintenance upstream swap.

## Messaging (recommended)

- Bilingual maintenance page with Try Again link (polls health endpoint).
- No misleading "migration complete" until cutover report signed.

## Rollback

- Source maintenance deactivated; ERP write path restored when `traffic_owner` returns to source.

## OWNER DECISION REQUIRED

**OD-13:** Source maintenance page auto-enable on DNS attestation?

**Recommendation:** **Yes** — tied to `cutover_maintenance` transition.

**OD-14:** Display estimated completion time on maintenance page?

**Recommendation:** **Optional WARNING** if not available; static message default.
