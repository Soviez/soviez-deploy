# Phase 21 Overlap Review

## Reusable handoffs

| Artifact | Phase 22 use |
|----------|--------------|
| `traffic_owner=destination` | Required; must remain |
| `rollback_window.json` (default 1800s) | Immediate window; **not** full stabilization |
| Source `cutover_maintenance` / `rollback_origin` | Start of archive state machine |
| Destination post-cutover backup | Required freshness gate |
| Source certificate retained | Retention through archive verify |
| DNS rollback snapshot | Retain; mark `manual_recovery_only` after closure |
| `phase22_readiness` report | Exact targeting input; TTL 24h; never archives |
| Immediate rollback R0–R2 | Disabled after rollback-window closure commit |
| R3 / window expiry | Needs Action; not automatic archive |

## Corrected boundary

Phase 21 **stops before** archive/purge.  
Phase 21 readiness `phase22_allowed=false` until a future authorized Phase 22 implementation sets execution gates.

## Conflation to fix

User docs that say R3 → “reverse-migration (Phase 22)” conflate **retirement archive** with **reverse migration**.  
Corrected Phase 22 is **not** reverse-migration. Reverse-migration (if ever) is a separate unauthorized future product.
