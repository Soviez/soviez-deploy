# Scheduling Model — Phase 16 (Proposed)

## Goal

Optional host-local scheduled Production backups without continuous SaaS dependency.

## Components

| Component | Role |
|-----------|------|
| Schedule record | Per Production or host policy (UTC + local display) |
| Scheduler worker | Coordinated with Phase 14 scheduler fairness |
| Manual backup | Always allowed; must not duplicate identical running op |
| Window | Default wall-clock (**OD-10**) |

## Default schedule time (OD-10)

**Open.** Recommendation for owner discussion: low-traffic local window (e.g. 02:00 host local), single Production serialized unless concurrency OD-11 allows more.

## Concurrency (OD-11)

**Open.** Recommendation: default **one** Production backup at a time per host; queue others. Restores and updates take priority per conflict matrix.

## Behavior rules

```text
timer fires
→ create production_backup op if none active for that Production
→ if conflict → defer/retry_scheduled (bounded)
→ never start duplicate backup for same Production
→ record skip reason in history (no secret data)
```

## Offline / disconnected

Schedules run fully local. Entitlement checks that require network must fail closed or use cached Annual/capability grants per existing constitution — **no** backup payload egress.

## Bandwidth / CPU limits (OD-12)

Throttles apply to filestore archive and remote transfer. Defaults open; recommend conservative CPU nice + configurable MB/s cap for remote.

## Non-goals

- SaaS-pushed backup schedules as sole control plane  
- Guaranteeing RPO solely via schedule without capacity/health
