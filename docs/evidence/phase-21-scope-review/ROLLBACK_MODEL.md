# ROLLBACK_MODEL.md

## Rollback types

| Type | When | Mechanism |
|------|------|-----------|
| **Pre-commit abort** | Before `traffic_owner=destination` | Reverse nginx/TLS on dest; source exit freeze; DNS unchanged |
| **DNS rollback** | Within rollback window; minimal dest writes | Reverse DNS instructions; source exit maintenance; dest public_route=false |
| **Full traffic rollback** | Health failure post-commit | DNS rollback + traffic_owner=source + dest deactivate public route |
| **Reverse-migration** | After meaningful dest writes | **Needs Action** — not automated in Phase 21 default |

## Preconditions for DNS rollback (safe window)

- Rollback window **open** (default 30 minutes — see `ROLLBACK_WINDOW_MODEL.md`).
- Destination business writes below threshold (OD-20) OR owner accepts data loss risk.
- Source backup pin intact (Phase 16).
- Source can exit `cutover_maintenance` and resume traffic.

## Rollback sequence (traffic rollback)

```text
trigger (manual or automatic advisory)
→ dest: public_route=false, integration neutralization restored
→ source: exit maintenance, traffic_owner=source (ledger + local)
→ emit DNS rollback instructions (previous target = source)
→ verify propagation back to source
→ source health PASS
→ signed rollback report
→ state: source rollback_origin → grace or normal (OD-21)
```

## Unsafe rollback

After meaningful destination writes (orders, payments, mail delivery):

- DNS-only rollback causes **split-brain data** — classify **Needs Action**.
- Requires reverse-migration plan (Phase 22 / manual).

## Token / license

- Migration Token **not** restored on rollback (Phase 20 irreversible).
- License slot remains on destination binding until exceptional admin reversal (Phase 20 OD-23 analog).

## nginx/SSL rollback

- Destination: Phase 12 promote rollback.
- Source: maintenance page removed; prior Production config restored.

## OWNER DECISION REQUIRED

**OD-20:** Define "meaningful dest writes" threshold blocking DNS-only rollback?

**Recommendation:** **Any** confirmed payment capture OR **>10** business documents created post-commit → **Needs Action**.

**OD-21:** After successful rollback, source state: return to `migration_origin_grace` or full normal?

**Recommendation:** **`rollback_origin` → migration_origin_grace** with cutover BLOCKED until new readiness cycle.
