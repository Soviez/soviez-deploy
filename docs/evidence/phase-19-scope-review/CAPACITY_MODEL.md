# CAPACITY_MODEL.md

**Date:** 2026-08-02

## Estimates

Before transfer start and before final pass:

| Resource | Source | Destination |
|----------|--------|-------------|
| Disk | Headroom for dump + chunk temp | Staging size ≈ selected payloads + margin |
| Free margin | Dump temp + 10–20% | **Estimate + 20–30%** (align Phase 17 OD spirit) |
| Network | Sustained bandwidth vs remaining bytes | Ingress capacity |
| Freeze budget | Final dump+delta must fit **≤15m** target | Apply time separate but reported |

## Gate outcomes

| Condition | Report |
|-----------|--------|
| Dest free < required + margin | **BLOCKED** |
| Freeze ETA > hard timeout | **BLOCKED** or require narrower selection |
| Bandwidth profile cannot finish pre-sync in owner window | **WARNING** (may still proceed) |

## Bandwidth profile

Default **balanced** (OD). Aggressive/throttle profiles are owner-selectable at impl without changing protocol.
