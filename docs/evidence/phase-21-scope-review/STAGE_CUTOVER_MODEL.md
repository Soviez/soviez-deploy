# STAGE_CUTOVER_MODEL.md

## Phase 20 baseline

- Stage **identity rebind** complete (internal).
- Stage **public routes disabled** (`stage_public_routes=false` globally).

## Phase 21 scope

Enable **public routing** for **selected Stages only** — post `traffic_owner=destination` and public health PASS.

## Classification

| Class | Failure mode | Example |
|-------|--------------|---------|
| **Mandatory** | BLOCKED cutover completion | Primary customer portal Stage |
| **Optional** | WARNING in report | Internal demo Stage |

Mapping from Phase 20 Stage rebind report:

- `mandatory_stage_ids[]`
- `optional_stage_ids[]`

## Sequence

```text
traffic_owner=destination
→ production ERP health PASS
→ for each mandatory Stage:
      validate Stage entitlement + parent license
      activate Stage nginx public route (Phase 12 ownership)
      Stage TLS (wildcard or dedicated)
      Stage smoke: /web/login
→ optional Stages: same steps; failure → WARNING only
```

## Public cutover IN Phase 21

Explicitly **in scope** for selected Stages — contradicts Phase 20 "Stage public routes disabled" which applies **until** Phase 21 activation step.

## DNS

- Stage FQDNs may be separate records — include in DNS instruction addendum.
- No Stage cutover before Production ERP health PASS (mandatory ordering).

## Rollback

- Stage public routes disabled on rollback.
- Stage identity rebind from Phase 20 **persists** — rollback is routing, not identity.

## OWNER DECISION REQUIRED

**OD-30:** Default if no Stages selected — skip Stage cutover entirely?

**Recommendation:** **Yes** — WARNING `no_stage_public_cutover`.

**OD-31:** Mandatory Stage failure after Production ERP live — auto-rollback Production too?

**Recommendation:** **No** — BLOCKED completion + operator choice (Production may stay live).
