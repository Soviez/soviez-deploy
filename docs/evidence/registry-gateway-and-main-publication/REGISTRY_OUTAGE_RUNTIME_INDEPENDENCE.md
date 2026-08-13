# REGISTRY_OUTAGE_RUNTIME_INDEPENDENCE — Runtime Continuity

## Summary

Once a valid pull ticket is issued, **gateway operation does not require live SaaS connectivity**. Running ERP workloads do not require continuous registry access.

## Independence matrix

| Scenario | ERP runtime impact | Registry path impact |
|----------|-------------------|----------------------|
| SaaS unavailable during active pull ticket | None until ticket expires (≤900s) | Gateway continues offline verify |
| SaaS unavailable after pull complete | None | N/A — images local |
| Gateway unavailable | None for **running** containers | New pulls fail |
| Docker Hub unavailable | None for **running** containers | New pulls fail at proxy |
| Ticket expired mid-pull | Pull fails; retry needs SaaS refresh | Expected |

## Design alignment

- Pull tickets: short TTL (900s) — limits exposure, not runtime dependency.
- Session max (3600s): SaaS-side refresh window; not a runtime heartbeat.
- Gateway: stateless verify + session-scoped digest graph in memory only.

## Installer stage machine

Post-`ticket_verified`, stage proceeds through snapshot/deploy without continuous registry connection unless a new image pull is initiated.

## Live verification

Simulate gateway outage with running ERP instance on staging VPS: **PENDING**

## LIVE_FULL_CYCLE readiness

**NO** — full cycle simulation requires staged SaaS + gateway + VPS (`LIVE_SIMULATION_READINESS.md`).
