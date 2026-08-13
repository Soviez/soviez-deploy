# Production Migration Cutover

Phase 21 moves live Production traffic from your source server to the destination after Phase 20 authorization and activation are complete.

## Before you start

- Phase 20 commit consumed your migration token exactly once.
- Destination is in **production licensed pre-cutover** mode (not yet public).
- Source is in **migration origin grace** (updates/clones restricted).
- Run Phase 21 pre-cutover readiness and resolve any **BLOCKED** items.

## What cutover does

1. Final data sync (bounded write freeze on source)
2. Activates destination Production route and TLS for your exact domain
3. Changes the **exact DNS A record** to point to the destination
4. Puts source into signed maintenance (business writes denied)
5. Runs public health checks
6. Switches **traffic owner** to destination
7. Opens a **rollback window** (default 30 minutes)

## What cutover does not do

- Does not purge or archive the source (Phase 22)
- Does not relay traffic through Soviez SaaS
- Does not change unrelated DNS records or use wildcard certificates
- Does not consume a second migration token

## Confirmation required

Cutover requires explicit operator confirmation. There is no environment-flag bypass.

## After cutover

You receive a certification summary including:

- Traffic owner — destination
- Production DNS — changed
- Source — maintenance
- Rollback window — open
- Phase 22 readiness — reported

Keep the operation ID for status, recovery, and rollback commands.

## DNS

Manual DNS change is supported: follow the instructions emitted by the installer, apply the exact A record at your provider, then confirm with the DNS retry command.

## Related

- [Immediate rollback](MIGRATION_IMMEDIATE_ROLLBACK.md)
- [Activation before cutover](MIGRATION_ACTIVATION_BEFORE_CUTOVER.md)
