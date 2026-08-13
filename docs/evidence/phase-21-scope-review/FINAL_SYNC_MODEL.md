# FINAL_SYNC_MODEL.md

## Purpose

**Mandatory** cutover final consistency pass — a bounded Phase-19-style delta from source to destination immediately before public Production route activation. Distinct from Phase 19 full streaming transfer and from Phase 20 commercial commit.

## Policy (recommended default)

- Final write freeze: **mandatory**
- Exact source Production only
- Final database snapshot or approved delta: **mandatory**
- Final filestore reconciliation: **mandatory**
- Destination apply + internal verify **before** public route
- Source write freeze released only into `cutover_maintenance` / write-blocked state after destination is ready
- Source business writes denied after authoritative final sync unless rollback is invoked

## When (always before public route)

| Checkpoint | Required |
|------------|----------|
| Phase 20 authorization + readiness current | Yes |
| Source `migration_origin_grace` → `cutover_freeze` | Yes |
| Destination `production_licensed_pre_cutover` internal healthy | Yes |
| Backup pin valid (Phase 16) | Yes |
| Destination verified backup present | Yes (WARNING/BLOCKED per OD) |
| No `traffic_cutover_started` yet | Yes |

## Mechanics

```text
cutover_freeze (source: stop accepting new business writes)
→ final_sync preflight (pair, Phase 19 watermark, backup pin, Phase 20 auth)
→ final database snapshot/delta (Phase 16/`pg_dump -Fc` primitives preferred)
→ final filestore reconciliation since Phase 19 manifest watermark
→ apply at destination → internal validate (ERP/LG/modules/filestore)
→ signed final_sync report bound to authorization_id + cutover plan_id
→ proceed to dest route / TLS / DNS steps
→ release freeze only into cutover_maintenance (writes remain blocked)
```

## Freeze maximum (recommended)

**15 minutes** hard timeout — exceed → abort cutover, remain `traffic_owner=source`, destination stays non-public.

## Source after final sync (before/during DNS)

- Business writes: **denied**
- Public behavior: signed maintenance (or owner-approved read-only — OD-05)
- Integrations: remain neutralized
- Internally: rollback-origin capable (backup/status/diagnostics)

## Idempotency

- `operation_type`: `migration_final_sync`
- Same `authorization_id` + idempotency key → same result or explicit resume
- Failed mid-sync → source remains traffic owner; no DNS mutation; no traffic_owner switch

## Exclusions

- Config/Stage identity rebind (Phase 20)
- DNS/nginx Production cutover (subsequent steps)
- Integration activation (after public health)
- Source archive/purge (Phase 22)

## OWNER DECISION REQUIRED

**OD-02:** Mandatory vs optional final sync — **Recommendation: mandatory.**  
**OD-03:** Final write-freeze maximum — **Recommendation: 15 minutes.**
