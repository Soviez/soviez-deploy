# Migration Production Cutover and Rollback Model

Phase 21 implements the **canonical Production cutover engine** — the only authorized path from Phase 20 pre-cutover state to live destination traffic with an immediate rollback window.

## Scope boundary

| Phase | Responsibility |
|-------|----------------|
| Phase 19 | Payload transfer, staging, final sync (no Production DNS / traffic owner flip) |
| Phase 20 | Atomic token commit, destination pre-cutover activation, source grace, Phase 21 **pre-cutover** readiness |
| Phase 21 | Production cutover, DNS exact-record mutation, TLS gate, traffic_owner switch, rollback window |
| Phase 22 | Post-cutover source archive/purge readiness (report only in Phase 21; execution unauthorized) |

## Canonical path

Only `soviez_migration_cutover_start` (via CLI `migration cutover start`) may set `SOVIEZ_MIG_P21_CANONICAL_CUTOVER=1`. Environment bypass flags (`SOVIEZ_MIG_ALLOW_CUTOVER`, `SOVIEZ_MIG_DNS_CUTOVER`) remain forbidden outside this engine.

## Operation sequence (state machine)

```text
started → final_cutover_sync → source_freeze → destination_route_activate
→ tls_validate → dns_cutover → propagation_observe → post_cutover_validate
→ traffic_owner_switch → integration_activate → rollback_window_open
→ stage_cutover → phase22_readiness → cutover_complete
```

Each mutating step is **idempotent** — retry/recover re-runs safely.

## Commit boundary

Irreversible operational commit requires **all** of:

1. Destination Production route active (exact FQDN nginx, no wildcard)
2. Production TLS valid for exact FQDN (hostname + expiry gate)
3. Authoritative DNS points to destination (exact A record; manual attestation or fixture provider)
4. Public health / smoke suite PASS
5. `traffic_owner=destination` (signed record)
6. Source in `cutover_freeze` / `cutover_maintenance` with AR-09 write denial

DNS change alone is insufficient if source could still accept business writes.

## Rollback tiers

| Tier | Condition | Action |
|------|-----------|--------|
| R0 | Pre-commit (`traffic_owner=source`) | Abort; no DNS restore required |
| R1 | Post-commit, within window, zero meaningful writes | Automatic safe rollback |
| R2 | Post-commit, within window, after T0+15m | Dual-control confirmation (OD-24) |
| R3 | Meaningful writes, payment capture, or window expired | `MIGRATION_ROLLBACK_NOT_SAFE` — advisory/manual only |

Migration token is **never restored** on rollback.

## Automatic triggers

| Code | Signal | Window behavior |
|------|--------|-----------------|
| AR-04 | Split-brain detected | Rollback required |
| AR-01 | Health flapping | Suppressed during grace; advisory post-window |

## Permanent bans (Phase 21)

- Source purge / archive
- SaaS payload relay
- Broad / zone-wide DNS mutation
- Wildcard Production routes
- Second token consumption
- Phase 22 archive execution

## Traffic owner

Single signed SoR: `soviez.traffic_owner.v1` keyed by `authorization_id`. Default `source`; switches to `destination` exactly once at commit boundary.

## Phase 22 readiness (post-cutover)

Distinct from Phase 21 **pre-cutover** readiness (`phase21_readiness/`). Post-cutover report confirms destination ownership and source maintenance — **never** archives or purges.

## Installer version

Target: **`0.21.0-phase21`**

## Related protocols

- `docs/dev/MIGRATION_CUTOVER_PROTOCOL.md`
- `docs/dev/MIGRATION_IMMEDIATE_ROLLBACK_PROTOCOL.md`
- `docs/dev/MIGRATION_TRAFFIC_OWNER_PROTOCOL.md`
- `docs/dev/MIGRATION_PHASE22_READINESS_PROTOCOL.md`
- `docs/dev/MIGRATION_PHASE21_READINESS_PROTOCOL.md` (pre-cutover)
