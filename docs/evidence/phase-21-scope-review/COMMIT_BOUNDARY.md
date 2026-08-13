# COMMIT_BOUNDARY.md

## Cutover commit point (recommended)

```text
cutover commit point =
  destination Production nginx route ACTIVE
  AND Production TLS VALID on destination
  AND Production DNS → destination (operator attested + propagation policy)
  AND public health suite PASS on Production FQDN
  AND source writes BLOCKED (cutover_maintenance)
  AND traffic_owner = destination
  AND traffic_cutover_started = true
  AND production_dns_changed = true
```

## True irreversible operational point

**`traffic_owner=destination` after public health PASS** — not DNS change alone.

Rationale: DNS may point to destination while source still serves maintenance with writes blocked; customers may not yet hit destination. Traffic ownership flip is when the system declares destination authoritative for Production epoch.

Commercial irreversible point remains Phase 20 (token consumed) — earlier.

## Before commit

- Rollback = abort nginx/TLS prep; no DNS rollback needed.
- Source may remain `migration_origin_grace` or `cutover_freeze`.
- `traffic_owner=source`.
- Cancel cutover operation allowed.

## After commit

- Rollback window opens (default 30m).
- Ordinary cancel forbidden — use rollback operation.
- Integration activation begins (incremental).
- Source remains in maintenance until rollback or Phase 22 archive path.

## Partial commit forbidden

Implementation must **not** persist:

- `traffic_owner=destination` with `public_route=false`.
- `public_route=true` with `traffic_owner=source`.
- `traffic_cutover_started=true` without health PASS artifact.

## Signed artifacts at commit

1. Cutover health report (PASS).
2. Cutover commit record (authorization_id, timestamps, traffic_owner).
3. Rollback window expiry timestamp.

## OWNER DECISION REQUIRED

**OD-32:** Single atomic commit RPC (SaaS ledger) for traffic_owner flip?

**Recommendation:** **Yes** — mirror Phase 20 atomic pattern; local apply saga after.

**OD-33:** Allow commit with WARNING health (optional tier only)?

**Recommendation:** **No** for mandatory tier failures; **Yes** if only optional WARNINGs (OD-16 tier 3).
