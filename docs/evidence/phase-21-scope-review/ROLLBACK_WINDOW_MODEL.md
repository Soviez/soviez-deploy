# ROLLBACK_WINDOW_MODEL.md

## Default window

**30 minutes** from `traffic_owner=destination` commit timestamp.

| Parameter | Default | Configurable |
|-----------|---------|--------------|
| Window duration | 30 min | OD-22 |
| Clock source | UTC signed in cutover report | — |
| Extension | Owner manual only | OD-23 |

## Window phases

```text
T0 = traffic_owner=destination commit
T0 → T0+30m = DNS rollback considered SAFE (subject to write threshold)
T0+30m → ∞ = DNS-only rollback → Needs Action unless zero writes proven
```

## Activities during window

- Monitor mandatory health metrics (degraded → rollback trigger).
- Hold integration activation for high-risk items if owner policy (optional stagger).
- Operator on-call required (OD-24).

## Expiry behavior

- Installer marks `rollback_window=expired` in cutover report.
- Automatic rollback triggers downgrade to **advisory** unless OD-25 enforces extended auto-rollback.
- Proceed to Phase 22 handoff eligibility check.

## Overlap with propagation

DNS propagation may still be in flux at T0. Rollback window includes propagation instability — health monitors continue.

## Audit

- `rollback_window_opened_at`
- `rollback_window_expires_at`
- `rollback_attempted_at` (if any)

## OWNER DECISION REQUIRED

**OD-22:** Confirm default 30-minute rollback window?

**Recommendation:** **Yes**.

**OD-23:** Allow one-time owner extension (+30m) without new authorization?

**Recommendation:** **Yes** with signed operator attestation.

**OD-24:** Require dual-control approval for rollback after T0+15m?

**Recommendation:** **Yes** for Production tenants with payments enabled.

**OD-25:** After window expiry, are automatic rollback triggers still enforced?

**Recommendation:** **Advisory only** — manual Needs Action.
